using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ApplyTrack.DB.Migrations
{
    /// <inheritdoc />
    public partial class Init_Mig : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:pg_trgm", ",,");

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Email = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    DisplayName = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    PasswordHash = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    CreatedAtMs = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                    table.CheckConstraint("CK_Users_CreatedAtMs_Positive", "\"CreatedAtMs\" > 0");
                    table.CheckConstraint("CK_Users_DisplayName_Length", "char_length(btrim(\"DisplayName\")) BETWEEN 1 AND 80");
                    table.CheckConstraint("CK_Users_Email_Lowercase", "\"Email\" = lower(\"Email\")");
                });

            migrationBuilder.CreateTable(
                name: "Proposals",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Company = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    Platform = table.Column<short>(type: "smallint", nullable: false),
                    Status = table.Column<short>(type: "smallint", nullable: false),
                    Budget = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: true),
                    FollowUpDate = table.Column<DateOnly>(type: "date", nullable: true),
                    Link = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    Notes = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    CreatedAtMs = table.Column<long>(type: "bigint", nullable: false),
                    UpdatedAtMs = table.Column<long>(type: "bigint", nullable: false),
                    DeletedAtMs = table.Column<long>(type: "bigint", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Proposals", x => x.Id);
                    table.CheckConstraint("CK_Proposals_Budget_NonNegative", "\"Budget\" IS NULL OR \"Budget\" >= 0");
                    table.CheckConstraint("CK_Proposals_Link_HttpOnly", "\"Link\" IS NULL OR \"Link\" ~* '^https?://'");
                    table.CheckConstraint("CK_Proposals_Platform_Range", "\"Platform\" BETWEEN 0 AND 3");
                    table.CheckConstraint("CK_Proposals_Status_Range", "\"Status\" BETWEEN 0 AND 5");
                    table.CheckConstraint("CK_Proposals_Timestamps_Positive", "\"CreatedAtMs\" > 0 AND \"UpdatedAtMs\" > 0 AND (\"DeletedAtMs\" IS NULL OR \"DeletedAtMs\" > 0)");
                    table.CheckConstraint("CK_Proposals_Title_Length", "char_length(btrim(\"Title\")) BETWEEN 3 AND 120");
                    table.ForeignKey(
                        name: "FK_Proposals_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserStats",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Total = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    Draft = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    Sent = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    Viewed = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    Interview = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    Won = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    Lost = table.Column<int>(type: "integer", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserStats", x => x.UserId);
                    table.CheckConstraint("CK_UserStats_NonNegative", "\"Total\" >= 0 AND \"Draft\" >= 0 AND \"Sent\" >= 0 AND \"Viewed\" >= 0 AND \"Interview\" >= 0 AND \"Won\" >= 0 AND \"Lost\" >= 0");
                    table.CheckConstraint("CK_UserStats_TotalMatchesParts", "\"Total\" = \"Draft\" + \"Sent\" + \"Viewed\" + \"Interview\" + \"Won\" + \"Lost\"");
                    table.ForeignKey(
                        name: "FK_UserStats_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Proposals_Title_Trgm_Live",
                table: "Proposals",
                column: "Title",
                filter: "\"DeletedAtMs\" IS NULL")
                .Annotation("Npgsql:IndexMethod", "gin")
                .Annotation("Npgsql:IndexOperators", new[] { "gin_trgm_ops" });

            migrationBuilder.CreateIndex(
                name: "IX_Proposals_UserId_Id_Live",
                table: "Proposals",
                columns: new[] { "UserId", "Id" },
                descending: new[] { false, true },
                filter: "\"DeletedAtMs\" IS NULL")
                .Annotation("Npgsql:IndexInclude", new[] { "Title", "Company", "Platform", "Status", "Budget", "FollowUpDate" });

            migrationBuilder.CreateIndex(
                name: "IX_Proposals_UserId_Status_Id_Live",
                table: "Proposals",
                columns: new[] { "UserId", "Status", "Id" },
                descending: new[] { false, false, true },
                filter: "\"DeletedAtMs\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Users_Email",
                table: "Users",
                column: "Email",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Proposals");

            migrationBuilder.DropTable(
                name: "UserStats");

            migrationBuilder.DropTable(
                name: "Users");
        }
    }
}
