using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Security;
using ApplyTrack.End.Validation;
using Microsoft.EntityFrameworkCore;

namespace ApplyTrack.End.Services;

public sealed class AuthService(
    ApplyTrackDbContext db,
    IPasswordHasher hasher,
    ITokenService tokens,
    TimeProvider time,
    ILogger<AuthService> logger
) : IAuthService
{
    public async Task<SignupResult> SignupAsync(SignupInput input, CancellationToken ct)
    {
        DateTimeOffset now = time.GetUtcNow();
        Guid userId = Guid.CreateVersion7(now);
        long nowMs = now.ToUnixTimeMilliseconds();

        // Slow CPU work first, so the database transaction stays short.
        string passwordHash = hasher.Hash(input.Password);

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        // Atomic. If two requests use the same email, exactly one row is inserted.
        int inserted = await db.Database.ExecuteSqlInterpolatedAsync(
            $@"INSERT INTO ""Users"" (""Id"", ""Email"", ""DisplayName"", ""PasswordHash"", ""CreatedAtMs"")
               VALUES ({userId}, {input.Email}, {input.DisplayName}, {passwordHash}, {nowMs})
               ON CONFLICT (""Email"") DO NOTHING",
            ct
        );

        if (inserted == 0)
        {
            logger.LogInformation("[SIGNUP] Duplicate email rejected.");
            return new SignupResult.EmailTaken(); // transaction is disposed = rollback
        }

        await db.Database.ExecuteSqlInterpolatedAsync(
            $@"INSERT INTO ""UserStats""
                   (""UserId"", ""Total"", ""Draft"", ""Sent"", ""Viewed"", ""Interview"", ""Won"", ""Lost"")
               VALUES ({userId}, 0, 0, 0, 0, 0, 0, 0)",
            ct
        );

        await tx.CommitAsync(ct);

        TokenResult token = tokens.Create(userId);
        var profile = new UserProfile(userId, input.Email, input.DisplayName);

        return new SignupResult.Created(
            new AuthResponse(token.Token, token.ExpiresAtUnixSeconds, profile)
        );
    }

    public async Task<SigninResult> SigninAsync(SigninInput input, CancellationToken ct)
    {
        // O(1): one seek on the unique index of Email.
        SigninRow? user = await db
            .Database.SqlQuery<SigninRow>(
                $@"SELECT ""Id"", ""DisplayName"", ""PasswordHash""
                   FROM ""Users""
                   WHERE ""Email"" = {input.Email}"
            )
            .FirstOrDefaultAsync(ct);

        // ALWAYS run the hash check, even when the user does not exist.
        // With a null hash, Verify does the same work against a dummy hash.
        bool passwordOk = hasher.Verify(input.Password, user?.PasswordHash);

        if (user is null || !passwordOk)
        {
            logger.LogWarning("[AUTH FAULT] Failed signin attempt.");
            return new SigninResult.InvalidCredentials();
        }

        TokenResult token = tokens.Create(user.Id);
        var profile = new UserProfile(user.Id, input.Email, user.DisplayName);

        return new SigninResult.Succeeded(
            new AuthResponse(token.Token, token.ExpiresAtUnixSeconds, profile)
        );
    }
}

/// <summary>The only columns signin needs. Never contains the whole user row.</summary>
internal sealed class SigninRow
{
    public Guid Id { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
}
