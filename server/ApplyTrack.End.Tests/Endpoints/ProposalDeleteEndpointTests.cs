using System.Net;
using System.Net.Http.Json;
using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class ProposalDeleteEndpointTests(ApiFactory factory)
{
    private readonly HttpClient _client = factory.CreateClient();

    private Task<ProposalResponse> CreateAsync(string token, int status = 0) =>
        _client.CreateProposalAsync(
            token,
            new
            {
                title = "Proposal to delete",
                platform = 0,
                status,
            }
        );

    private Task<HttpResponseMessage> RawGetAsync(string token, Guid id) =>
        _client.SendAsync(ApiTestHelpers.Authed(HttpMethod.Get, $"/api/proposals/{id}", token));

    private async Task<int> CountAsync(string sql, params object[] args)
    {
        using IServiceScope scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
        return await db.Database.SqlQueryRaw<int>(sql, args).SingleAsync();
    }

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
    public async Task DeleteOwn_Returns204_ThenGetListAndSecondDeleteSayGone()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token);

        var response = await _client.DeleteProposalAsync(user.Token, created.Id);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        Assert.Equal(0, (await response.Content.ReadAsStringAsync()).Length);

        Assert.Equal(
            HttpStatusCode.NotFound,
            (await RawGetAsync(user.Token, created.Id)).StatusCode
        );
        Assert.Empty((await _client.ListProposalsAsync(user.Token)).Items);

        var second = await _client.DeleteProposalAsync(user.Token, created.Id);
        Assert.Equal(HttpStatusCode.NotFound, second.StatusCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(4)]
    [InlineData(5)]
    public async Task Delete_LowersTotalAndExactlyThatStatusCounter(int status)
    {
        AuthResponse user = await _client.SignupAsync();
        int otherStatus = (status + 1) % 6;
        ProposalResponse target = await CreateAsync(user.Token, status);
        await CreateAsync(user.Token, otherStatus);
        Assert.Equal(
            ApiTestHelpers.StatsFor(new[] { status, otherStatus }),
            await _client.GetStatsAsync(user.Token)
        );

        var response = await _client.DeleteProposalAsync(user.Token, target.Id);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        Assert.Equal(
            ApiTestHelpers.StatsFor(new[] { otherStatus }),
            await _client.GetStatsAsync(user.Token)
        );
    }

    [Fact]
    public async Task NoToken_Returns401()
    {
        var response = await _client.DeleteAsync($"/api/proposals/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task UnknownId_Returns404()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await _client.DeleteProposalAsync(user.Token, Guid.NewGuid());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("not_found", error.Code);
    }

    [Fact]
    public async Task OtherUsersProposal_Returns404_AndNothingChanges()
    {
        AuthResponse owner = await _client.SignupAsync();
        AuthResponse stranger = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(owner.Token, status: 0);

        var foreign = await _client.DeleteProposalAsync(stranger.Token, created.Id);
        var unknown = await _client.DeleteProposalAsync(stranger.Token, Guid.NewGuid());

        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        Assert.Equal(
            await unknown.Content.ReadAsStringAsync(),
            await foreign.Content.ReadAsStringAsync()
        ); // same body: nothing leaks

        Assert.Equal(created, await _client.GetProposalAsync(owner.Token, created.Id));
        Assert.Equal(
            ApiTestHelpers.StatsFor(new[] { 0 }),
            await _client.GetStatsAsync(owner.Token)
        );
        Assert.Equal(
            ApiTestHelpers.StatsFor(Array.Empty<int>()),
            await _client.GetStatsAsync(stranger.Token)
        );
    }

    [Fact]
    public async Task InvalidId_Returns400_BadRequest()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await _client.SendAsync(
            ApiTestHelpers.Authed(HttpMethod.Delete, "/api/proposals/abc", user.Token)
        );

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("bad_request", error.Code);
    }

    [Fact]
    public async Task DeletedRow_StaysInTheDatabase_WithItsOwnerAndDeleteTime()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token);

        await _client.DeleteProposalAsync(user.Token, created.Id);

        int rows = await CountAsync(
            "SELECT COUNT(*)::int AS \"Value\" FROM \"Proposals\" WHERE \"Id\" = {0} AND \"UserId\" = {1} AND \"DeletedAtMs\" > 1000000000000",
            created.Id,
            user.User.Id
        );
        Assert.Equal(1, rows); // soft delete: nothing is lost
    }

    [Fact]
    public async Task DeletingFreesASlot_UnderThe500Limit()
    {
        AuthResponse user = await _client.SignupAsync();
        await SetLiveCountAsync(user.User.Id, 499);
        ProposalResponse last = await CreateAsync(user.Token); // now 500

        var blocked = await _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal());
        Assert.Equal(HttpStatusCode.Conflict, blocked.StatusCode);

        var deleted = await _client.DeleteProposalAsync(user.Token, last.Id);
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        var again = await _client.PostProposalAsync(user.Token, ApiTestHelpers.ValidProposal());
        Assert.Equal(HttpStatusCode.Created, again.StatusCode);
        Assert.Equal(500, (await _client.GetStatsAsync(user.Token)).Total);
    }

    [Fact]
    public async Task DeleteThenUpdate_Returns404_AndDoesNotBringTheRowBack()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token, status: 2);
        await _client.DeleteProposalAsync(user.Token, created.Id);

        var update = await _client.PutProposalAsync(
            user.Token,
            created.Id,
            new
            {
                title = "Try to resurrect",
                platform = 0,
                status = 4,
            }
        );

        Assert.Equal(HttpStatusCode.NotFound, update.StatusCode);
        Assert.Equal(
            HttpStatusCode.NotFound,
            (await RawGetAsync(user.Token, created.Id)).StatusCode
        );
        Assert.Equal(
            ApiTestHelpers.StatsFor(Array.Empty<int>()),
            await _client.GetStatsAsync(user.Token)
        );
    }

    [Fact]
    public async Task FiveParallelDeletesOfTheSameProposal_OnlyOneWins_CounterLowersOnce()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse target = await CreateAsync(user.Token, status: 0);
        await CreateAsync(user.Token, status: 1);

        HttpResponseMessage[] responses = await Task.WhenAll(
            Enumerable.Range(0, 5).Select(_ => _client.DeleteProposalAsync(user.Token, target.Id))
        );

        Assert.Equal(1, responses.Count(r => r.StatusCode == HttpStatusCode.NoContent));
        Assert.Equal(4, responses.Count(r => r.StatusCode == HttpStatusCode.NotFound));
        Assert.Equal(ApiTestHelpers.StatsFor(new[] { 1 }), await _client.GetStatsAsync(user.Token));
    }

    [Fact]
    public async Task ParallelDeletesOfDifferentProposals_CountersMatchTheRemainingRows()
    {
        AuthResponse user = await _client.SignupAsync();
        var created = new List<ProposalResponse>();
        foreach (int status in new[] { 0, 1, 2, 3, 4, 5 })
        {
            created.Add(await CreateAsync(user.Token, status));
        }

        HttpResponseMessage[] responses = await Task.WhenAll(
            created.Take(5).Select(p => _client.DeleteProposalAsync(user.Token, p.Id))
        );

        Assert.All(responses, r => Assert.Equal(HttpStatusCode.NoContent, r.StatusCode));
        Assert.Equal(ApiTestHelpers.StatsFor(new[] { 5 }), await _client.GetStatsAsync(user.Token));

        ProposalListResponse list = await _client.ListProposalsAsync(user.Token);
        Assert.Equal(new[] { created[5].Id }, list.Items.Select(i => i.Id).ToArray());
    }
}
