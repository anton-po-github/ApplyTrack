using System.Net;
using System.Net.Http.Json;
using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class ProposalUpdateEndpointTests(ApiFactory factory)
{
    private readonly HttpClient _client = factory.CreateClient();

    // The stats we expect for a list of proposal statuses.
    private static StatsResponse StatsFor(IEnumerable<int> statuses)
    {
        int[] count = new int[6];
        foreach (int status in statuses)
            count[status]++;

        return new StatsResponse(
            count.Sum(),
            count[0],
            count[1],
            count[2],
            count[3],
            count[4],
            count[5]
        );
    }

    private static object Body(string title = "Updated title", int status = 0) =>
        new
        {
            title,
            platform = 0,
            status,
        };

    private Task<ProposalResponse> CreateAsync(string token, int status = 0) =>
        _client.CreateProposalAsync(
            token,
            new
            {
                title = "Original title",
                platform = 0,
                status,
            }
        );

    [Fact]
    public async Task UpdateAllFields_Returns200_AndGetShowsTheSame()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token);
        await Task.Delay(5);

        var response = await _client.PutProposalAsync(
            user.Token,
            created.Id,
            new
            {
                title = "  Updated title  ",
                company = "Acme",
                platform = 2,
                status = 3,
                budget = 250.75m,
                followUpDate = "2026-12-24",
                link = "https://example.com/job",
                notes = "Updated notes",
            }
        );

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        ProposalResponse updated = (await response.Content.ReadFromJsonAsync<ProposalResponse>())!;
        Assert.Equal(created.Id, updated.Id);
        Assert.Equal("Updated title", updated.Title);
        Assert.Equal("Acme", updated.Company);
        Assert.Equal(2, updated.Platform);
        Assert.Equal(3, updated.Status);
        Assert.Equal(250.75m, updated.Budget);
        Assert.Equal(new DateOnly(2026, 12, 24), updated.FollowUpDate);
        Assert.Equal("https://example.com/job", updated.Link);
        Assert.Equal("Updated notes", updated.Notes);
        Assert.Equal(created.CreatedAtMs, updated.CreatedAtMs);
        Assert.True(updated.UpdatedAtMs > created.UpdatedAtMs);

        Assert.Equal(updated, await _client.GetProposalAsync(user.Token, created.Id));
    }

    [Fact]
    public async Task FullReplace_ClearsOptionalFieldsThatAreNotSent()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await _client.CreateProposalAsync(
            user.Token,
            new
            {
                title = "Has everything",
                company = "Acme",
                platform = 1,
                status = 1,
                budget = 100m,
                followUpDate = "2026-12-01",
                link = "https://example.com",
                notes = "Some notes",
            }
        );

        var response = await _client.PutProposalAsync(user.Token, created.Id, Body(status: 1));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        ProposalResponse loaded = await _client.GetProposalAsync(user.Token, created.Id);
        Assert.Null(loaded.Company);
        Assert.Null(loaded.Budget);
        Assert.Null(loaded.FollowUpDate);
        Assert.Null(loaded.Link);
        Assert.Null(loaded.Notes);
    }

    [Fact]
    public async Task SameStatus_LeavesCountersUnchanged()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token, status: 2);

        var response = await _client.PutProposalAsync(
            user.Token,
            created.Id,
            Body(title: "Only the title changed", status: 2)
        );

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(StatsFor(new[] { 2 }), await _client.GetStatsAsync(user.Token));
    }

    [Theory]
    [InlineData(0, 1)]
    [InlineData(1, 0)]
    [InlineData(2, 5)]
    [InlineData(5, 2)]
    [InlineData(3, 4)]
    [InlineData(4, 3)]
    public async Task StatusChange_MovesExactlyOneCount(int from, int to)
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token, status: from);
        Assert.Equal(StatsFor(new[] { from }), await _client.GetStatsAsync(user.Token));

        var response = await _client.PutProposalAsync(user.Token, created.Id, Body(status: to));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(StatsFor(new[] { to }), await _client.GetStatsAsync(user.Token));
    }

    [Fact]
    public async Task NoToken_Returns401()
    {
        HttpRequestMessage request = new(HttpMethod.Put, $"/api/proposals/{Guid.NewGuid()}")
        {
            Content = JsonContent.Create(Body()),
        };

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task UnknownId_Returns404()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await _client.PutProposalAsync(user.Token, Guid.NewGuid(), Body());

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

        var foreign = await _client.PutProposalAsync(stranger.Token, created.Id, Body(status: 4));
        var unknown = await _client.PutProposalAsync(
            stranger.Token,
            Guid.NewGuid(),
            Body(status: 4)
        );

        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        Assert.Equal(
            await unknown.Content.ReadAsStringAsync(),
            await foreign.Content.ReadAsStringAsync()
        ); // same body: nothing leaks

        Assert.Equal(created, await _client.GetProposalAsync(owner.Token, created.Id));
        Assert.Equal(StatsFor(new[] { 0 }), await _client.GetStatsAsync(owner.Token));
        Assert.Equal(StatsFor(Array.Empty<int>()), await _client.GetStatsAsync(stranger.Token));
    }

    [Fact]
    public async Task SoftDeletedProposal_Returns404()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token);

        using (IServiceScope scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
            long nowMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            Guid id = created.Id;
            await db.Database.ExecuteSqlInterpolatedAsync(
                $@"UPDATE ""Proposals"" SET ""DeletedAtMs"" = {nowMs} WHERE ""Id"" = {id}"
            );
        }

        var response = await _client.PutProposalAsync(user.Token, created.Id, Body());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task InvalidPayload_Returns400_AndNothingChanges()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token, status: 1);

        var response = await _client.PutProposalAsync(
            user.Token,
            created.Id,
            new
            {
                title = "ab",
                platform = 9,
                status = 4,
            }
        );

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("validation", error.Code);
        Assert.True(error.Fields!.ContainsKey("title"));
        Assert.True(error.Fields.ContainsKey("platform"));

        Assert.Equal(created, await _client.GetProposalAsync(user.Token, created.Id));
        Assert.Equal(StatsFor(new[] { 1 }), await _client.GetStatsAsync(user.Token));
    }

    [Fact]
    public async Task InvalidId_Returns400_BadRequest()
    {
        AuthResponse user = await _client.SignupAsync();

        HttpRequestMessage request = ApiTestHelpers.Authed(
            HttpMethod.Put,
            "/api/proposals/abc",
            user.Token
        );
        request.Content = JsonContent.Create(Body());
        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("bad_request", error.Code);
    }

    [Fact]
    public async Task WrongJsonType_Returns400_BadRequest()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token);

        var response = await _client.PutProposalAsync(
            user.Token,
            created.Id,
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
    public async Task ClientCannotChangeOwnerIdOrTimestamps()
    {
        AuthResponse user = await _client.SignupAsync();
        AuthResponse victim = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token);

        var response = await _client.PutProposalAsync(
            user.Token,
            created.Id,
            new
            {
                title = "Mass assignment try",
                platform = 0,
                status = 0,
                userId = victim.User.Id,
                id = Guid.NewGuid(),
                createdAtMs = 1,
                updatedAtMs = 1,
                deletedAtMs = 5,
            }
        );

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        ProposalResponse updated = (await response.Content.ReadFromJsonAsync<ProposalResponse>())!;
        Assert.Equal(created.Id, updated.Id);
        Assert.Equal(created.CreatedAtMs, updated.CreatedAtMs);
        Assert.True(updated.UpdatedAtMs > 1_000_000_000_000);

        // Still alive, still owned by the token user, nothing moved to the victim.
        Assert.Equal(
            "Mass assignment try",
            (await _client.GetProposalAsync(user.Token, created.Id)).Title
        );
        Assert.Empty((await _client.ListProposalsAsync(victim.Token)).Items);
    }

    [Fact]
    public async Task FiveParallelUpdatesOfTheSameProposal_CountersStayConsistent()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse created = await CreateAsync(user.Token, status: 0);

        HttpResponseMessage[] responses = await Task.WhenAll(
            Enumerable
                .Range(1, 5)
                .Select(status =>
                    _client.PutProposalAsync(
                        user.Token,
                        created.Id,
                        Body(title: $"Update {status}", status: status)
                    )
                )
        );

        Assert.All(responses, r => Assert.Equal(HttpStatusCode.OK, r.StatusCode));

        // Whichever update ran last, the counters must match the row.
        ProposalResponse final = await _client.GetProposalAsync(user.Token, created.Id);
        Assert.Equal(
            StatsFor(new[] { (int)final.Status }),
            await _client.GetStatsAsync(user.Token)
        );
    }

    [Fact]
    public async Task ParallelUpdatesOfDifferentProposals_CountersMatchTheRows()
    {
        AuthResponse user = await _client.SignupAsync();
        int[] targets = [1, 1, 2, 5, 0];
        var created = new List<ProposalResponse>();
        foreach (int _ in targets)
        {
            created.Add(await CreateAsync(user.Token, status: 0));
        }

        HttpResponseMessage[] responses = await Task.WhenAll(
            created.Select(
                (p, i) => _client.PutProposalAsync(user.Token, p.Id, Body(status: targets[i]))
            )
        );

        Assert.All(responses, r => Assert.Equal(HttpStatusCode.OK, r.StatusCode));
        Assert.Equal(StatsFor(targets), await _client.GetStatsAsync(user.Token));

        ProposalListResponse list = await _client.ListProposalsAsync(user.Token);
        Assert.Equal(
            StatsFor(list.Items.Select(i => (int)i.Status)),
            await _client.GetStatsAsync(user.Token)
        );
    }
}
