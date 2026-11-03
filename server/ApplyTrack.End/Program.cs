// ApplyTrack.End/Program.cs
using System.Text;
using ApplyTrack.DB;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// ==========================================================
// STEP 4.1: MINIMAL API JSON CONFIGURATION
// ==========================================================
// Explicitly force Minimal APIs to bridge JavaScript's camelCase with C#'s PascalCase.
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    options.SerializerOptions.DictionaryKeyPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
});

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy(
        "ApplyTrackCorsPolicy",
        policy =>
            policy
                .WithOrigins(allowedOrigins)
                .WithHeaders("Authorization", "Content-Type")
                .WithMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
    );
});

// ====================================================================
// JWT AUTHENTICATION SETUP (THE GATEKEEPER)
// ====================================================================
var jwtSecret =
    builder.Configuration["JwtConfig:Secret"]
    ?? throw new InvalidOperationException("JWT Secret missing!");

builder
    .Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        // BUGFIX: Stop .NET from renaming standard JWT claims to legacy XML SOAP claims!
        options.MapInboundClaims = false;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["JwtConfig:Issuer"],
            ValidAudience = builder.Configuration["JwtConfig:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
        };

        // 🚀 STEP 1.2: The WebSocket Auth Interceptor
        // WebSockets cannot natively send HTTP Headers on the initial handshake.
        // We configure Kestrel to seamlessly pull the JWT from the query string ONLY for our SignalR route.
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];

                // Read the path to ensure we only do this for the Hub
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hub/workspace"))
                {
                    // Map the token from the query string to the auth context
                    context.Token = accessToken;
                }

                return Task.CompletedTask;
            },
        };
    });

builder.Services.AddAuthorization();

// ====================================================================
// RATE LIMITING (Golden Mean for Hetzner cpx11)
// ====================================================================

var defaultConnection =
    builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("Database connection string is missing.");

builder.Services.AddDbContextPool<ApplyTrackDbContext>(options =>
    options.UseNpgsql(defaultConnection, b => b.MigrationsAssembly("ApplyTrack.DB"))
);

builder.Services.AddPooledDbContextFactory<ApplyTrackDbContext>(options =>
    options.UseNpgsql(defaultConnection, b => b.MigrationsAssembly("ApplyTrack.DB"))
);

var app = builder.Build();

app.MapGet("/api/ping", () => Results.Ok(new { status = "ok" }));

app.MapMethods(
    "/health",
    new[] { HttpMethods.Get, HttpMethods.Head },
    IResult (HttpContext context, IConfiguration config) =>
    {
        // Ultra-fast security check with no memory allocation. Blocks spam bots in nanoseconds.
        var tokenFromConfig = config["CronJob:KeepAliveToken"];

        if (
            !context.Request.Headers.TryGetValue("X-ApplyTrack-KeepAlive", out var token)
            || token != tokenFromConfig
        )
        {
            // Immediately return a 401 Unauthorized status code without logging or generating a response body
            return Results.Unauthorized();
        }

        // If the request is a HEAD request (as should be configured in the monitoring system),
        // return only the headers (status 200 OK) without generating a response body.

        if (HttpMethods.IsHead(context.Request.Method))
        {
            return Results.Ok();
        }

        // Fallback response for GET requests (for developer debugging)
        // We avoid JSON serialization by returning a simple status code.
        return Results.Ok("ApplyTrack_Systems_Online");
    }
);

app.UseRouting();
app.UseCors("ApplyTrackCorsPolicy");
app.UseAuthentication();
app.UseAuthorization();

//app.UseRateLimiter();

app.Run();
