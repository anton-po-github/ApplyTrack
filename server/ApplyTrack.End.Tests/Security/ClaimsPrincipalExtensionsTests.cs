using System.Security.Claims;
using ApplyTrack.End.Security;

namespace ApplyTrack.End.Tests.Security;

public class ClaimsPrincipalExtensionsTests
{
    private static ClaimsPrincipal WithSub(string? sub)
    {
        var identity = new ClaimsIdentity("test");
        if (sub is not null)
        {
            identity.AddClaim(new Claim("sub", sub));
        }
        return new ClaimsPrincipal(identity);
    }

    [Fact]
    public void ValidSub_ReturnsTrue_AndTheId()
    {
        var id = Guid.CreateVersion7();

        bool ok = WithSub(id.ToString("D")).TryGetUserId(out Guid result);

        Assert.True(ok);
        Assert.Equal(id, result);
    }

    [Theory]
    [InlineData(null)] // no sub claim at all
    [InlineData("")]
    [InlineData("not-a-guid")]
    [InlineData("00000000-0000-0000-0000-000000000000")] // empty id
    public void BadSub_ReturnsFalse(string? sub)
    {
        Assert.False(WithSub(sub).TryGetUserId(out _));
    }

    [Fact]
    public void OtherGuidFormats_AreRejected()
    {
        string noHyphens = Guid.CreateVersion7().ToString("N");

        Assert.False(WithSub(noHyphens).TryGetUserId(out _));
    }
}
