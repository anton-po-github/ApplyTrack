using System.Globalization;
using System.Text;
using System.Threading.RateLimiting;
using ApplyTrack.End.Models;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;

namespace ApplyTrack.End.Infrastructure;

public static class SecurityExtensions
{
    public const string CorsPolicy = "WebDemo";
    public const string AuthLimiterPolicy = "AuthLimiter";

    private const int MinSecretBytes = 32; // HS256 needs a 256-bit key

    // ---------- JWT ----------
    public static IServiceCollection AddJwtAuth(
        this IServiceCollection services,
        IConfiguration config
    )
    {
        string secret =
            config["JwtConfig:Secret"]
            ?? throw new InvalidOperationException("JwtConfig:Secret is missing.");
        string issuer =
            config["JwtConfig:Issuer"]
            ?? throw new InvalidOperationException("JwtConfig:Issuer is missing.");
        string audience =
            config["JwtConfig:Audience"]
            ?? throw new InvalidOperationException("JwtConfig:Audience is missing.");

        byte[] keyBytes = Encoding.UTF8.GetBytes(secret);
        if (keyBytes.Length < MinSecretBytes)
            throw new InvalidOperationException("JwtConfig:Secret must be at least 32 bytes.");

        var key = new SymmetricSecurityKey(keyBytes);

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.MapInboundClaims = false; // keep the claim name "sub" as "sub"
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = key,
                    ValidateIssuer = true,
                    ValidIssuer = issuer,
                    ValidateAudience = true,
                    ValidAudience = audience,
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromSeconds(30),
                    ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
                };
            });

        services.AddAuthorization();
        return services;
    }

    // ---------- CORS (only for the Flutter Web demo) ----------
    public static IServiceCollection AddWebCors(
        this IServiceCollection services,
        IConfiguration config,
        IHostEnvironment env
    )
    {
        string[] origins = config.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        bool isDev = env.IsDevelopment();

        services.AddCors(options =>
            options.AddPolicy(
                CorsPolicy,
                policy =>
                {
                    policy
                        .WithMethods("GET", "POST", "PUT", "DELETE")
                        .WithHeaders("Content-Type", "Authorization");

                    if (isDev)
                    {
                        // Local Flutter Web uses a random localhost port.
                        policy.SetIsOriginAllowed(origin =>
                            Uri.TryCreate(origin, UriKind.Absolute, out Uri? uri) && uri.IsLoopback
                        );
                    }
                    else
                    {
                        policy.WithOrigins(origins); // empty list = nobody allowed
                    }
                }
            )
        );
        return services;
    }

    // ---------- Real client IP behind Azure ----------
    public static IServiceCollection AddProxyHeaders(this IServiceCollection services)
    {
        services.Configure<ForwardedHeadersOptions>(options =>
        {
            options.ForwardedHeaders =
                ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
            options.ForwardLimit = 1; // take only the entry added by Azure's front end
            // Azure App Service is the only way in, so we trust its proxy.
            options.KnownIPNetworks.Clear();
            options.KnownProxies.Clear();
        });
        return services;
    }

    // ---------- Rate limits (per IP) ----------
    public static IServiceCollection AddApiRateLimiting(
        this IServiceCollection services,
        IConfiguration config
    )
    {
        int globalPerMinute = config.GetValue("RateLimit:GlobalPerMinute", 300);
        int authPerMinute = config.GetValue("RateLimit:AuthPerMinute", 10);

        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            options.OnRejected = async (context, ct) =>
            {
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out TimeSpan retryAfter))
                {
                    context.HttpContext.Response.Headers.RetryAfter = (
                        (int)retryAfter.TotalSeconds
                    ).ToString(CultureInfo.InvariantCulture);
                }

                await context.HttpContext.Response.WriteAsJsonAsync(
                    new ErrorResponse("rate_limited", "Too many requests. Try again later."),
                    ct
                );
            };

            // Every request: per IP.
            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    ClientKey(context),
                    _ => FixedWindow(globalPerMinute)
                )
            );

            // Strict: for signup, signin and google (added on those groups later).
            options.AddPolicy(
                AuthLimiterPolicy,
                context =>
                    RateLimitPartition.GetFixedWindowLimiter(
                        ClientKey(context),
                        _ => FixedWindow(authPerMinute)
                    )
            );
        });
        return services;
    }

    private static string ClientKey(HttpContext context) =>
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    private static FixedWindowRateLimiterOptions FixedWindow(int permitLimit) =>
        new()
        {
            PermitLimit = permitLimit,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0, // no queue: instant 429
            AutoReplenishment = true,
        };
}
