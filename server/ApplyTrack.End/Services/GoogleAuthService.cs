using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Security;
using ApplyTrack.End.Validation;
using Microsoft.EntityFrameworkCore;

namespace ApplyTrack.End.Services;

public sealed class GoogleAuthService(
    ApplyTrackDbContext db,
    IGoogleTokenVerifier verifier,
    IPasswordHasher hasher,
    ITokenService tokens,
    TimeProvider time,
    ILogger<GoogleAuthService> logger
) : IGoogleAuthService
{
    public async Task<GoogleSigninResult> SigninAsync(GoogleSigninInput input, CancellationToken ct)
    {
        GoogleIdentity? identity = await verifier.VerifyAsync(input.Credential, ct);
        if (identity is null)
        {
            return new GoogleSigninResult.InvalidToken();
        }

        // Without this check, someone could use a Google account with an unproven email.
        if (!identity.EmailVerified)
        {
            logger.LogWarning("[AUTH FAULT] Google email is not verified.");
            return new GoogleSigninResult.InvalidToken();
        }

        string email = (identity.Email ?? string.Empty).Trim().ToLowerInvariant();
        if (!AuthValidator.IsValidEmail(email))
        {
            logger.LogWarning("[AUTH FAULT] Google email cannot be stored.");
            return new GoogleSigninResult.EmailNotSupported();
        }

        string displayName = DisplayNames.FromGoogle(identity.Name, email);
        DateTimeOffset now = time.GetUtcNow();
        Guid newId = Guid.CreateVersion7(now);
        long nowMs = now.ToUnixTimeMilliseconds();
        string unusableHash = hasher.CreateUnusableHash(); // random bytes: cheap, no PBKDF2

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        // Atomic find-or-create. Parallel first sign-ins of one email: exactly one insert wins.
        int inserted = await db.Database.ExecuteSqlInterpolatedAsync(
            $@"INSERT INTO ""Users"" (""Id"", ""Email"", ""DisplayName"", ""PasswordHash"", ""CreatedAtMs"")
               VALUES ({newId}, {email}, {displayName}, {unusableHash}, {nowMs})
               ON CONFLICT (""Email"") DO NOTHING",
            ct
        );

        UserProfile profile;

        if (inserted == 1)
        {
            await db.Database.ExecuteSqlInterpolatedAsync(
                $@"INSERT INTO ""UserStats""
                       (""UserId"", ""Total"", ""Draft"", ""Sent"", ""Viewed"", ""Interview"", ""Won"", ""Lost"")
                   VALUES ({newId}, 0, 0, 0, 0, 0, 0, 0)",
                ct
            );

            profile = new UserProfile(newId, email, displayName);
        }
        else
        {
            ProfileRow existing =
                await db
                    .Database.SqlQuery<ProfileRow>(
                        $@"SELECT ""Id"", ""Email"", ""DisplayName"" FROM ""Users"" WHERE ""Email"" = {email}"
                    )
                    .FirstOrDefaultAsync(ct)
                ?? throw new InvalidOperationException("User vanished after an email conflict.");

            // Our signup does not prove email ownership. If someone pre-registered this email
            // with their own password, that password must not survive a real Google sign-in.
            // The account, its data and its name stay. Only the password stops working.
            await db.Database.ExecuteSqlInterpolatedAsync(
                $@"UPDATE ""Users"" SET ""PasswordHash"" = {unusableHash} WHERE ""Id"" = {existing.Id}",
                ct
            );

            profile = new UserProfile(existing.Id, existing.Email, existing.DisplayName);
        }

        await tx.CommitAsync(ct);

        TokenResult token = tokens.Create(profile.Id);
        return new GoogleSigninResult.Succeeded(
            new AuthResponse(token.Token, token.ExpiresAtUnixSeconds, profile)
        );
    }
}
