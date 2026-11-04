using System.Net;
using System.Net.Http.Json;
using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class ProposalGetEndpointTests(ApiFactory factory)
{
    private readonly HttpClient _client = factory.CreateClient();

    private Task<HttpResponseMessage> GetAsync(string token, string id) =>
        _client.SendAsync(ApiTestHelpers.Authed(HttpMethod.Get, $"/api/proposals/{id}", token));

    private async Task<HttpResponseMessage> CreateAsync(string token, object? body = null)
    {
        var response = await _client.PostProposalAsync(
            token,
            body ?? ApiTestHelpers.ValidProposal()
        );
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return response;
    }

    [Fact]
    public async Task OwnProposal_Returns200_WithAllFields_AndLocationHeaderWorks()
    {
        AuthResponse user = await _client.SignupAsync();
        var createResponse = await CreateAsync(
            user.Token,
            new
            {
                title = "Build a Flutter app",
                company = "Acme",
                platform = 2,
                status = 3,
                budget = 1500.50m,
                followUpDate = "2026-12-01",
                link = "https://www.upwork.com/jobs/~01",
                notes = "Call on Monday",
            }
        );
        ProposalResponse created = (
            await createResponse.Content.ReadFromJsonAsync<ProposalResponse>()
        )!;

        // The Location header from Step 6 must now point to a working address.
        var response = await _client.SendAsync(
            ApiTestHelpers.Authed(
                HttpMethod.Get,
                createResponse.Headers.Location!.OriginalString,
                user.Token
            )
        );

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        ProposalResponse loaded = (await response.Content.ReadFromJsonAsync<ProposalResponse>())!;
        Assert.Equal(created, loaded);
        Assert.Equal(2, loaded.Platform);
        Assert.Equal(3, loaded.Status);
        Assert.Equal(1500.50m, loaded.Budget);
        Assert.Equal(new DateOnly(2026, 12, 1), loaded.FollowUpDate);
    }

    [Fact]
    public async Task MinimalProposal_ReturnsNullOptionals()
    {
        AuthResponse user = await _client.SignupAsync();
        var createResponse = await CreateAsync(user.Token);
        ProposalResponse created = (
            await createResponse.Content.ReadFromJsonAsync<ProposalResponse>()
        )!;

        var response = await GetAsync(user.Token, created.Id.ToString());

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        ProposalResponse loaded = (await response.Content.ReadFromJsonAsync<ProposalResponse>())!;
        Assert.Null(loaded.Company);
        Assert.Null(loaded.Budget);
        Assert.Null(loaded.FollowUpDate);
        Assert.Null(loaded.Link);
        Assert.Null(loaded.Notes);
    }

    [Fact]
    public async Task NoToken_Returns401()
    {
        var response = await _client.GetAsync($"/api/proposals/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task UnknownId_Returns404()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await GetAsync(user.Token, Guid.NewGuid().ToString());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("not_found", error.Code);
    }

    [Fact]
    public async Task OtherUsersProposal_Returns404_ExactlyLikeAnUnknownId()
    {
        AuthResponse owner = await _client.SignupAsync();
        AuthResponse stranger = await _client.SignupAsync();
        var createResponse = await CreateAsync(owner.Token);
        ProposalResponse created = (
            await createResponse.Content.ReadFromJsonAsync<ProposalResponse>()
        )!;

        var foreign = await GetAsync(stranger.Token, created.Id.ToString());
        var unknown = await GetAsync(stranger.Token, Guid.NewGuid().ToString());

        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        Assert.Equal(unknown.StatusCode, foreign.StatusCode);
        Assert.Equal(
            await unknown.Content.ReadAsStringAsync(),
            await foreign.Content.ReadAsStringAsync()
        ); // same body: nothing leaks

        // The owner still sees it.
        var own = await GetAsync(owner.Token, created.Id.ToString());
        Assert.Equal(HttpStatusCode.OK, own.StatusCode);
    }

    [Fact]
    public async Task SoftDeletedProposal_Returns404()
    {
        AuthResponse user = await _client.SignupAsync();
        var createResponse = await CreateAsync(user.Token);
        ProposalResponse created = (
            await createResponse.Content.ReadFromJsonAsync<ProposalResponse>()
        )!;

        using (IServiceScope scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
            long nowMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            Guid id = created.Id;
            await db.Database.ExecuteSqlInterpolatedAsync(
                $@"UPDATE ""Proposals"" SET ""DeletedAtMs"" = {nowMs} WHERE ""Id"" = {id}"
            );
        }

        var response = await GetAsync(user.Token, created.Id.ToString());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Theory]
    [InlineData("abc")]
    [InlineData("123")]
    public async Task InvalidId_Returns400_BadRequest(string id)
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await GetAsync(user.Token, id);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("bad_request", error.Code);
    }

    [Fact]
    public async Task Response_NeverContainsOwnerOrDeleteFields()
    {
        AuthResponse user = await _client.SignupAsync();
        var createResponse = await CreateAsync(user.Token);
        ProposalResponse created = (
            await createResponse.Content.ReadFromJsonAsync<ProposalResponse>()
        )!;

        var response = await GetAsync(user.Token, created.Id.ToString());
        string raw = await response.Content.ReadAsStringAsync();

        Assert.DoesNotContain("userId", raw, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("deletedAt", raw, StringComparison.OrdinalIgnoreCase);
    }
}
