using System.Net;
using System.Net.Http.Json;
using ApplyTrack.End.Models;
using ApplyTrack.End.Security;
using ApplyTrack.End.Tests.Support;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class MeEndpointTests(ApiFactory factory)
{
    private const string MeUrl = "/api/auth/me";
    private readonly HttpClient _client = factory.CreateClient();

    // Makes tokens with the REAL secret, issuer and audience of the test server.
    private JwtTokenService TokenService(FakeTimeProvider time, string? otherSecret = null)
    {
        JwtOptions real = factory.Services.GetRequiredService<IOptions<JwtOptions>>().Value;

        return new JwtTokenService(
            Options.Create(
                new JwtOptions
                {
                    Secret = otherSecret ?? real.Secret,
                    Issuer = real.Issuer,
                    Audience = real.Audience,
                }
            ),
            time
        );
    }

    private async Task<HttpStatusCode> GetMeAsync(string token)
    {
        var response = await _client.SendAsync(ApiTestHelpers.Authed(HttpMethod.Get, MeUrl, token));
        return response.StatusCode;
    }

    [Fact]
    public async Task ValidToken_Returns200_WithTheSameProfile()
    {
        AuthResponse signedUp = await _client.SignupAsync();

        var response = await _client.SendAsync(
            ApiTestHelpers.Authed(HttpMethod.Get, MeUrl, signedUp.Token)
        );

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        UserProfile? me = await response.Content.ReadFromJsonAsync<UserProfile>();
        Assert.Equal(signedUp.User, me);
    }

    [Fact]
    public async Task NoToken_Returns401()
    {
        var response = await _client.GetAsync(MeUrl);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GarbageToken_Returns401()
    {
        Assert.Equal(HttpStatusCode.Unauthorized, await GetMeAsync("abc"));
    }

    [Fact]
    public async Task ExpiredToken_Returns401()
    {
        var time = new FakeTimeProvider(DateTimeOffset.UtcNow.AddHours(-13)); // 12 h life + 1 h
        string token = TokenService(time).Create(Guid.CreateVersion7()).Token;

        Assert.Equal(HttpStatusCode.Unauthorized, await GetMeAsync(token));
    }

    [Fact]
    public async Task TokenSignedWithOtherSecret_Returns401()
    {
        var time = new FakeTimeProvider(DateTimeOffset.UtcNow);
        string token = TokenService(time, "ANOTHER_SECRET_KEY_THAT_IS_AT_LEAST_32_BYTES!!")
            .Create(Guid.CreateVersion7())
            .Token;

        Assert.Equal(HttpStatusCode.Unauthorized, await GetMeAsync(token));
    }

    [Fact]
    public async Task ValidToken_ForUnknownUser_Returns401()
    {
        var time = new FakeTimeProvider(DateTimeOffset.UtcNow);
        string token = TokenService(time).Create(Guid.CreateVersion7()).Token; // user never created

        var response = await _client.SendAsync(ApiTestHelpers.Authed(HttpMethod.Get, MeUrl, token));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("unauthorized", error.Code);
    }

    [Fact]
    public async Task Ping_StaysPublic()
    {
        var response = await _client.GetAsync("/api/ping");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
