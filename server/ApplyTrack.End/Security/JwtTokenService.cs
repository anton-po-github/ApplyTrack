using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace ApplyTrack.End.Security;

public sealed class JwtTokenService : ITokenService
{
    private static readonly TimeSpan Lifetime = TimeSpan.FromHours(12);
    private const int MinSecretBytes = 32;

    private readonly JsonWebTokenHandler _handler = new();
    private readonly SigningCredentials _credentials;
    private readonly JwtOptions _options;
    private readonly TimeProvider _time;

    public JwtTokenService(IOptions<JwtOptions> options, TimeProvider time)
    {
        _options = options.Value;
        _time = time;

        byte[] keyBytes = Encoding.UTF8.GetBytes(_options.Secret);
        if (keyBytes.Length < MinSecretBytes)
        {
            throw new InvalidOperationException("JwtConfig:Secret must be at least 32 bytes.");
        }

        _credentials = new SigningCredentials(
            new SymmetricSecurityKey(keyBytes),
            SecurityAlgorithms.HmacSha256
        );
    }

    public TokenResult Create(Guid userId)
    {
        DateTimeOffset now = _time.GetUtcNow();
        DateTimeOffset expires = now.Add(Lifetime);

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _options.Issuer,
            Audience = _options.Audience,
            Subject = new ClaimsIdentity(
                new[]
                {
                    new Claim(JwtRegisteredClaimNames.Sub, userId.ToString("D")),
                    new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
                }
            ),
            NotBefore = now.UtcDateTime,
            IssuedAt = now.UtcDateTime,
            Expires = expires.UtcDateTime,
            SigningCredentials = _credentials,
        };

        return new TokenResult(_handler.CreateToken(descriptor), expires.ToUnixTimeSeconds());
    }
}
