using ApplyTrack.End.Models;
using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Tests.Validation;

public class SigninValidatorTests
{
    [Fact]
    public void Valid_Request_IsCleaned()
    {
        var result = AuthValidator.ValidateSignin(
            new SigninRequest("  User@Example.COM ", "  secret  ")
        );

        Assert.NotNull(result.Input);
        Assert.Equal("user@example.com", result.Input.Email);
        Assert.Equal("  secret  ", result.Input.Password); // passwords are never trimmed
    }

    [Fact]
    public void NullRequest_FailsBothFields()
    {
        var result = AuthValidator.ValidateSignin(null);

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("email"));
        Assert.True(result.Errors.ContainsKey("password"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void EmptyEmail_IsRejected(string email)
    {
        var result = AuthValidator.ValidateSignin(new SigninRequest(email, "password123"));

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("email"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void EmptyPassword_IsRejected(string password)
    {
        var result = AuthValidator.ValidateSignin(new SigninRequest("a@b.com", password));

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("password"));
    }

    [Fact]
    public void PasswordOver128_IsRejected()
    {
        var result = AuthValidator.ValidateSignin(
            new SigninRequest("a@b.com", new string('x', 129))
        );

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("password"));
    }

    [Fact]
    public void EmailOver255_IsRejected()
    {
        var result = AuthValidator.ValidateSignin(
            new SigninRequest(new string('a', 256), "password123")
        );

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("email"));
    }
}
