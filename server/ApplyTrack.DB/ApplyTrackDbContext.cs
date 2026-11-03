using ApplyTrack.DB.Models;
using Microsoft.EntityFrameworkCore;

namespace ApplyTrack.DB;

public sealed class ApplyTrackDbContext(DbContextOptions<ApplyTrackDbContext> options)
    : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Proposal> Proposals => Set<Proposal>();
    public DbSet<UserStats> UserStats => Set<UserStats>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Needed for the trigram search index on Proposals.Title.
        modelBuilder.HasPostgresExtension("pg_trgm");

        // ==========================================================
        // USERS
        // ==========================================================
        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable(
                "Users",
                t =>
                {
                    // The server lowercases. The DB rejects anything else.
                    t.HasCheckConstraint(
                        "CK_Users_Email_Lowercase",
                        "\"Email\" = lower(\"Email\")"
                    );

                    // btrim: a name of only spaces must not pass.
                    t.HasCheckConstraint(
                        "CK_Users_DisplayName_Length",
                        $"char_length(btrim(\"DisplayName\")) BETWEEN {UserLimits.DisplayNameMinLength} AND {UserLimits.DisplayNameMaxLength}"
                    );

                    t.HasCheckConstraint("CK_Users_CreatedAtMs_Positive", "\"CreatedAtMs\" > 0");
                }
            );

            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).ValueGeneratedNever(); // UUID v7 comes from the app

            entity.Property(e => e.Email).IsRequired().HasMaxLength(UserLimits.EmailMaxLength);
            entity
                .Property(e => e.DisplayName)
                .IsRequired()
                .HasMaxLength(UserLimits.DisplayNameMaxLength);
            entity
                .Property(e => e.PasswordHash)
                .IsRequired()
                .HasMaxLength(UserLimits.PasswordHashMaxLength);

            // O(1) login lookup + physical duplicate protection.
            entity.HasIndex(e => e.Email).IsUnique().HasDatabaseName("IX_Users_Email");
        });

        // ==========================================================
        // PROPOSALS
        // ==========================================================
        modelBuilder.Entity<Proposal>(entity =>
        {
            entity.ToTable(
                "Proposals",
                t =>
                {
                    t.HasCheckConstraint(
                        "CK_Proposals_Title_Length",
                        $"char_length(btrim(\"Title\")) BETWEEN {ProposalLimits.TitleMinLength} AND {ProposalLimits.TitleMaxLength}"
                    );
                    t.HasCheckConstraint(
                        "CK_Proposals_Platform_Range",
                        "\"Platform\" BETWEEN 0 AND 3"
                    );
                    t.HasCheckConstraint("CK_Proposals_Status_Range", "\"Status\" BETWEEN 0 AND 5");
                    t.HasCheckConstraint(
                        "CK_Proposals_Budget_NonNegative",
                        "\"Budget\" IS NULL OR \"Budget\" >= 0"
                    );

                    // Only http/https. Blocks javascript: links. The server parses the URL too.
                    t.HasCheckConstraint(
                        "CK_Proposals_Link_HttpOnly",
                        "\"Link\" IS NULL OR \"Link\" ~* '^https?://'"
                    );

                    t.HasCheckConstraint(
                        "CK_Proposals_Timestamps_Positive",
                        "\"CreatedAtMs\" > 0 AND \"UpdatedAtMs\" > 0 AND (\"DeletedAtMs\" IS NULL OR \"DeletedAtMs\" > 0)"
                    );
                }
            );

            // 1. PRIMARY KEY (UUID v7 from the app, time-ordered)
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).ValueGeneratedNever();

            // 2. COLUMNS (no NVARCHAR(MAX) surprises)
            entity.Property(e => e.Title).IsRequired().HasMaxLength(ProposalLimits.TitleMaxLength);
            entity.Property(e => e.Company).HasMaxLength(ProposalLimits.CompanyMaxLength);
            entity.Property(e => e.Link).HasMaxLength(ProposalLimits.LinkMaxLength);
            entity.Property(e => e.Notes).HasMaxLength(ProposalLimits.NotesMaxLength);
            entity.Property(e => e.Budget).HasPrecision(12, 2); // numeric(12,2)

            // Enums are stored as smallint.
            entity.Property(e => e.Platform).HasConversion<short>();
            entity.Property(e => e.Status).HasConversion<short>();

            // 3. SOFT DELETE: deleted rows are invisible to every normal query.
            // A GET or PUT on a deleted row finds nothing, so the API returns 404.
            entity.HasQueryFilter(e => e.DeletedAtMs == null);

            // 4. USER RELATIONSHIP (no navigation property: loosely coupled)
            entity
                .HasOne<User>()
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade); // user deleted -> all proposals deleted

            // 5. INDEXES (all partial: only live rows)
            const string liveRows = "\"DeletedAtMs\" IS NULL";

            // ==========================================================
            // LIST: keyset paging, newest first, covering (index-only scan)
            // ==========================================================
            // UUID v7 is time-ordered, so (UserId, Id DESC) is the paging order.
            // INCLUDE holds the columns the list screen shows, so Postgres
            // can answer the page without touching the table.
            // Notes and Link are NOT included: only the detail screen needs them.
            entity
                .HasIndex(e => new { e.UserId, e.Id })
                .IsDescending(false, true)
                .IncludeProperties(e => new
                {
                    e.Title,
                    e.Company,
                    e.Platform,
                    e.Status,
                    e.Budget,
                    e.FollowUpDate,
                })
                .HasFilter(liveRows)
                .HasDatabaseName("IX_Proposals_UserId_Id_Live");

            // STATUS FILTER: same paging order inside one status.
            entity
                .HasIndex(e => new
                {
                    e.UserId,
                    e.Status,
                    e.Id,
                })
                .IsDescending(false, false, true)
                .HasFilter(liveRows)
                .HasDatabaseName("IX_Proposals_UserId_Status_Id_Live");

            // TEXT SEARCH (q=): the one honest exception to O(1).
            // Trigram index. The query always adds UserId = X, so it scans one user's rows only.
            entity
                .HasIndex(e => e.Title)
                .HasMethod("gin")
                .HasOperators("gin_trgm_ops")
                .HasFilter(liveRows)
                .HasDatabaseName("IX_Proposals_Title_Trgm_Live");

            // No FollowUpDate index for now. Add it with the dueBy filter.
        });

        // ==========================================================
        // USER STATS (one row per user, O(1) read by primary key)
        // ==========================================================
        modelBuilder.Entity<UserStats>(entity =>
        {
            entity.ToTable(
                "UserStats",
                t =>
                {
                    t.HasCheckConstraint(
                        "CK_UserStats_NonNegative",
                        "\"Total\" >= 0 AND \"Draft\" >= 0 AND \"Sent\" >= 0 AND \"Viewed\" >= 0 AND \"Interview\" >= 0 AND \"Won\" >= 0 AND \"Lost\" >= 0"
                    );

                    // Counters can never drift from the total.
                    t.HasCheckConstraint(
                        "CK_UserStats_TotalMatchesParts",
                        "\"Total\" = \"Draft\" + \"Sent\" + \"Viewed\" + \"Interview\" + \"Won\" + \"Lost\""
                    );
                }
            );

            // PK = FK. One row per user, read by primary key.
            entity.HasKey(e => e.UserId);
            entity.Property(e => e.UserId).ValueGeneratedNever();

            entity.Property(e => e.Total).HasDefaultValue(0);
            entity.Property(e => e.Draft).HasDefaultValue(0);
            entity.Property(e => e.Sent).HasDefaultValue(0);
            entity.Property(e => e.Viewed).HasDefaultValue(0);
            entity.Property(e => e.Interview).HasDefaultValue(0);
            entity.Property(e => e.Won).HasDefaultValue(0);
            entity.Property(e => e.Lost).HasDefaultValue(0);

            entity
                .HasOne<User>()
                .WithOne()
                .HasForeignKey<UserStats>(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
