using System.Collections.Concurrent;
using ApplyTrack.End.Security;

namespace ApplyTrack.End.Tests.Support;

/// <summary>Stands in for Google in tests. Tests "print" their own tokens here.</summary>
public sealed class FakeGoogleTokenVerifier : IGoogleTokenVerifier
{
    private readonly ConcurrentDictionary<string, GoogleIdentity> _tokens = new();

    public string Register(string email, bool emailVerified = true, string? name = "Test User")
    {
        string token = $"fake-{Guid.NewGuid():N}";
        _tokens[token] = new GoogleIdentity($"sub-{Guid.NewGuid():N}", email, emailVerified, name);
        return token;
    }

    public Task<GoogleIdentity?> VerifyAsync(string credential, CancellationToken ct) =>
        Task.FromResult(_tokens.TryGetValue(credential, out GoogleIdentity? id) ? id : null);
}
