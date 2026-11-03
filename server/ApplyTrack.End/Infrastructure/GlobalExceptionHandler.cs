using ApplyTrack.End.Models;
using Microsoft.AspNetCore.Diagnostics;

namespace ApplyTrack.End.Infrastructure;

/// <summary>
/// Catches every unhandled exception.
/// Logs the details on the server. Sends only a generic message to the client.
/// </summary>
public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken
    )
    {
        logger.LogError(
            exception,
            "[SERVER FAULT] Unhandled exception on {Path}",
            httpContext.Request.Path
        );

        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;

        await httpContext.Response.WriteAsJsonAsync(
            new ErrorResponse("server_error", "Something went wrong."),
            cancellationToken
        );

        return true;
    }
}
