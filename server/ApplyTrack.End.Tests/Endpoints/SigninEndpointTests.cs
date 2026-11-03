using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using ApplyTrack.End.Models;
using ApplyTrack.End.Tests.Support;

namespace ApplyTrack.End.Tests.Endpoints;

[Collection("Api")]
public class SigninEndpointTests(ApiFactory factory)
{
    private const string SignupUrl = "/api/auth/signup";
    private const string SigninUrl = "/api/auth/signin";
    private const string Password = "password123";
    private readonly HttpClient _client = factory.CreateClient();

    private static string NewEmail() => $"user-{Guid.NewGuid():N}@example.com";

    private async Task<AuthResponse> CreateUserAsync(string email)
    {
        var response = await _client.PostAsJsonAsync(
            SignupUrl,
            new
            {
                email,
                password = Password,
                displayName = "Anton",
            }
        );
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
    }

    [Fact]
    public async Task CorrectPassword_Returns200_AndSameUser_EvenWithOtherEmailCase()
    {
        string email = NewEmail();
        AuthResponse created = await CreateUserAsync(email);

        var response = await _client.PostAsJsonAsync(
            SigninUrl,
            new { email = "  " + email.ToUpperInvariant() + " ", password = Password }
        );

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        AuthResponse body = (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.False(string.IsNullOrWhiteSpace(body.Token));
        Assert.True(body.ExpiresAtUnixSeconds > DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        Assert.Equal(created.User.Id, body.User.Id);
        Assert.Equal(email, body.User.Email);
        Assert.Equal("Anton", body.User.DisplayName);
    }

    [Fact]
    public async Task WrongPassword_Returns401()
    {
        string email = NewEmail();
        await CreateUserAsync(email);

        var response = await _client.PostAsJsonAsync(
            SigninUrl,
            new { email, password = "wrong-password" }
        );

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("invalid_credentials", error.Code);
    }

    [Fact]
    public async Task UnknownEmail_GivesTheSameAnswerAsWrongPassword()
    {
        string email = NewEmail();
        await CreateUserAsync(email);

        var wrongPassword = await _client.PostAsJsonAsync(
            SigninUrl,
            new { email, password = "wrong-password" }
        );
        var unknownEmail = await _client.PostAsJsonAsync(
            SigninUrl,
            new { email = NewEmail(), password = Password }
        );

        Assert.Equal(wrongPassword.StatusCode, unknownEmail.StatusCode);
        ErrorResponse first = (await wrongPassword.Content.ReadFromJsonAsync<ErrorResponse>())!;
        ErrorResponse second = (await unknownEmail.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal(first.Code, second.Code);
        Assert.Equal(first.Message, second.Message);
        Assert.Null(first.Fields);
        Assert.Null(second.Fields);
    }

    [Fact]
    public async Task EmptyFields_Return400_WithFieldErrors()
    {
        var response = await _client.PostAsJsonAsync(SigninUrl, new { email = "", password = "" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        ErrorResponse error = (await response.Content.ReadFromJsonAsync<ErrorResponse>())!;
        Assert.Equal("validation", error.Code);
        Assert.True(error.Fields!.ContainsKey("email"));
        Assert.True(error.Fields.ContainsKey("password"));
    }

    [Fact]
    public async Task UnknownEmail_StillDoesTheHashingWork()
    {
        // Without the dummy hash, an unknown email answers in about 5 ms.
        // Real PBKDF2 work needs far more. We take the fastest of 3 tries.
        var times = new List<long>();

        for (int i = 0; i < 3; i++)
        {
            var timer = Stopwatch.StartNew();
            var response = await _client.PostAsJsonAsync(
                SigninUrl,
                new { email = NewEmail(), password = Password }
            );
            timer.Stop();

            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            times.Add(timer.ElapsedMilliseconds);
        }

        Assert.True(
            times.Min() >= 20,
            $"Unknown email answered in {times.Min()} ms. The dummy hash work may be missing."
        );
    }
}
