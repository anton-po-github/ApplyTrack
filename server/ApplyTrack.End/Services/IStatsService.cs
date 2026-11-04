using ApplyTrack.End.Models;

namespace ApplyTrack.End.Services;

public interface IStatsService
{
    /// <summary>Null when the user has no stats row (for example, the user was deleted).</summary>
    Task<StatsResponse?> GetAsync(Guid userId, CancellationToken ct);
}
