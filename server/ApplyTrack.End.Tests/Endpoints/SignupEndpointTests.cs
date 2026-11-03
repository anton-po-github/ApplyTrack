using System.Net;
using System.Net.Http.Json;
using System.Text;
using ApplyTrack.DB;
using ApplyTrack.End.Models;
using ApplyTrack.End.Security;
using ApplyTrack.End.Tests.Support;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class SignupEndpointTests(ApiFactory factory)
{
    private const string Url = "/api/auth/signup";
    private readonly HttpClient _client = factory.CreateClient();

    // Every test uses a new email, so tests never need cleaning.
    private static string NewEmail() => $"user-{Guid.NewGuid():N}@example.com";

    private async Task<int> CountAsync(string sql, params object[] args)
    {
        using IServiceScope scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
        return await db.Database.SqlQueryRaw<int>(sql, args).SingleAsync();
    }

    [Fact]
    public async Task ValidRequest_Returns201_WithTokenAndProfile()
    {
        string email = NewEmail();

        var response = await _client.PostAsJsonAsync(
            Url,
            new
            {
                email,
                password = "password123",
                displayName = "Anton",
            }
        );

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        string raw = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("password", raw, StringComparison.OrdinalIgnoreCase);

        AuthResponse? body = await response.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.NotNull(body);
        Assert.False(string.IsNullOrWhiteSpace(body.Token));
        Assert.True(body.ExpiresAtUnixSeconds > DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        Assert.Equal(email, body.User.Email);
        Assert.Equal("Anton", body.User.DisplayName);
        Assert.Equal(7, body.User.Id.Version); // UUID v7
    }

    [Fact]
    public async Task ValidRequest_CreatesUserAndStatsRow_AndStoresOnlyAHash()
    {
        string email = NewEmail();
        var response = await _client.PostAsJsonAsync(
            Url,
            new
            {
                email,
                password = "password123",
                displayName = "Anton",
            }
        );
        AuthResponse body = (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        Guid id = body.User.Id;

        int statsRows = await CountAsync(
            "SELECT COUNT(*)::int AS \"Value\" FROM \"UserStats\" WHERE \"UserId\" = {0} AND \"Total\" = 0",
            id
        );
        Assert.Equal(1, statsRows);

        using IServiceScope scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>();
        string hash = await db
            .Database.SqlQueryRaw<string>(
                "SELECT \"PasswordHash\" AS \"Value\" FROM \"Users\" WHERE \"Id\" = {0}",
                id
            )
            .SingleAsync();

        Assert.NotEqual("password123", hash);
        Assert.True(new Pbkdf2PasswordHasher().Verify("password123", hash));
    }

    [Fact]
    public async Task Email_IsTrimmedAndLowercased()
    {
        string email = NewEmail();

        var response = await _client.PostAsJsonAsync(
            Url,
            new
            {
                email = "  " + email.ToUpperInvariant() + " ",
                password = "password123",
                displayName = "  Anton ",
            }
        );

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        AuthResponse body = (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.Equal(email, body.User.Email);
        Assert.Equal("Anton", body.User.DisplayName);
    }

    [Fact]
    public async Task DuplicateEmail_Returns409_AndCreatesNoSecondUser()
    {
        string email = NewEmail();
        var first = await _client.PostAsJsonAsync(
            Url,
            new
            {
                email,
                password = "password123",
                displayName = "One",
            }
        );
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);

        var second = await _client.PostAsJsonAsync(
            Url,
            new
            {
                email = email.ToUpperInvariant(),
                password = "password456",
                displayName = "Two",
            }
        );

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
        ErrorResponse error = (await second.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("email_taken", error.Code);
        Assert.True(error.Fields!.ContainsKey("email"));

        int users = await CountAsync(
            "SELECT COUNT(*)::int AS \"Value\" FROM \"Users\" WHERE \"Email\" = {0}",
            email
        );
        Assert.Equal(1, users);
    }

    [Fact]
    public async Task InvalidPayload_Returns400_WithFieldErrors()
    {
        var response = await _client.PostAsJsonAsync(
            Url,
            new
            {
                email = "bad",
                password = "123",
                displayName = " ",
            }
        );

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("validation", error.Code);
        Assert.True(error.Fields!.ContainsKey("email"));
        Assert.True(error.Fields.ContainsKey("password"));
        Assert.True(error.Fields.ContainsKey("displayName"));
    }

    [Fact]
    public async Task BrokenJson_Returns400_NotServerError()
    {
        var content = new StringContent("{bad", Encoding.UTF8, "application/json");

        var response = await _client.PostAsync(Url, content);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("bad_request", error.Code);
    }

    [Fact]
    public async Task FiveSignupsAtTheSameTime_SameEmail_OnlyOneWins()
    {
        string email = NewEmail();

        HttpResponseMessage[] responses = await Task.WhenAll(
            Enumerable
                .Range(0, 5)
                .Select(_ =>
                    _client.PostAsJsonAsync(
                        Url,
                        new
                        {
                            email,
                            password = "password123",
                            displayName = "Race",
                        }
                    )
                )
        );

        Assert.Equal(1, responses.Count(r => r.StatusCode == HttpStatusCode.Created));
        Assert.Equal(4, responses.Count(r => r.StatusCode == HttpStatusCode.Conflict));
    }
}
