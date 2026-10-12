using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using MindPal.Api.Auth;
using MindPal.Api.Data;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();

// Request body limit 20 KB (SRS v1.1)
builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 20 * 1024);

// Database context
builder.Services.AddDbContext<MindPalDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("MindPal")));

// ---- JWT settings (secret must come from user-secrets / environment, never from git) ----
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwt.Key) || Encoding.UTF8.GetByteCount(jwt.Key) < 32)
    throw new InvalidOperationException("Jwt:Key is missing or shorter than 32 bytes. Set it with 'dotnet user-secrets set Jwt:Key <value>'.");
builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton<TokenService>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;   // keep claim names "sub" and "role"
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true, ValidIssuer = jwt.Issuer,
            ValidateAudience = true, ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });
builder.Services.AddAuthorization();

// ---- Problem details (RFC 9457) ----
builder.Services.AddProblemDetails();

// ---- Rate limiting (SRS v1.1) ----
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = 429;
        ctx.HttpContext.Response.ContentType = "application/problem+json";
        await ctx.HttpContext.Response.WriteAsync(
            "{\"type\":\"about:blank\",\"title\":\"Too many requests\",\"status\":429,\"code\":\"rate_limited\"}", ct);
    };
    static string Ip(HttpContext c) => c.Connection.RemoteIpAddress?.ToString() ?? "unknown";
    o.AddPolicy("auth", c => RateLimitPartition.GetFixedWindowLimiter(Ip(c),
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 20, Window = TimeSpan.FromMinutes(15) }));
    o.AddPolicy("register", c => RateLimitPartition.GetFixedWindowLimiter(Ip(c),
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromHours(1) }));
    o.AddPolicy("reflect", c => RateLimitPartition.GetFixedWindowLimiter(
        c.User.FindFirst("sub")?.Value ?? Ip(c),
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 120, Window = TimeSpan.FromMinutes(1) }));
});

// Render sits behind a proxy: use the real client IP for rate limits
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownIPNetworks.Clear();
    o.KnownProxies.Clear();
});

builder.Services.AddOpenApi();

var app = builder.Build();

app.UseForwardedHeaders();
app.UseExceptionHandler();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
    app.MapOpenApi();   // JSON at /openapi/v1.json

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
        return Results.Problem("Connection string 'MindPal' is not configured.");
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

app.MapGet("/health/ready", async (MindPalDbContext db, CancellationToken ct) =>
    await db.Database.CanConnectAsync(ct)
        ? Results.Ok(new { status = "ready" })
        : Results.Json(new { status = "not_ready" }, statusCode: 503));

app.MapAuth();

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
}).RequireAuthorization().RequireRateLimiting("reflect").WithTags("Reflection");

app.Run();

record ReflectRequest(string? Text);

public partial class Program { }   // lets the test project start the API