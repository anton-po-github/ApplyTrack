// ApplyTrack.End/Program.cs
using ApplyTrack.DB;
using ApplyTrack.End.Endpoints;
using ApplyTrack.End.Infrastructure;
using ApplyTrack.End.Security;
using ApplyTrack.End.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// ---------- Security ----------
builder.Services.AddProxyHeaders();
builder.Services.AddJwtAuth(builder.Configuration);
builder.Services.AddWebCors(builder.Configuration, builder.Environment);
builder.Services.AddApiRateLimiting(builder.Configuration);

// ---------- Database ----------
var defaultConnection =
    builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("Database connection string is missing.");

builder.Services.AddDbContextPool<ApplyTrackDbContext>(options =>
    options.UseNpgsql(defaultConnection, b => b.MigrationsAssembly("ApplyTrack.DB"))
);

/* builder.Services.AddPooledDbContextFactory<ApplyTrackDbContext>(options =>
    options.UseNpgsql(defaultConnection, b => b.MigrationsAssembly("ApplyTrack.DB"))
); */

// ---------- Infrastructure ----------
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();
builder.Services.AddSingleton<ITokenService, JwtTokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();

var app = builder.Build();

// ---------- Middleware (order matters) ----------
app.UseForwardedHeaders();
app.UseExceptionHandler();
app.UseCors(SecurityExtensions.CorsPolicy);
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

// ---------- Endpoints ----------
app.MapGet("/api/ping", () => Results.Ok(new { status = "ok" })).AllowAnonymous();

app.MapMethods(
        "/health",
        new[] { HttpMethods.Get, HttpMethods.Head },
        IResult (HttpContext context, IConfiguration config) =>
        {
            string? expected = config["CronJob:KeepAliveToken"];

            // No token configured = endpoint closed (fail safe).
            if (
                string.IsNullOrWhiteSpace(expected)
                || !context.Request.Headers.TryGetValue("X-ApplyTrack-KeepAlive", out var token)
                || token != expected
            )
            {
                return Results.Unauthorized();
            }

            return HttpMethods.IsHead(context.Request.Method)
                ? Results.Ok()
                : Results.Ok("ApplyTrack_Systems_Online");
        }
    )
    .AllowAnonymous();

app.MapAuthEndpoints();

app.Run();

public partial class Program;
