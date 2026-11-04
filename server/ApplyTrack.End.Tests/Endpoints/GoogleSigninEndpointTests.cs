using System.Net;
using System.Net.Http.Json;
using System.Text;
using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class GoogleSigninEndpointTests(ApiFactory factory)
{
    private const string Url = "/api/auth/google";
    private readonly HttpClient _client = factory.CreateClient();

    private string Token(string email, bool verified = true, string? name = "Test User") =>
        factory.Google.Register(email, verified, name);

    private Task<HttpResponseMessage> GoogleAsync(string credential) =>
        _client.PostAsJsonAsync(Url, new { credential });

    private async Task<AuthResponse> GoogleOkAsync(string credential)
    {
        var response = await GoogleAsync(credential);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
    }

    private async Task<int> CountAsync(string sql, params object[] args)
    {
        using IServiceScope scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
        return await db.Database.SqlQueryRaw<int>(sql, args).SingleAsync();
    }

    private Task<int> UsersWithEmailAsync(string email) =>
        CountAsync("SELECT COUNT(*)::int AS \"Value\" FROM \"Users\" WHERE \"Email\" = {0}", email);

    [Fact]
    public async Task NewGoogleUser_Returns200_CreatesUserAndStats_AndTokenWorks()
    {
        string email = ApiTestHelpers.NewEmail();

        AuthResponse body = await GoogleOkAsync(Token(email, name: "  Anton Google "));

        Assert.False(string.IsNullOrWhiteSpace(body.Token));
        Assert.True(body.ExpiresAtUnixSeconds > DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        Assert.Equal(7, body.User.Id.Version);
        Assert.Equal(email, body.User.Email);
        Assert.Equal("Anton Google", body.User.DisplayName);

        Assert.Equal(1, await UsersWithEmailAsync(email));
        Assert.Equal(
            1,
            await CountAsync(
                "SELECT COUNT(*)::int AS \"Value\" FROM \"UserStats\" WHERE \"UserId\" = {0} AND \"Total\" = 0",
                body.User.Id
            )
        );

        // The token from Google sign-in works on a protected endpoint.
        var me = await _client.SendAsync(
            ApiTestHelpers.Authed(HttpMethod.Get, "/api/auth/me", body.Token)
        );
        Assert.Equal(HttpStatusCode.OK, me.StatusCode);
        Assert.Equal(body.User, await me.Content.ReadFromJsonAsync<UserProfile>());
        Assert.Equal(
            ApiTestHelpers.StatsFor(Array.Empty<int>()),
            await _client.GetStatsAsync(body.Token)
        );
    }

    [Fact]
    public async Task SecondGoogleSignin_ReturnsTheSameUser_NoDuplicate()
    {
        string email = ApiTestHelpers.NewEmail();

        AuthResponse first = await GoogleOkAsync(Token(email));
        AuthResponse second = await GoogleOkAsync(Token(email, name: "Other Name"));

        Assert.Equal(first.User, second.User); // same id, same stored name
        Assert.Equal(1, await UsersWithEmailAsync(email));
    }

    [Fact]
    public async Task Email_IsTrimmedAndLowercased_AndMatchesTheSameUser()
    {
        string email = ApiTestHelpers.NewEmail();

        AuthResponse upper = await GoogleOkAsync(Token("  " + email.ToUpperInvariant() + " "));
        AuthResponse lower = await GoogleOkAsync(Token(email));

        Assert.Equal(email, upper.User.Email);
        Assert.Equal(upper.User.Id, lower.User.Id);
    }

    [Fact]
    public async Task ExistingPasswordUser_GoogleSignin_SameAccount_KeepsDataAndName()
    {
        string email = ApiTestHelpers.NewEmail();
        AuthResponse signedUp = await _client.SignupAsync(email); // display name "Anton"
        ProposalResponse proposal = await _client.CreateProposalAsync(
            signedUp.Token,
            ApiTestHelpers.ValidProposal()
        );

        AuthResponse viaGoogle = await GoogleOkAsync(Token(email, name: "Google Name"));

        Assert.Equal(signedUp.User, viaGoogle.User); // same id, same stored name
        ProposalListResponse list = await _client.ListProposalsAsync(viaGoogle.Token);
        Assert.Equal(new[] { proposal.Id }, list.Items.Select(i => i.Id).ToArray());
    }

    [Fact]
    public async Task ExistingPasswordUser_PasswordIsDisabledAfterGoogleSignin()
    {
        string email = ApiTestHelpers.NewEmail();
        AuthResponse signedUp = await _client.SignupAsync(email);
        await GoogleOkAsync(Token(email));

        var passwordSignin = await _client.PostAsJsonAsync(
            "/api/auth/signin",
            new { email, password = ApiTestHelpers.Password }
        );
        AuthResponse again = await GoogleOkAsync(Token(email));

        Assert.Equal(HttpStatusCode.Unauthorized, passwordSignin.StatusCode);
        Assert.Equal(signedUp.User.Id, again.User.Id); // Google still works
    }

    [Fact]
    public async Task UnverifiedEmail_Returns401_CreatesNoUser_SameAnswerAsAnUnknownToken()
    {
        string email = ApiTestHelpers.NewEmail();

        var unverified = await GoogleAsync(Token(email, verified: false));
        var unknown = await GoogleAsync("not-a-registered-token");

        Assert.Equal(HttpStatusCode.Unauthorized, unverified.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, unknown.StatusCode);
        ErrorResponse error = (await unverified.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("invalid_google_token", error.Code);
        Assert.Equal(
            await unknown.Content.ReadAsStringAsync(),
            await unverified.Content.ReadAsStringAsync()
        ); // same body: nothing leaks
        Assert.Equal(0, await UsersWithEmailAsync(email));
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("{\"credential\":\"\"}")]
    [InlineData("{\"credential\":\"   \"}")]
    public async Task MissingOrEmptyCredential_Returns400_WithFieldError(string json)
    {
        var response = await _client.PostAsync(
            Url,
            new StringContent(json, Encoding.UTF8, "application/json")
        );

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("validation", error.Code);
        Assert.True(error.Fields!.ContainsKey("credential"));
    }

    [Fact]
    public async Task TooLongCredential_Returns400_WithoutAskingGoogle()
    {
        var response = await GoogleAsync(new string('x', 4097));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("validation", error.Code);
    }

    [Theory]
    [InlineData("ünï@example.com")]
    [InlineData("not-an-email")]
    public async Task EmailWeCannotStore_Returns400_AndCreatesNoUser(string email)
    {
        var response = await GoogleAsync(Token(email));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("google_email_unsupported", error.Code);
        Assert.Equal(0, await UsersWithEmailAsync(email.ToLowerInvariant()));
    }

    [Fact]
    public async Task DisplayName_IsCutTo80_AndFallsBackToTheEmailPart()
    {
        AuthResponse longName = await GoogleOkAsync(
            Token(ApiTestHelpers.NewEmail(), name: new string('N', 100))
        );
        string email = ApiTestHelpers.NewEmail();
        AuthResponse noName = await GoogleOkAsync(Token(email, name: null));

        Assert.Equal(80, longName.User.DisplayName.Length);
        Assert.Equal(email[..email.IndexOf('@')], noName.User.DisplayName);
    }

    [Fact]
    public async Task FiveFirstSigninsAtTheSameTime_SameEmail_OneUser_OneStatsRow()
    {
        string email = ApiTestHelpers.NewEmail();
        string[] tokens = Enumerable.Range(0, 5).Select(_ => Token(email)).ToArray();

        HttpResponseMessage[] responses = await Task.WhenAll(tokens.Select(GoogleAsync));

        Assert.All(responses, r => Assert.Equal(HttpStatusCode.OK, r.StatusCode));
        AuthResponse?[] bodies = await Task.WhenAll(
            responses.Select(r => r.Content.ReadFromJsonAsync<AuthResponse>())
        );
        Guid id = Assert.Single(bodies.Select(b => b!.User.Id).Distinct());

        Assert.Equal(1, await UsersWithEmailAsync(email));
        Assert.Equal(
            1,
            await CountAsync(
                "SELECT COUNT(*)::int AS \"Value\" FROM \"UserStats\" WHERE \"UserId\" = {0}",
                id
            )
        );
    }

    [Fact]
    public async Task BrokenJson_Returns400_BadRequest()
    {
        var response = await _client.PostAsync(
            Url,
            new StringContent("{bad", Encoding.UTF8, "application/json")
        );

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("bad_request", error.Code);
    }
}
