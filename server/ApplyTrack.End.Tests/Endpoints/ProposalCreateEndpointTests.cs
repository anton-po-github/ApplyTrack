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
public class ProposalCreateEndpointTests(ApiFactory factory)
{
    private const string Url = "/api/proposals";
    private readonly HttpClient _client = factory.CreateClient();

    private async Task<int> CountAsync(string sql, params object[] args)
    {
        using IServiceScope scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
        return await db.Database.SqlQueryRaw<int>(sql, args).SingleAsync();
    }

    private Task<int> ProposalRowsAsync(Guid userId) =>
        CountAsync(
            "SELECT COUNT(*)::int AS \"Value\" FROM \"Proposals\" WHERE \"UserId\" = {0}",
            userId
        );

    // Pretend the user already has this many proposals (keeps the CHECK: Total = sum).
    private async Task SetLiveCountAsync(Guid userId, int count)
    {
        using IServiceScope scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
        await db.Database.ExecuteSqlInterpolatedAsync(
            $@"UPDATE ""UserStats"" SET ""Total"" = {count}, ""Draft"" = {count} WHERE ""UserId"" = {userId}"
        );
    }

    [Fact]
    public async Task ValidRequest_Returns201_AndSavesTheRowForTheTokenUser()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await _client.PostProposalAsync(
            user.Token,
            new
            {
                title = "  Build a Flutter app  ",
                company = "Acme",
                platform = 1,
                status = 2,
                budget = 1500.50m,
                followUpDate = "2026-12-01",
                link = "https://www.upwork.com/jobs/~01",
                notes = "Call on Monday",
            }
        );

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        ProposalResponse p = (await response.Content.ReadFromJsonAsync<ProposalResponse>())!;
        Assert.Equal($"/api/proposals/{p.Id}", response.Headers.Location!.OriginalString);
        Assert.Equal(7, p.Id.Version);
        Assert.Equal("Build a Flutter app", p.Title);
        Assert.Equal("Acme", p.Company);
        Assert.Equal(1, p.Platform);
        Assert.Equal(2, p.Status);
        Assert.Equal(1500.50m, p.Budget);
        Assert.Equal(new DateOnly(2026, 12, 1), p.FollowUpDate);
        Assert.Equal("https://www.upwork.com/jobs/~01", p.Link);
        Assert.Equal("Call on Monday", p.Notes);
        Assert.True(p.CreatedAtMs > 1_000_000_000_000);
        Assert.Equal(p.CreatedAtMs, p.UpdatedAtMs);

        int rows = await CountAsync(
            "SELECT COUNT(*)::int AS \"Value\" FROM \"Proposals\" WHERE \"Id\" = {0} AND \"UserId\" = {1} AND \"DeletedAtMs\" IS NULL",
            p.Id,
            user.User.Id
        );
        Assert.Equal(1, rows);
    }

    [Fact]
    public async Task MinimalRequest_Returns201_WithNullOptionals()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal());

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        ProposalResponse p = (await response.Content.ReadFromJsonAsync<ProposalResponse>())!;
        Assert.Null(p.Company);
        Assert.Null(p.Budget);
        Assert.Null(p.FollowUpDate);
        Assert.Null(p.Link);
        Assert.Null(p.Notes);
    }

    [Fact]
    public async Task Counters_FollowTheStatusOfEachCreatedProposal()
    {
        AuthResponse user = await _client.SignupAsync();

        await _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal(status: 0));
        await _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal(status: 1));
        await _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal(status: 1));

        StatsResponse stats = await _client.GetStatsAsync(user.Token);
        Assert.Equal(new StatsResponse(3, 1, 2, 0, 0, 0, 0), stats);
    }

    [Fact]
    public async Task NoToken_Returns401()
    {
        var response = await _client.PostAsJsonAsync(Url, ApiTestHelpers.ValidProposal());

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task InvalidPayload_Returns400_AndChangesNothing()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await _client.PostProposalAsync(
            user.Token,
            new
            {
                title = "ab",
                platform = 9,
                status = -1,
                budget = -5,
                followUpDate = "nope",
                link = "ftp://x",
                notes = new string('n', 2001),
            }
        );

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("validation", error.Code);
        Assert.Equal(7, error.Fields!.Count);

        Assert.Equal(0, await ProposalRowsAsync(user.User.Id));
        Assert.Equal(
            new StatsResponse(0, 0, 0, 0, 0, 0, 0),
            await _client.GetStatsAsync(user.Token)
        );
    }

    [Fact]
    public async Task WrongJsonType_Returns400_BadRequest()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await _client.PostProposalAsync(
            user.Token,
            new
            {
                title = "Valid title",
                platform = "Upwork",
                status = 0,
            }
        );

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("bad_request", error.Code);
    }

    [Fact]
    public async Task ClientCannotChooseOwnerIdOrTimestamps()
    {
        AuthResponse user = await _client.SignupAsync();
        AuthResponse victim = await _client.SignupAsync();
        Guid fakeId = Guid.NewGuid();

        var response = await _client.PostProposalAsync(
            user.Token,
            new
            {
                title = "Mass assignment try",
                platform = 0,
                status = 0,
                userId = victim.User.Id,
                id = fakeId,
                createdAtMs = 1,
            }
        );

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        ProposalResponse p = (await response.Content.ReadFromJsonAsync<ProposalResponse>())!;
        Assert.NotEqual(fakeId, p.Id);
        Assert.True(p.CreatedAtMs > 1_000_000_000_000);

        Assert.Equal(1, await ProposalRowsAsync(user.User.Id));
        Assert.Equal(0, await ProposalRowsAsync(victim.User.Id));
        Assert.Equal(0, (await _client.GetStatsAsync(victim.Token)).Total);
    }

    [Fact]
    public async Task At500_NewProposalGets409_AndNothingChanges()
    {
        AuthResponse user = await _client.SignupAsync();
        await SetLiveCountAsync(user.User.Id, 499);

        var last = await _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal());
        var tooMany = await _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal());

        Assert.Equal(HttpStatusCode.Created, last.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, tooMany.StatusCode);
        ErrorResponse error = (await tooMany.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("proposal_limit", error.Code);

        Assert.Equal(500, (await _client.GetStatsAsync(user.Token)).Total);
        Assert.Equal(1, await ProposalRowsAsync(user.User.Id));
    }

    [Fact]
    public async Task FiveCreatesAtTheSameTime_With2FreeSlots_OnlyTwoWin()
    {
        AuthResponse user = await _client.SignupAsync();
        await SetLiveCountAsync(user.User.Id, 498);

        HttpResponseMessage[] responses = await Task.WhenAll(
            Enumerable
                .Range(0, 5)
                .Select(_ => _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal()))
        );

        Assert.Equal(2, responses.Count(r => r.StatusCode == HttpStatusCode.Created));
        Assert.Equal(3, responses.Count(r => r.StatusCode == HttpStatusCode.Conflict));
        Assert.Equal(500, (await _client.GetStatsAsync(user.Token)).Total);
        Assert.Equal(2, await ProposalRowsAsync(user.User.Id));
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

        var response = await _client.PostProposalAsync(token, ApiTestHelpers.ValidProposal());

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
