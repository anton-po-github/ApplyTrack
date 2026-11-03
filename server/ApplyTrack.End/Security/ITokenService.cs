namespace ApplyTrack.End.Security;

public sealed record TokenResult(string Token, long ExpiresAtUnixSeconds);

public interface ITokenService
{
    TokenResult Create(Guid userId);
}
