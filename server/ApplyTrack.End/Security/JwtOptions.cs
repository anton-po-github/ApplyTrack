namespace ApplyTrack.End.Security;

/// <summary>Bound from the "JwtConfig" section.</summary>
public sealed class JwtOptions
{
    public const string SectionName = "JwtConfig";

    public string Secret { get; init; } = string.Empty;
    public string Issuer { get; init; } = string.Empty;
    public string Audience { get; init; } = string.Empty;
}
