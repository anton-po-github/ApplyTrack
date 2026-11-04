using ApplyTrack.End.Security;
using Microsoft.Extensions.Logging.Abstractions;

namespace ApplyTrack.End.Tests.Security;

public class GoogleTokenVerifierTests
{
    // Garbage fails while reading the token, before any call to Google. No network needed.
    [Theory]
    [InlineData("abc")]
    [InlineData("a.b.c")]
    public async Task GarbageToken_ReturnsNull_DoesNotThrow(string garbage)
    {
        var verifier = new GoogleTokenVerifier(
            "test-client.apps.googleusercontent.com",
            NullLogger<GoogleTokenVerifier>.Instance
        );

        GoogleIdentity? identity = await verifier.VerifyAsync(garbage, CancellationToken.None);

        Assert.Null(identity);
    }
}
