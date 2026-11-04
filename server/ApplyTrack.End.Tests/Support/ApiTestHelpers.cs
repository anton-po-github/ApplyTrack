using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using ApplyTrack.End.Models;

namespace ApplyTrack.End.Tests.Support;

/// <summary>Small helpers so new tests stay short.</summary>
public static class ApiTestHelpers
{
    public const string Password = "password123";

    public static string NewEmail() => $"user-{Guid.NewGuid():N}@example.com";

    public static async Task<HttpResponseMessage> PostProposalAsync(
        this HttpClient client,
        string token,
        object body
    )
    {
        HttpRequestMessage request = Authed(HttpMethod.Post, "/api/proposals", token);
        request.Content = JsonContent.Create(body);
        return await client.SendAsync(request);
    }

    public static async Task<StatsResponse> GetStatsAsync(this HttpClient client, string token)
    {
        var response = await client.SendAsync(Authed(HttpMethod.Get, "/api/stats", token));
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<StatsResponse>())!;
    }

    public static object ValidProposal(string title = "Build a Flutter app", int status = 0) =>
        new
        {
            title,
            platform = 0,
            status,
        };

    /// <summary>Creates a new user through the real API and returns token + profile.</summary>
    public static async Task<AuthResponse> SignupAsync(this HttpClient client, string? email = null)
    {
        var response = await client.PostAsJsonAsync(
            "/api/auth/signup",
            new
            {
                email = email ?? NewEmail(),
                password = Password,
                displayName = "Anton",
            }
        );

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
    }

    public static HttpRequestMessage Authed(HttpMethod method, string url, string token)
    {
        var request = new HttpRequestMessage(method, url);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return request;
    }
}
