using System.Text;
using ApplyTrack.End.Security;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace ApplyTrack.End.Tests.Security;

public class JwtTokenServiceTests
{
    private const string Secret = "TEST_SECRET_KEY_THAT_IS_AT_LEAST_32_BYTES_LONG!";
    private const string OtherSecret = "ANOTHER_SECRET_KEY_THAT_IS_AT_LEAST_32_BYTES!!";

    private static JwtTokenService CreateService(FakeTimeProvider time, string secret = Secret) =>
        new(
            Options.Create(
                new JwtOptions
                {
                    Secret = secret,
                    Issuer = "TestIssuer",
                    Audience = "TestAudience",
                }
            ),
            time
        );

    // Same rules the real server uses to check a token.
    private static TokenValidationParameters ServerRules(string secret) =>
        new()
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
            ValidateIssuer = true,
            ValidIssuer = "TestIssuer",
            ValidateAudience = true,
            ValidAudience = "TestAudience",
            ValidateLifetime = true,
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
        };

    [Fact]
    public async Task Create_TokenPassesServerRules_AndHoldsUserId()
    {
        var time = new FakeTimeProvider(DateTimeOffset.UtcNow);
        var userId = Guid.CreateVersion7();

        TokenResult token = CreateService(time).Create(userId);

        var result = await new JsonWebTokenHandler().ValidateTokenAsync(
            token.Token,
            ServerRules(Secret)
        );

        Assert.True(result.IsValid);
        Assert.Equal(userId.ToString("D"), result.ClaimsIdentity.FindFirst("sub")?.Value);
    }

    [Fact]
    public void Create_ExpiresInTwelveHours()
    {
        var start = DateTimeOffset.UtcNow;
        var time = new FakeTimeProvider(start);

        TokenResult token = CreateService(time).Create(Guid.CreateVersion7());

        Assert.Equal(start.AddHours(12).ToUnixTimeSeconds(), token.ExpiresAtUnixSeconds);
    }

    [Fact]
    public async Task Create_TokenFromOtherKey_IsRejected()
    {
        var time = new FakeTimeProvider(DateTimeOffset.UtcNow);

        TokenResult token = CreateService(time, OtherSecret).Create(Guid.CreateVersion7());

        var result = await new JsonWebTokenHandler().ValidateTokenAsync(
            token.Token,
            ServerRules(Secret)
        );

        Assert.False(result.IsValid);
    }

    [Fact]
    public void Create_TwoTokens_HaveDifferentJti()
    {
        var time = new FakeTimeProvider(DateTimeOffset.UtcNow);
        JwtTokenService service = CreateService(time);
        var userId = Guid.CreateVersion7();

        string first = new JsonWebToken(service.Create(userId).Token).Id;
        string second = new JsonWebToken(service.Create(userId).Token).Id;

        Assert.NotEqual(first, second);
    }

    [Fact]
    public void Constructor_ShortSecret_Throws()
    {
        var time = new FakeTimeProvider(DateTimeOffset.UtcNow);

        Assert.Throws<InvalidOperationException>(() => CreateService(time, "too short"));
    }
}
