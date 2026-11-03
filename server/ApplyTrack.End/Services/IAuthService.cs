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

public interface IAuthService
{
    Task<SignupResult> SignupAsync(SignupInput input, CancellationToken ct);
}
