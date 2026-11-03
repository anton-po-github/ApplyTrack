using ApplyTrack.End.Infrastructure;
using ApplyTrack.End.Models;
using ApplyTrack.End.Services;
using ApplyTrack.End.Validation;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

namespace ApplyTrack.End.Endpoints;

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        RouteGroupBuilder group = app.MapGroup("/api/auth")
            .RequireRateLimiting(SecurityExtensions.AuthLimiterPolicy)
            .AllowAnonymous();

        group.MapPost(
            "/signup",
            async Task<
                Results<
                    JsonHttpResult<AuthResponse>,
                    BadRequest<ErrorResponse>,
                    Conflict<ErrorResponse>
                >
            > ([FromBody] SignupRequest? request, IAuthService auth, CancellationToken ct) =>
            {
                SignupValidation check = AuthValidator.ValidateSignup(request);
                if (check.Input is null)
                {
                    return TypedResults.BadRequest(
                        new ErrorResponse("validation", "Please fix the fields.", check.Errors)
                    );
                }

                SignupResult result = await auth.SignupAsync(check.Input, ct);

                switch (result)
                {
                    case SignupResult.Created created:
                        return TypedResults.Json(
                            created.Auth,
                            statusCode: StatusCodes.Status201Created
                        );

                    case SignupResult.EmailTaken:
                        const string taken = "This email is already in use.";
                        return TypedResults.Conflict(
                            new ErrorResponse(
                                "email_taken",
                                taken,
                                new Dictionary<string, string> { ["email"] = taken }
                            )
                        );

                    default:
                        throw new InvalidOperationException("Unknown signup result.");
                }
            }
        );

        group.MapPost(
            "/signin",
            async Task<
                Results<Ok<AuthResponse>, BadRequest<ErrorResponse>, JsonHttpResult<ErrorResponse>>
            > ([FromBody] SigninRequest? request, IAuthService auth, CancellationToken ct) =>
            {
                SigninValidation check = AuthValidator.ValidateSignin(request);
                if (check.Input is null)
                {
                    return TypedResults.BadRequest(
                        new ErrorResponse("validation", "Please fix the fields.", check.Errors)
                    );
                }

                SigninResult result = await auth.SigninAsync(check.Input, ct);

                switch (result)
                {
                    case SigninResult.Succeeded ok:
                        return TypedResults.Ok(ok.Auth);

                    case SigninResult.InvalidCredentials:
                        // Same answer for "no such email" and "wrong password".
                        return TypedResults.Json(
                            new ErrorResponse("invalid_credentials", "Invalid email or password."),
                            statusCode: StatusCodes.Status401Unauthorized
                        );

                    default:
                        throw new InvalidOperationException("Unknown signin result.");
                }
            }
        );
    }
}
