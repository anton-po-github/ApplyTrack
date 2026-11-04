using ApplyTrack.End.Models;
using ApplyTrack.End.Validation;

namespace ApplyTrack.End.Tests.Validation;

public class GoogleSigninValidatorTests
{
    [Fact]
    public void Valid_Credential_IsTrimmed()
    {
        var result = AuthValidator.ValidateGoogleSignin(new GoogleSigninRequest("  abc.def.ghi  "));

        Assert.NotNull(result.Input);
        Assert.Equal("abc.def.ghi", result.Input.Credential);
    }

    [Fact]
    public void NullRequest_IsRejected()
    {
        var result = AuthValidator.ValidateGoogleSignin(null);

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("credential"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void EmptyCredential_IsRejected(string credential)
    {
        var result = AuthValidator.ValidateGoogleSignin(new GoogleSigninRequest(credential));

        Assert.Null(result.Input);
        Assert.True(result.Errors.ContainsKey("credential"));
    }

    [Fact]
    public void CredentialLength_Limit_Is4096()
    {
        Assert.NotNull(
            AuthValidator.ValidateGoogleSignin(new GoogleSigninRequest(new string('x', 4096))).Input
        );
        Assert.Null(
            AuthValidator.ValidateGoogleSignin(new GoogleSigninRequest(new string('x', 4097))).Input
        );
    }
}
