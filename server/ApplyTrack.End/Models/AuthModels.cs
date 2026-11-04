namespace ApplyTrack.End.Models;

/// <summary>Signup body. Fields are nullable on purpose: the client can send anything.</summary>
public sealed record SignupRequest(string? Email, string? Password, string? DisplayName)
{
    public override string ToString() => nameof(SignupRequest); // never print the password
}

public sealed record UserProfile(Guid Id, string Email, string DisplayName);

public sealed record AuthResponse(string Token, long ExpiresAtUnixSeconds, UserProfile User);

public sealed record SigninRequest(string? Email, string? Password)
{
    public override string ToString() => nameof(SigninRequest); // never print the password
}

public sealed record GoogleSigninRequest(string? Credential)
{
    public override string ToString() => nameof(GoogleSigninRequest); // never print the token
}
