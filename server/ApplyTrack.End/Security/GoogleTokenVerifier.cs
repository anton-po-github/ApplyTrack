using Google.Apis.Auth;

namespace ApplyTrack.End.Security;

public sealed class GoogleTokenVerifier(string clientId, ILogger<GoogleTokenVerifier> logger)
    : IGoogleTokenVerifier
{
    // Only tokens made for OUR client id are accepted.
    private readonly GoogleJsonWebSignature.ValidationSettings _settings = new()
    {
        Audience = [clientId],
    };

    public async Task<GoogleIdentity?> VerifyAsync(string credential, CancellationToken ct)
    {
        // Cheap server-side check: a JWT has exactly 3 parts and a sane size.
        if (!LooksLikeJwt(credential))
        {
            logger.LogWarning("[AUTH FAULT] Google token rejected: bad format");
            return null;
        }

        try
        {
            GoogleJsonWebSignature.Payload payload = await GoogleJsonWebSignature
                .ValidateAsync(credential, _settings)
                .WaitAsync(ct);

            return new GoogleIdentity(
                payload.Subject,
                payload.Email ?? string.Empty,
                payload.EmailVerified,
                payload.Name
            );
        }
        catch (Exception ex) when (ex is InvalidJwtException or FormatException)
        {
            // The token itself is never logged.
            logger.LogWarning("[AUTH FAULT] Google token rejected: {Reason}", ex.Message);
            return null;
        }
    }

    private const int MaxTokenLength = 4096;

    // O(1) in practice: length is capped, so the scan is bounded.
    private static bool LooksLikeJwt(string? token)
    {
        if (string.IsNullOrEmpty(token) || token.Length > MaxTokenLength)
            return false;

        int dots = 0;
        foreach (char c in token)
        {
            if (c == '.')
            {
                dots++;
                continue;
            }
            bool ok = char.IsAsciiLetterOrDigit(c) || c is '-' or '_';
            if (!ok)
                return false;
        }
        return dots == 2;
    }
}
