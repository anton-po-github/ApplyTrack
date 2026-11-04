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
}
