using Npgsql;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "MindPal.Api" }));

app.MapGet("/health/db", async (IConfiguration config, ILogger<Program> logger) =>
{
    var connectionString = config.GetConnectionString("MindPal");
    if (string.IsNullOrWhiteSpace(connectionString))
    {
        return Results.Problem("Connection string 'MindPal' is not configured.");
    }

    try
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand("SELECT 1", connection);
        await command.ExecuteScalarAsync();
        return Results.Ok(new { status = "ok", database = "connected" });
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database health check failed");
        return Results.Problem("Database connection failed.");
    }
});

app.Run();