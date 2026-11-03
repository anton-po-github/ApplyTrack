using ApplyTrack.End.Models;

namespace ApplyTrack.End.Validation;

public sealed record SigninInput(string Email, string Password)
{
    public override string ToString() => nameof(SigninInput); // never print the password
}

public sealed record SigninValidation(
    SigninInput? Input,
    IReadOnlyDictionary<string, string> Errors
);

/// <summary>Clean, validated signup data. Only the validator can make it.</summary>
public sealed record SignupInput(string Email, string Password, string DisplayName)
{
    public override string ToString() => nameof(SignupInput); // never print the password
}

public sealed record SignupValidation(
    SignupInput? Input,
    IReadOnlyDictionary<string, string> Errors
);

public static class AuthValidator
{
    public const int MaxEmailLength = 255;
    public const int MinPasswordLength = 8;
    public const int MaxPasswordLength = 128; // stops huge passwords from burning CPU in PBKDF2
    public const int MaxDisplayNameLength = 80;

    public static SignupValidation ValidateSignup(SignupRequest? request)
    {
        var errors = new Dictionary<string, string>();

        string email = (request?.Email ?? string.Empty).Trim().ToLowerInvariant();
        string password = request?.Password ?? string.Empty;
        string displayName = (request?.DisplayName ?? string.Empty).Trim();

        string? emailError = CheckEmail(email);
        if (emailError is not null)
            errors["email"] = emailError;

        string? passwordError = CheckPassword(password);
        if (passwordError is not null)
            errors["password"] = passwordError;

        string? nameError = CheckDisplayName(displayName);
        if (nameError is not null)
            errors["displayName"] = nameError;

        return errors.Count == 0
            ? new SignupValidation(new SignupInput(email, password, displayName), errors)
            : new SignupValidation(null, errors);
    }

    // Signin checks only "is it there" and "is it sane". It never explains the password rules.
    public static SigninValidation ValidateSignin(SigninRequest? request)
    {
        var errors = new Dictionary<string, string>();

        string email = (request?.Email ?? string.Empty).Trim().ToLowerInvariant();
        string password = request?.Password ?? string.Empty;

        if (email.Length == 0)
            errors["email"] = "Email is required.";
        else if (email.Length > MaxEmailLength)
            errors["email"] = "Email is too long.";

        if (string.IsNullOrWhiteSpace(password))
            errors["password"] = "Password is required.";
        else if (password.Length > MaxPasswordLength)
            errors["password"] = "Password is too long."; // stops CPU abuse in PBKDF2

        return errors.Count == 0
            ? new SigninValidation(new SigninInput(email, password), errors)
            : new SigninValidation(null, errors);
    }

    private static string? CheckEmail(string email)
    {
        if (email.Length == 0)
            return "Email is required.";
        if (email.Length > MaxEmailLength)
            return "Email is too long.";
        return IsEmailShapeValid(email) ? null : "Email format is not valid.";
    }

    // ASCII only: the database CHECK (Email = lower(Email)) must always agree with ToLowerInvariant.
    private static bool IsEmailShapeValid(string email)
    {
        foreach (char c in email)
        {
            if (
                c > 127
                || char.IsWhiteSpace(c)
                || char.IsControl(c)
                || c is ',' or ';' or '<' or '>'
            )
                return false;
        }

        int at = email.IndexOf('@');
        if (at <= 0 || at != email.LastIndexOf('@'))
            return false;

        string local = email[..at];
        string domain = email[(at + 1)..];

        return local.Length <= 64
            && domain.Length >= 3
            && domain.Contains('.')
            && !domain.StartsWith('.')
            && !domain.EndsWith('.')
            && !domain.Contains("..");
    }

    private static string? CheckPassword(string password)
    {
        if (string.IsNullOrWhiteSpace(password))
            return "Password is required.";
        if (password.Length < MinPasswordLength)
            return $"Password must be at least {MinPasswordLength} characters.";
        if (password.Length > MaxPasswordLength)
            return $"Password must be at most {MaxPasswordLength} characters.";
        return null;
    }

    private static string? CheckDisplayName(string name)
    {
        if (name.Length == 0)
            return "Name is required.";
        if (name.Length > MaxDisplayNameLength)
            return $"Name must be at most {MaxDisplayNameLength} characters.";
        if (name.Any(char.IsControl))
            return "Name has invalid characters.";
        return null;
    }
}
