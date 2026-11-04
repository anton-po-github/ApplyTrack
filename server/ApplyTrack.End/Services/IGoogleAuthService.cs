using ApplyTrack.End.Models;
using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Services;

public abstract record GoogleSigninResult
{
    private GoogleSigninResult() { }

    public sealed record Succeeded(AuthResponse Auth) : GoogleSigninResult;

    public sealed record InvalidToken : GoogleSigninResult;

    public sealed record EmailNotSupported : GoogleSigninResult;
}

public interface IGoogleAuthService
{
    Task<GoogleSigninResult> SigninAsync(GoogleSigninInput input, CancellationToken ct);
}
