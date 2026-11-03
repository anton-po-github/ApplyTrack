namespace ApplyTrack.DB.Models;

public sealed class User
{
    public Guid Id { get; set; } = Guid.CreateVersion7(); // app-generated, time-ordered

    public required string Email { get; set; } // server lowercases, DB rejects anything else
    public required string DisplayName { get; set; }
    public required string PasswordHash { get; set; } // PBKDF2, Base64
    public required long CreatedAtMs { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
}
