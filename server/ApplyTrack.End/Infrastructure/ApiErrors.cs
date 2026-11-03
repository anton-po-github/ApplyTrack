using ApplyTrack.End.Models;
using Microsoft.AspNetCore.Http.HttpResults;

namespace ApplyTrack.End.Infrastructure;

/// <summary>Ready-made error answers. One place, so every endpoint answers the same way.</summary>
public static class ApiErrors
{
    public static JsonHttpResult<ErrorResponse> Unauthorized() =>
        TypedResults.Json(
            new ErrorResponse("unauthorized", "Please sign in again."),
            statusCode: StatusCodes.Status401Unauthorized
        );
}
