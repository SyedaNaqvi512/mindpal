using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace MindPal.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "exercise_events",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    exercise_type = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_exercise_events", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "safety_events",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_safety_events", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    display_name = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    avatar_id = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)1),
                    email = table.Column<string>(type: "citext", nullable: false),
                    password_hash = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    role = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false, defaultValue: "user"),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false, defaultValue: "active"),
                    email_verified = table.Column<bool>(type: "boolean", nullable: false),
                    failed_login_count = table.Column<short>(type: "smallint", nullable: false),
                    locked_until = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    deletion_requested_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_users", x => x.id);
                    table.CheckConstraint("ck_users_avatar", "avatar_id BETWEEN 1 AND 12");
                    table.CheckConstraint("ck_users_deletion", "(status = 'pending_deletion') = (deletion_requested_at IS NOT NULL)");
                    table.CheckConstraint("ck_users_email_len", "char_length(email) BETWEEN 3 AND 254");
                    table.CheckConstraint("ck_users_name_len", "char_length(btrim(display_name)) BETWEEN 1 AND 40");
                    table.CheckConstraint("ck_users_role", "role IN ('user','admin')");
                    table.CheckConstraint("ck_users_status", "status IN ('active','suspended','pending_deletion')");
                });

            migrationBuilder.CreateTable(
                name: "ai_usage_logs",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    model = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    duration_ms = table.Column<int>(type: "integer", nullable: false),
                    status = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ai_usage_logs", x => x.id);
                    table.CheckConstraint("ck_ai_usage_duration", "duration_ms >= 0");
                    table.CheckConstraint("ck_ai_usage_status", "status IN ('success','timeout','error','rate_limited')");
                    table.ForeignKey(
                        name: "FK_ai_usage_logs_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "consents",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    policy_version = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    granted_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    revoked_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_consents", x => x.id);
                    table.CheckConstraint("ck_consents_revoked", "revoked_at IS NULL OR revoked_at >= granted_at");
                    table.CheckConstraint("ck_consents_type", "type IN ('ai_processing')");
                    table.ForeignKey(
                        name: "FK_consents_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "one_time_tokens",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    purpose = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    token_hash = table.Column<string>(type: "char(64)", nullable: false),
                    expires_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    used_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_one_time_tokens", x => x.id);
                    table.CheckConstraint("ck_ott_purpose", "purpose IN ('verify_email','reset_password')");
                    table.ForeignKey(
                        name: "FK_one_time_tokens_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "refresh_tokens",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    token_hash = table.Column<string>(type: "char(64)", nullable: false),
                    expires_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    revoked_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_refresh_tokens", x => x.id);
                    table.CheckConstraint("ck_refresh_expiry", "expires_at > created_at");
                    table.ForeignKey(
                        name: "FK_refresh_tokens_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_activity_days",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    activity_date = table.Column<DateOnly>(type: "date", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_activity_days", x => new { x.user_id, x.activity_date });
                    table.ForeignKey(
                        name: "FK_user_activity_days_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "reflection_feedback",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false, defaultValueSql: "gen_random_uuid()"),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    usage_id = table.Column<Guid>(type: "uuid", nullable: false),
                    rating = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    reason_code = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_reflection_feedback", x => x.id);
                    table.CheckConstraint("ck_feedback_rating", "rating IN ('helpful','not_helpful')");
                    table.CheckConstraint("ck_feedback_reason", "reason_code IS NULL OR (rating = 'not_helpful' AND reason_code IN ('not_relevant','too_generic','felt_wrong','too_long','other'))");
                    table.ForeignKey(
                        name: "FK_reflection_feedback_ai_usage_logs_usage_id",
                        column: x => x.usage_id,
                        principalTable: "ai_usage_logs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_reflection_feedback_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_ai_usage_created",
                table: "ai_usage_logs",
                column: "created_at")
                .Annotation("Npgsql:IndexInclude", new[] { "status", "duration_ms" });

            migrationBuilder.CreateIndex(
                name: "ix_ai_usage_user_time",
                table: "ai_usage_logs",
                columns: new[] { "user_id", "created_at" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "ix_consents_latest",
                table: "consents",
                columns: new[] { "user_id", "type", "granted_at" },
                descending: new[] { false, false, true });

            migrationBuilder.CreateIndex(
                name: "ux_consents_active",
                table: "consents",
                columns: new[] { "user_id", "type" },
                unique: true,
                filter: "revoked_at IS NULL");

            migrationBuilder.CreateIndex(
                name: "ix_exercise_events_created",
                table: "exercise_events",
                column: "created_at")
                .Annotation("Npgsql:IndexInclude", new[] { "exercise_type" });

            migrationBuilder.CreateIndex(
                name: "ix_one_time_tokens_expires_at",
                table: "one_time_tokens",
                column: "expires_at");

            migrationBuilder.CreateIndex(
                name: "ix_one_time_tokens_user",
                table: "one_time_tokens",
                columns: new[] { "user_id", "purpose" });

            migrationBuilder.CreateIndex(
                name: "ux_one_time_tokens_hash",
                table: "one_time_tokens",
                column: "token_hash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_feedback_created",
                table: "reflection_feedback",
                column: "created_at")
                .Annotation("Npgsql:IndexInclude", new[] { "rating", "reason_code" });

            migrationBuilder.CreateIndex(
                name: "ix_feedback_user",
                table: "reflection_feedback",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ux_feedback_usage",
                table: "reflection_feedback",
                column: "usage_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_refresh_tokens_expires_at",
                table: "refresh_tokens",
                column: "expires_at");

            migrationBuilder.CreateIndex(
                name: "ix_refresh_tokens_user",
                table: "refresh_tokens",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ux_refresh_tokens_hash",
                table: "refresh_tokens",
                column: "token_hash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_safety_created",
                table: "safety_events",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "ix_activity_date",
                table: "user_activity_days",
                column: "activity_date");

            migrationBuilder.CreateIndex(
                name: "ix_users_created_at",
                table: "users",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "ix_users_deletion_due",
                table: "users",
                column: "deletion_requested_at",
                filter: "status = 'pending_deletion'");

            migrationBuilder.CreateIndex(
                name: "ux_users_email",
                table: "users",
                column: "email",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "consents");

            migrationBuilder.DropTable(
                name: "exercise_events");

            migrationBuilder.DropTable(
                name: "one_time_tokens");

            migrationBuilder.DropTable(
                name: "reflection_feedback");

            migrationBuilder.DropTable(
                name: "refresh_tokens");

            migrationBuilder.DropTable(
                name: "safety_events");

            migrationBuilder.DropTable(
                name: "user_activity_days");

            migrationBuilder.DropTable(
                name: "ai_usage_logs");

            migrationBuilder.DropTable(
                name: "users");
        }
    }
}
