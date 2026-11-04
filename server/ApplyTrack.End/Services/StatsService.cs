using ApplyTrack.DB;
using ApplyTrack.End.Models;
using Microsoft.EntityFrameworkCore;

namespace ApplyTrack.End.Services;

public sealed class StatsService(ApplyTrackDbContext db) : IStatsService
{
    public async Task<StatsResponse?> GetAsync(Guid userId, CancellationToken ct)
    {
        // O(1): read by primary key. One small row. No counting over proposals.
        StatsRow? row = await db
            .Database.SqlQuery<StatsRow>(
                $@"SELECT ""Total"", ""Draft"", ""Sent"", ""Viewed"", ""Interview"", ""Won"", ""Lost""
                   FROM ""UserStats""
                   WHERE ""UserId"" = {userId}"
            )
            .FirstOrDefaultAsync(ct);

        return row is null
            ? null
            : new StatsResponse(
                row.Total,
                row.Draft,
                row.Sent,
                row.Viewed,
                row.Interview,
                row.Won,
                row.Lost
            );
    }
}

internal sealed class StatsRow
{
    public int Total { get; set; }
    public int Draft { get; set; }
    public int Sent { get; set; }
    public int Viewed { get; set; }
    public int Interview { get; set; }
    public int Won { get; set; }
    public int Lost { get; set; }
}
