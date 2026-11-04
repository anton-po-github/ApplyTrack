using System.Text;
using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Validation;
using Microsoft.EntityFrameworkCore;

namespace ApplyTrack.End.Services;

public sealed class ProposalService(ApplyTrackDbContext db, TimeProvider time) : IProposalService
{
    public const int MaxLiveProposalsPerUser = 500;

    public async Task<CreateProposalResult> CreateAsync(
        Guid userId,
        ProposalInput input,
        CancellationToken ct
    )
    {
        DateTimeOffset now = time.GetUtcNow();
        Guid id = Guid.CreateVersion7(now);
        long nowMs = now.ToUnixTimeMilliseconds();
        int status = input.Status;
        int max = MaxLiveProposalsPerUser;

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        // 1) Atomic limit check + counter update in ONE statement.
        //    It locks this user's stats row, so parallel creates run one by one.
        int updated = await db.Database.ExecuteSqlInterpolatedAsync(
            $@"UPDATE ""UserStats"" SET
                   ""Total""     = ""Total"" + 1,
                   ""Draft""     = ""Draft""     + CASE WHEN {status} = 0 THEN 1 ELSE 0 END,
                   ""Sent""      = ""Sent""      + CASE WHEN {status} = 1 THEN 1 ELSE 0 END,
                   ""Viewed""    = ""Viewed""    + CASE WHEN {status} = 2 THEN 1 ELSE 0 END,
                   ""Interview"" = ""Interview"" + CASE WHEN {status} = 3 THEN 1 ELSE 0 END,
                   ""Won""       = ""Won""       + CASE WHEN {status} = 4 THEN 1 ELSE 0 END,
                   ""Lost""      = ""Lost""      + CASE WHEN {status} = 5 THEN 1 ELSE 0 END
               WHERE ""UserId"" = {userId} AND ""Total"" < {max}",
            ct
        );

        if (updated == 0)
        {
            // Either the limit is reached, or the user has no stats row (user deleted).
            int hasRow = await db
                .Database.SqlQuery<int>(
                    $@"SELECT COUNT(*)::int AS ""Value"" FROM ""UserStats"" WHERE ""UserId"" = {userId}"
                )
                .SingleAsync(ct);

            return hasRow == 0
                ? new CreateProposalResult.UserNotFound()
                : new CreateProposalResult.LimitReached(); // transaction is disposed = rollback
        }

        // 2) Insert the row. If this fails, the counter update rolls back too.
        await db.Database.ExecuteSqlInterpolatedAsync(
            $@"INSERT INTO ""Proposals""
                   (""Id"", ""UserId"", ""Title"", ""Company"", ""Platform"", ""Status"", ""Budget"",
                    ""FollowUpDate"", ""Link"", ""Notes"", ""CreatedAtMs"", ""UpdatedAtMs"")
               VALUES
                   ({id}, {userId}, {input.Title}, {input.Company}, {input.Platform}, {input.Status},
                    {input.Budget}, {input.FollowUpDate}, {input.Link}, {input.Notes}, {nowMs}, {nowMs})",
            ct
        );

        await tx.CommitAsync(ct);

        return new CreateProposalResult.Created(
            new ProposalResponse(
                id,
                input.Title,
                input.Company,
                input.Platform,
                input.Status,
                input.Budget,
                input.FollowUpDate,
                input.Link,
                input.Notes,
                nowMs,
                nowMs
            )
        );
    }

    public async Task<ProposalResponse?> GetAsync(Guid userId, Guid id, CancellationToken ct)
    {
        // O(1): primary key seek. Owner and soft-delete checks are part of the same query.
        ProposalRow? row = await db
            .Database.SqlQuery<ProposalRow>(
                $@"SELECT ""Id"", ""Title"", ""Company"", ""Platform"", ""Status"", ""Budget"",
                          ""FollowUpDate"", ""Link"", ""Notes"", ""CreatedAtMs"", ""UpdatedAtMs""
                   FROM ""Proposals""
                   WHERE ""Id"" = {id} AND ""UserId"" = {userId} AND ""DeletedAtMs"" IS NULL"
            )
            .FirstOrDefaultAsync(ct);

        return row?.ToResponse();
    }

