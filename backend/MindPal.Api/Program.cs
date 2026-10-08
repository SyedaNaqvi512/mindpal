using System.Text;
using System.Text.Json;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();
var app = builder.Build();

const string SystemPrompt =
    "You are MindPal, a supportive CBT-style reflection assistant for university students. " +
    "Read the journal entry and reply in five short parts: " +
    "1) acknowledge the feeling, " +
    "2) gently name one possible thinking pattern (for example all-or-nothing thinking), " +
    "3) ask one or two gentle questions that separate facts from assumptions, " +
    "4) offer one balanced alternative thought, " +
    "5) suggest one small practical next step. " +
    "Be warm and concise. Avoid empty reassurance and clinical language. " +
    "You are not a therapist and you never diagnose. " +
    "If the entry mentions wanting to harm themselves or others, or being in danger, " +
    "skip the five parts and gently encourage the person to contact a trusted person " +
    "or a local emergency or crisis service right away.";

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

app.MapPost("/reflect", async (ReflectRequest request, IConfiguration config,
    IHttpClientFactory httpFactory, ILogger<Program> logger) =>
{
    var text = request.Text?.Trim();
    if (string.IsNullOrEmpty(text))
    {
        return Results.BadRequest(new { error = "Text is required." });
    }
    if (text.Length > 2000)
    {
        return Results.BadRequest(new { error = "Text must be 2000 characters or fewer." });
    }

    var apiKey = config["Gemini:ApiKey"];
    var model = config["Gemini:Model"];
    if (string.IsNullOrWhiteSpace(apiKey) || string.IsNullOrWhiteSpace(model))
    {
        return Results.Problem("Gemini is not configured.");
    }

    var payload = new
    {
        system_instruction = new { parts = new[] { new { text = SystemPrompt } } },
        contents = new[] { new { role = "user", parts = new[] { new { text } } } }
    };

    var url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent";
    using var message = new HttpRequestMessage(HttpMethod.Post, url);
    message.Headers.Add("x-goog-api-key", apiKey);
    message.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

    try
    {
        var client = httpFactory.CreateClient();
        using var response = await client.SendAsync(message);

        if (!response.IsSuccessStatusCode)
        {
            var status = (int)response.StatusCode;
            logger.LogWarning("Gemini returned status {Status}", status);
            if (status == 429)
            {
                return Results.Json(new { error = "Too many requests. Please wait a moment and try again." }, statusCode: 429);
            }
            return Results.Json(new { error = "The AI service is unavailable. Please try again." }, statusCode: 502);
        }

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var parts = doc.RootElement.GetProperty("candidates")[0].GetProperty("content").GetProperty("parts");
        var sb = new StringBuilder();
        foreach (var part in parts.EnumerateArray())
        {
            if (part.TryGetProperty("text", out var t))
            {
                sb.Append(t.GetString());
            }
        }

        return Results.Ok(new { reflection = sb.ToString() });
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Reflection request failed");
        return Results.Json(new { error = "The AI service is unavailable. Please try again." }, statusCode: 502);
    }
});

app.Run();

record ReflectRequest(string? Text);