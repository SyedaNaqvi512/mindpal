
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MindPal.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddUserGender : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                DO $migration$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1
                        FROM information_schema.columns
                        WHERE table_schema = 'public'
                          AND table_name = 'users'
                          AND column_name = 'gender'
                    ) THEN
                        ALTER TABLE public.users
                        ADD COLUMN gender character varying(20)
                        NOT NULL DEFAULT 'unspecified';
                    ELSE
                        ALTER TABLE public.users
                        ALTER COLUMN gender TYPE character varying(20);
                    END IF;

                    IF NOT EXISTS (
                        SELECT 1
                        FROM pg_constraint
                        WHERE conname = 'ck_users_gender'
                          AND conrelid = 'public.users'::regclass
                    ) THEN
                        ALTER TABLE public.users
                        ADD CONSTRAINT ck_users_gender
                        CHECK (
                            gender IN ('female', 'male', 'unspecified')
                        );
                    END IF;
                END
                $migration$;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Intentionally preserve the gender column and existing user data.
            // This migration also reconciles schema objects that may predate it.
        }
    }
}
