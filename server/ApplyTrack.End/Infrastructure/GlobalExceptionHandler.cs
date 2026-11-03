using ApplyTrack.End.Models;
using Microsoft.AspNetCore.Diagnostics;

namespace ApplyTrack.End.Infrastructure;

public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken
    )
    {
        // The client left. Nobody is listening.
        if (
            exception is OperationCanceledException
            && httpContext.RequestAborted.IsCancellationRequested
        )
        {
            return true;
        }

        // Bad JSON, wrong content type, body too large: the client's fault, not ours.
        if (exception is BadHttpRequestException bad)
        {
            logger.LogWarning(
                "[BAD REQUEST] {Path}: {Message}",
                httpContext.Request.Path,
                bad.Message
            );
            httpContext.Response.StatusCode = bad.StatusCode;
            await httpContext.Response.WriteAsJsonAsync(
                new ErrorResponse("bad_request", "The request is not valid."),
                cancellationToken
            );
            return true;
        }

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
