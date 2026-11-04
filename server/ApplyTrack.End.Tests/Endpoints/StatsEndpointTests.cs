using System.Net;
using System.Net.Http.Json;
using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Security;
using ApplyTrack.End.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class StatsEndpointTests(ApiFactory factory)
{
    private const string StatsUrl = "/api/stats";
    private readonly HttpClient _client = factory.CreateClient();

    private Task<HttpResponseMessage> GetStatsAsync(string token) =>
        _client.SendAsync(ApiTestHelpers.Authed(HttpMethod.Get, StatsUrl, token));

    [Fact]
    public async Task NoToken_Returns401()
    {
        var response = await _client.GetAsync(StatsUrl);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task NewUser_GetsAllZeros()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await GetStatsAsync(user.Token);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        StatsResponse stats = (await response.Content.ReadFromJsonAsync<StatsResponse>())!;
        Assert.Equal(new StatsResponse(0, 0, 0, 0, 0, 0, 0), stats);
    }

    [Fact]
    public async Task ReadsTheStoredCounters_EachColumnToItsOwnField()
    {
        AuthResponse user = await _client.SignupAsync();

        // Different number per column, so a swapped field cannot hide.
        using (IServiceScope scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
            Guid id = user.User.Id;
            await db.Database.ExecuteSqlInterpolatedAsync(
                $@"UPDATE ""UserStats""
                   SET ""Total"" = 21, ""Draft"" = 1, ""Sent"" = 2, ""Viewed"" = 3,
                       ""Interview"" = 4, ""Won"" = 5, ""Lost"" = 6
                   WHERE ""UserId"" = {id}"
            );
        }

        var response = await GetStatsAsync(user.Token);

        StatsResponse stats = (await response.Content.ReadFromJsonAsync<StatsResponse>())!;
        Assert.Equal(new StatsResponse(21, 1, 2, 3, 4, 5, 6), stats);
    }

    [Fact]
    public async Task EachUser_SeesOnlyTheirOwnStats()
    {
        AuthResponse first = await _client.SignupAsync();
        AuthResponse second = await _client.SignupAsync();

        using (IServiceScope scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
            Guid id = first.User.Id;
            await db.Database.ExecuteSqlInterpolatedAsync(
                $@"UPDATE ""UserStats"" SET ""Total"" = 1, ""Draft"" = 1 WHERE ""UserId"" = {id}"
            );
        }

        var response = await GetStatsAsync(second.Token);

        StatsResponse stats = (await response.Content.ReadFromJsonAsync<StatsResponse>())!;
        Assert.Equal(0, stats.Total);
    }

    [Fact]
    public async Task ValidToken_ForUnknownUser_Returns401()
    {
        JwtOptions real = factory.Services.GetRequiredService<IOptions<JwtOptions>>().Value;
        var tokens = new JwtTokenService(
            Options.Create(real),
            new FakeTimeProvider(DateTimeOffset.UtcNow)
        );
        string token = tokens.Create(Guid.CreateVersion7()).Token; // user never created

        var response = await GetStatsAsync(token);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
