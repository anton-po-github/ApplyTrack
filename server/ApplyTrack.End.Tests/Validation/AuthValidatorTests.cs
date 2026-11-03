using ApplyTrack.End.Models;
using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Tests.Validation;

public class AuthValidatorTests
{
    private const string GoodPassword = "password123";

    [Fact]
    public void Valid_Request_IsCleaned()
    {
        var result = AuthValidator.ValidateSignup(
            new SignupRequest("  User@Example.COM ", GoodPassword, "  Anton  ")
        );

        Assert.NotNull(result.Input);
        Assert.Empty(result.Errors);
        Assert.Equal("user@example.com", result.Input.Email);
        Assert.Equal("Anton", result.Input.DisplayName);
        Assert.Equal(GoodPassword, result.Input.Password); // passwords are never trimmed
    }

    [Fact]
    public void NullRequest_FailsAllThreeFields()
    {
        var result = AuthValidator.ValidateSignup(null);

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("email"));
        Assert.True(result.Errors.ContainsKey("password"));
        Assert.True(result.Errors.ContainsKey("displayName"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("plain")]
    [InlineData("a@b")]
    [InlineData("@b.com")]
    [InlineData("a b@c.com")]
    [InlineData("a@@b.com")]
    [InlineData("a@b..com")]
    [InlineData("a@.com")]
    [InlineData("Ünï@b.com")]
    [InlineData("a@b.com,c@d.com")]
    public void BadEmail_IsRejected(string email)
    {
        var result = AuthValidator.ValidateSignup(new SignupRequest(email, GoodPassword, "Anton"));

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("email"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("1234567")] // 7 characters
    public void ShortPassword_IsRejected(string password)
    {
        var result = AuthValidator.ValidateSignup(new SignupRequest("a@b.com", password, "Anton"));

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("password"));
    }

    [Fact]
    public void PasswordLength_Limits_Are8To128()
    {
        Assert.NotNull(
            AuthValidator
                .ValidateSignup(new SignupRequest("a@b.com", new string('x', 8), "A"))
                .Input
        );
        Assert.NotNull(
            AuthValidator
                .ValidateSignup(new SignupRequest("a@b.com", new string('x', 128), "A"))
                .Input
        );
        Assert.Null(
            AuthValidator
                .ValidateSignup(new SignupRequest("a@b.com", new string('x', 129), "A"))
                .Input
        );
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("bad\nname")]
    public void BadDisplayName_IsRejected(string name)
    {
        var result = AuthValidator.ValidateSignup(new SignupRequest("a@b.com", GoodPassword, name));

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("displayName"));
    }

    [Fact]
    public void DisplayNameLength_Limit_Is80()
    {
        Assert.NotNull(
            AuthValidator
                .ValidateSignup(new SignupRequest("a@b.com", GoodPassword, new string('n', 80)))
                .Input
        );
        Assert.Null(
            AuthValidator
                .ValidateSignup(new SignupRequest("a@b.com", GoodPassword, new string('n', 81)))
                .Input
        );
    }
}
