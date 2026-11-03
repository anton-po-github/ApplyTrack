using ApplyTrack.DB;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace ApplyTrack.End.Tests.Support;

/// <summary>
/// Starts the real API in memory and connects it to the TEST database.
/// </summary>
public sealed class ApiFactory : WebApplicationFactory<Program>
{
    // Local-only password. To use your own, set the APPLYTRACK_TEST_DB environment variable.
    private const string DefaultTestConnection =
        "Host=localhost; Port=5432; Username=admin; Password=LocalDevPassword123!; Database=ApplyTrack_Test; Pooling=true; Maximum Pool Size=50";

    static ApiFactory()
    {
        string connection =
            Environment.GetEnvironmentVariable("APPLYTRACK_TEST_DB") ?? DefaultTestConnection;

        // Safety: never run tests against a real database.
        if (!connection.Contains("_Test", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Refusing to run: the test database name must contain '_Test'."
            );
        }

        // Environment variables beat appsettings files.
        Environment.SetEnvironmentVariable("ConnectionStrings__DefaultConnection", connection);
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.UseEnvironment("Development");

    protected override IHost CreateHost(IHostBuilder builder)
    {
        IHost host = base.CreateHost(builder);

        // Creates the test database if missing, then applies your migration.
        using IServiceScope scope = host.Services.CreateScope();
        scope.ServiceProvider.GetRequiredService<ApplyTrackDbContext>().Database.Migrate();

        return host;
    }
}
