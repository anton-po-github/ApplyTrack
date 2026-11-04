using System.Net;
using System.Net.Http.Json;
using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class ProposalListEndpointTests(ApiFactory factory)
{
    private readonly HttpClient _client = factory.CreateClient();

    private Task<ProposalResponse> CreateAsync(
        string token,
        string title,
        int status = 0,
        string? notes = null,
        string? company = null
    ) =>
        _client.CreateProposalAsync(
            token,
            new
            {
                title,
                platform = 0,
                status,
                notes,
                company,
            }
        );

    private Task<HttpResponseMessage> RawListAsync(string token, string query) =>
        _client.SendAsync(ApiTestHelpers.Authed(HttpMethod.Get, $"/api/proposals?{query}", token));

    [Fact]
    public async Task NoToken_Returns401()
    {
        var response = await _client.GetAsync("/api/proposals");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task NewUser_GetsAnEmptyList()
    {
        AuthResponse user = await _client.SignupAsync();

        ProposalListResponse list = await _client.ListProposalsAsync(user.Token);

        Assert.Empty(list.Items);
        Assert.Null(list.NextCursor);
    }

    [Fact]
    public async Task List_ReturnsNewestFirst_WithAllFields()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse first = await CreateAsync(user.Token, "First proposal");
        await Task.Delay(5);
        ProposalResponse second = await CreateAsync(user.Token, "Second proposal");
        await Task.Delay(5);
        ProposalResponse third = await CreateAsync(user.Token, "Third proposal");

        ProposalListResponse list = await _client.ListProposalsAsync(user.Token);

        Assert.Equal(
            new[] { third.Id, second.Id, first.Id },
            list.Items.Select(i => i.Id).ToArray()
        );
        Assert.Equal(third, list.Items[0]);
        Assert.Null(list.NextCursor);
    }

    [Fact]
    public async Task Paging_WalksAllItems_NoDuplicates_NoGaps()
    {
        AuthResponse user = await _client.SignupAsync();
        var created = new List<ProposalResponse>();
        for (int i = 1; i <= 5; i++)
        {
            created.Add(await CreateAsync(user.Token, $"Proposal {i}"));
            await Task.Delay(5);
        }

        var seen = new List<Guid>();
        Guid? cursor = null;
        int pages = 0;
        do
        {
            string query = cursor is null ? "limit=2" : $"limit=2&cursor={cursor}";
            ProposalListResponse page = await _client.ListProposalsAsync(user.Token, query);

            Assert.True(page.Items.Count <= 2);
            seen.AddRange(page.Items.Select(i => i.Id));
            cursor = page.NextCursor;
            pages++;
            Assert.True(pages <= 5, "Paging does not end.");
        } while (cursor is not null);

        Assert.Equal(3, pages);
        Assert.Equal(created.AsEnumerable().Reverse().Select(c => c.Id), seen);
    }

    [Fact]
    public async Task ExactMultipleOfLimit_LastPageHasNoNextCursor()
    {
        AuthResponse user = await _client.SignupAsync();
        for (int i = 1; i <= 4; i++)
        {
            await CreateAsync(user.Token, $"Proposal {i}");
            await Task.Delay(5);
        }

        ProposalListResponse first = await _client.ListProposalsAsync(user.Token, "limit=2");
        Assert.Equal(2, first.Items.Count);
        Assert.NotNull(first.NextCursor);

        ProposalListResponse second = await _client.ListProposalsAsync(
            user.Token,
            $"limit=2&cursor={first.NextCursor}"
        );
        Assert.Equal(2, second.Items.Count);
        Assert.Null(second.NextCursor);
    }

    [Fact]
    public async Task DefaultLimit_Is20()
    {
        AuthResponse user = await _client.SignupAsync();
        for (int i = 1; i <= 21; i++)
        {
            await CreateAsync(user.Token, $"Proposal {i}");
        }

        ProposalListResponse first = await _client.ListProposalsAsync(user.Token);
        Assert.Equal(20, first.Items.Count);
        Assert.NotNull(first.NextCursor);

        ProposalListResponse second = await _client.ListProposalsAsync(
            user.Token,
            $"cursor={first.NextCursor}"
        );
        Assert.Single(second.Items);
        Assert.Null(second.NextCursor);
    }

    [Fact]
    public async Task StatusFilter_WorksTogetherWithPaging()
    {
        AuthResponse user = await _client.SignupAsync();
        var sent = new List<Guid>();
        foreach (int status in new[] { 1, 0, 1, 1 })
        {
            ProposalResponse p = await CreateAsync(user.Token, $"Item status {status}", status);
            if (status == 1)
                sent.Add(p.Id);
            await Task.Delay(5);
        }

        ProposalListResponse first = await _client.ListProposalsAsync(
            user.Token,
            "status=1&limit=2"
        );
        Assert.Equal(2, first.Items.Count);
        Assert.All(first.Items, i => Assert.Equal(1, i.Status));
        Assert.NotNull(first.NextCursor);

        ProposalListResponse second = await _client.ListProposalsAsync(
            user.Token,
            $"status=1&limit=2&cursor={first.NextCursor}"
        );
        Assert.Single(second.Items);
        Assert.Equal(1, second.Items[0].Status);
        Assert.Null(second.NextCursor);

        Assert.Equal(
            sent.AsEnumerable().Reverse(),
            first.Items.Concat(second.Items).Select(i => i.Id)
        );
    }

    [Fact]
    public async Task Search_IsCaseInsensitive_FindsMiddleOfTitle_AndIgnoresOtherFields()
    {
        AuthResponse user = await _client.SignupAsync();
        await CreateAsync(user.Token, "Flutter app");
        await CreateAsync(user.Token, "React dashboard");
        await CreateAsync(user.Token, "Other job", notes: "flutter notes", company: "Flutter Inc");

        ProposalListResponse upper = await _client.ListProposalsAsync(user.Token, "q=FLUTTER");
        ProposalListResponse middle = await _client.ListProposalsAsync(user.Token, "q=ashboa");

        Assert.Equal(new[] { "Flutter app" }, upper.Items.Select(i => i.Title).ToArray());
        Assert.Equal(new[] { "React dashboard" }, middle.Items.Select(i => i.Title).ToArray());
    }

    [Theory]
    [InlineData("%", "100% sure job")]
    [InlineData("_", "snake_case job")]
    [InlineData(@"\", @"path\to job")]
    public async Task Search_SpecialCharacters_AreLiteral(string q, string expectedTitle)
    {
        AuthResponse user = await _client.SignupAsync();
        await CreateAsync(user.Token, "100% sure job");
        await CreateAsync(user.Token, "snake_case job");
        await CreateAsync(user.Token, @"path\to job");
        await CreateAsync(user.Token, "Plain boring job");

        ProposalListResponse list = await _client.ListProposalsAsync(
            user.Token,
            $"q={Uri.EscapeDataString(q)}"
        );

        Assert.Equal(new[] { expectedTitle }, list.Items.Select(i => i.Title).ToArray());
    }

    [Fact]
    public async Task StatusAndSearch_CombineWithAnd()
    {
        AuthResponse user = await _client.SignupAsync();
        await CreateAsync(user.Token, "Flutter app", status: 0);
        await CreateAsync(user.Token, "Flutter mobile", status: 1);
        await CreateAsync(user.Token, "React app", status: 1);

        ProposalListResponse list = await _client.ListProposalsAsync(
            user.Token,
            "q=flutter&status=1"
        );

        Assert.Equal(new[] { "Flutter mobile" }, list.Items.Select(i => i.Title).ToArray());
    }

    [Fact]
    public async Task EachUser_SeesOnlyTheirOwnProposals()
    {
        AuthResponse userA = await _client.SignupAsync();
        AuthResponse userB = await _client.SignupAsync();
        await CreateAsync(userA.Token, "A first");
        await CreateAsync(userA.Token, "A second");
        ProposalResponse b = await CreateAsync(userB.Token, "B only");

        ProposalListResponse listA = await _client.ListProposalsAsync(userA.Token);
        ProposalListResponse listB = await _client.ListProposalsAsync(userB.Token);

        Assert.Equal(2, listA.Items.Count);
        Assert.Equal(new[] { b.Id }, listB.Items.Select(i => i.Id).ToArray());
    }

    [Fact]
    public async Task SoftDeletedProposals_AreHidden()
    {
        AuthResponse user = await _client.SignupAsync();
        ProposalResponse keep = await CreateAsync(user.Token, "Keep me");
        ProposalResponse gone = await CreateAsync(user.Token, "Delete me");

        using (IServiceScope scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
            long nowMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            Guid id = gone.Id;
            await db.Database.ExecuteSqlInterpolatedAsync(
                $@"UPDATE ""Proposals"" SET ""DeletedAtMs"" = {nowMs} WHERE ""Id"" = {id}"
            );
        }

        ProposalListResponse list = await _client.ListProposalsAsync(user.Token);

        Assert.Equal(new[] { keep.Id }, list.Items.Select(i => i.Id).ToArray());
    }

    [Theory]
    [InlineData("status=9", "status")]
    [InlineData("status=-1", "status")]
    [InlineData("limit=0", "limit")]
    [InlineData("limit=51", "limit")]
    public async Task OutOfRangeParameters_Return400_WithFieldError(string query, string field)
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await RawListAsync(user.Token, query);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("validation", error.Code);
        Assert.True(error.Fields!.ContainsKey(field));
    }

    [Theory]
    [InlineData("status=abc")]
    [InlineData("limit=abc")]
    [InlineData("cursor=abc")]
    public async Task WrongParameterTypes_Return400_BadRequest(string query)
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await RawListAsync(user.Token, query);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("bad_request", error.Code);
    }

    [Fact]
    public async Task TooLongSearch_Returns400_WithFieldError()
    {
        AuthResponse user = await _client.SignupAsync();

        var response = await RawListAsync(user.Token, $"q={new string('x', 101)}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("validation", error.Code);
        Assert.True(error.Fields!.ContainsKey("q"));
    }
}
