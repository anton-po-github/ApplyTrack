namespace ApplyTrack.End.Security;

/// <summary>What we trust from a Google token after Google's signature check passed.</summary>
public sealed record GoogleIdentity(string Subject, string Email, bool EmailVerified, string? Name);

public interface IGoogleTokenVerifier
{
    /// <summary>Null when the token is invalid, expired, or made for another app.</summary>
    Task<GoogleIdentity?> VerifyAsync(string credential, CancellationToken ct);
}
