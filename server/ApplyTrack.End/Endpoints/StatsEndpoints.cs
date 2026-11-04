using System.Security.Claims;
using ApplyTrack.End.Infrastructure;
using ApplyTrack.End.Models;
using ApplyTrack.End.Security;
using ApplyTrack.End.Services;
using Microsoft.AspNetCore.Http.HttpResults;

namespace ApplyTrack.End.Endpoints;

public static class StatsEndpoints
{
    public static void MapStatsEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet(
                "/api/stats",
                async Task<Results<Ok<StatsResponse>, JsonHttpResult<ErrorResponse>>> (
                    ClaimsPrincipal user,
                    IStatsService stats,
                    CancellationToken ct
                ) =>
                {
                    if (!user.TryGetUserId(out Guid userId))
                    {
                        return ApiErrors.Unauthorized();
                    }

                    StatsResponse? result = await stats.GetAsync(userId, ct);
                    if (result is null)
                    {
                        return ApiErrors.Unauthorized(); // valid token, but the user is gone
                    }

                    return TypedResults.Ok(result);
                }
            )
            .RequireAuthorization();
    }
}
