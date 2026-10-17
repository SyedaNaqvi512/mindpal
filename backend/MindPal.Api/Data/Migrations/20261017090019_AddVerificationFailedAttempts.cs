using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindPal.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddVerificationFailedAttempts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "failed_attempts",
                table: "one_time_tokens",
                type: "smallint",
                nullable: false,
                defaultValue: (short)0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "failed_attempts",
                table: "one_time_tokens");
        }
    }
}
