using ApplyTrack.End.Models;
using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Services;

/// <summary>Every expected outcome of signup. The endpoint must handle each one.</summary>
public abstract record SignupResult
{
    private SignupResult() { }

    public sealed record Created(AuthResponse Auth) : SignupResult;

    public sealed record EmailTaken : SignupResult;
}

/// <summary>Every expected outcome of signin.</summary>
public abstract record SigninResult
{
    private SigninResult() { }

    public sealed record Succeeded(AuthResponse Auth) : SigninResult;

    public sealed record InvalidCredentials : SigninResult;
}

public interface IAuthService
{
    Task<SignupResult> SignupAsync(SignupInput input, CancellationToken ct);

    Task<SigninResult> SigninAsync(SigninInput input, CancellationToken ct);

    /// <summary>Null when the user does not exist (for example, was deleted).</summary>
    Task<UserProfile?> GetProfileAsync(Guid userId, CancellationToken ct);
}
