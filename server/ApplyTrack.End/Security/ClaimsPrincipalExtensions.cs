using System.Security.Claims;
using Microsoft.IdentityModel.JsonWebTokens;

namespace ApplyTrack.End.Security;

public static class ClaimsPrincipalExtensions
{
    /// <summary>
    /// Reads the user id from the "sub" claim of a token the server already checked.
    /// False if the claim is missing, not a real id, or empty.
    /// </summary>
    public static bool TryGetUserId(this ClaimsPrincipal principal, out Guid userId)
    {
        string? sub = principal.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;

        return Guid.TryParseExact(sub, "D", out userId) && userId != Guid.Empty;
    }
}