    public async Task<ProposalListResponse> ListAsync(
        Guid userId,
        ProposalListQuery query,
        Guid? cursor,
        CancellationToken ct
    )
    {
        // The SQL text is made ONLY from fixed pieces and numbered placeholders.
        // Every value (user id, cursor, status, search, limit) travels as a parameter.
        var sql = new StringBuilder(
            @"SELECT ""Id"", ""Title"", ""Company"", ""Platform"", ""Status"", ""Budget"",
                     ""FollowUpDate"", ""Link"", ""Notes"", ""CreatedAtMs"", ""UpdatedAtMs""
              FROM ""Proposals""
              WHERE ""UserId"" = {0} AND ""DeletedAtMs"" IS NULL"
        );
        var args = new List<object> { userId };

        if (cursor is Guid after)
        {
            args.Add(after);
            sql.Append(" AND \"Id\" < {").Append(args.Count - 1).Append('}');
        }

        if (query.Status is short status)
        {
            args.Add(status);
            sql.Append(" AND \"Status\" = {").Append(args.Count - 1).Append('}');
        }

        if (query.Search is string search)
        {
            args.Add(LikeEscaper.ContainsPattern(search));
            sql.Append(" AND \"Title\" ILIKE {").Append(args.Count - 1).Append('}');
        }

        // One extra row tells us if a next page exists.
        args.Add(query.Limit + 1);
        sql.Append(" ORDER BY \"Id\" DESC LIMIT {").Append(args.Count - 1).Append('}');

        List<ProposalRow> rows = await db
            .Database.SqlQueryRaw<ProposalRow>(sql.ToString(), args.ToArray())
            .ToListAsync(ct);

        bool hasMore = rows.Count > query.Limit;
        List<ProposalRow> page = hasMore ? rows.GetRange(0, query.Limit) : rows;
        Guid? nextCursor = hasMore ? page[^1].Id : null;

        return new ProposalListResponse(page.Select(r => r.ToResponse()).ToList(), nextCursor);
    }

    public async Task<UpdateProposalResult> UpdateAsync(
        Guid userId,
        Guid id,
        ProposalInput input,
        CancellationToken ct
    )
    {
        long nowMs = time.GetUtcNow().ToUnixTimeMilliseconds();
        int newStatus = input.Status;

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        // 1) Lock the row and read the old status.
        //    Owner and soft-delete checks are part of the same query.
        List<ProposalLockRow> locked = await db
            .Database.SqlQuery<ProposalLockRow>(
                $@"SELECT ""Status"", ""CreatedAtMs""
                   FROM ""Proposals""
                   WHERE ""Id"" = {id} AND ""UserId"" = {userId} AND ""DeletedAtMs"" IS NULL
                   FOR UPDATE"
            )
            .ToListAsync(ct);

        if (locked.Count == 0)
        {
            return new UpdateProposalResult.NotFound(); // transaction is disposed = rollback
        }

        int oldStatus = locked[0].Status;
        long createdAtMs = locked[0].CreatedAtMs;
        long updatedAtMs = Math.Max(nowMs, createdAtMs); // never older than the creation time

        // 2) Replace all editable fields. Id, UserId and CreatedAtMs never change.
        int updated = await db.Database.ExecuteSqlInterpolatedAsync(
            $@"UPDATE ""Proposals"" SET
                   ""Title"" = {input.Title},
                   ""Company"" = {input.Company},
                   ""Platform"" = {input.Platform},
                   ""Status"" = {input.Status},
                   ""Budget"" = {input.Budget},
                   ""FollowUpDate"" = {input.FollowUpDate},
                   ""Link"" = {input.Link},
                   ""Notes"" = {input.Notes},
                   ""UpdatedAtMs"" = {updatedAtMs}
               WHERE ""Id"" = {id} AND ""UserId"" = {userId}",
            ct
        );

        if (updated != 1)
        {
            throw new InvalidOperationException("The locked proposal row was not updated.");
        }

        // 3) Move one count from the old status to the new status. Total stays the same.
        if (oldStatus != newStatus)
        {
            int statsUpdated = await db.Database.ExecuteSqlInterpolatedAsync(
                $@"UPDATE ""UserStats"" SET
                       ""Draft""     = ""Draft""     - CASE WHEN {oldStatus} = 0 THEN 1 ELSE 0 END + CASE WHEN {newStatus} = 0 THEN 1 ELSE 0 END,
                       ""Sent""      = ""Sent""      - CASE WHEN {oldStatus} = 1 THEN 1 ELSE 0 END + CASE WHEN {newStatus} = 1 THEN 1 ELSE 0 END,
                       ""Viewed""    = ""Viewed""    - CASE WHEN {oldStatus} = 2 THEN 1 ELSE 0 END + CASE WHEN {newStatus} = 2 THEN 1 ELSE 0 END,
                       ""Interview"" = ""Interview"" - CASE WHEN {oldStatus} = 3 THEN 1 ELSE 0 END + CASE WHEN {newStatus} = 3 THEN 1 ELSE 0 END,
                       ""Won""       = ""Won""       - CASE WHEN {oldStatus} = 4 THEN 1 ELSE 0 END + CASE WHEN {newStatus} = 4 THEN 1 ELSE 0 END,
                       ""Lost""      = ""Lost""      - CASE WHEN {oldStatus} = 5 THEN 1 ELSE 0 END + CASE WHEN {newStatus} = 5 THEN 1 ELSE 0 END
                   WHERE ""UserId"" = {userId}",
                ct
            );

            if (statsUpdated != 1)
            {
                // A proposal without a stats row means broken data. Roll everything back.
                throw new InvalidOperationException("The stats row is missing.");
            }
        }

        await tx.CommitAsync(ct);

        return new UpdateProposalResult.Updated(
            new ProposalResponse(
                id,
                input.Title,
                input.Company,
                input.Platform,
                input.Status,
                input.Budget,
                input.FollowUpDate,
                input.Link,
                input.Notes,
                createdAtMs,
                updatedAtMs
            )
        );
    }
}
