using Microsoft.EntityFrameworkCore;

namespace ApplyTrack.DB;

public sealed class ApplyTrackDbContext(DbContextOptions<ApplyTrackDbContext> options)
    : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ApplyTrackDbContext).Assembly);
    }
}
