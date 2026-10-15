
using System.Net;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using MindPal.Api.Auth;
using MindPal.Api.Consents;
using MindPal.Api.Data;
using MindPal.Api.Reflection;
using MindPal.Api.Services;
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

if (string.IsNullOrWhiteSpace(jwt.Key) ||
    Encoding.UTF8.GetByteCount(jwt.Key) < 32)
{
    throw new InvalidOperationException(
        "Jwt:Key is missing or shorter than 32 bytes. Set it with 'dotnet user-secrets set Jwt:Key <value>'.");
}

builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton<TokenService>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false; // Keep claim names "sub" and "role"
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,

            ValidateAudience = true,
            ValidAudience = jwt.Audience,

            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwt.Key)),

            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),

            NameClaimType = "name",
            RoleClaimType = "role"
        };
    });

builder.Services.AddAuthorization();

// ---- Problem details (RFC 9457) ----
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

builder.Services.AddScoped<IReflectionEngine, GeminiReflectionEngine>();

// ---- Rate limiting (SRS v1.1) ----
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    o.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = 429;
        ctx.HttpContext.Response.ContentType = "application/problem+json";

        await ctx.HttpContext.Response.WriteAsync(
            "{\"type\":\"about:blank\",\"title\":\"Too many requests\",\"status\":429,\"code\":\"rate_limited\"}",
            ct);
    };

    static string Ip(HttpContext c) =>
        c.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    o.AddPolicy("auth", c =>
        RateLimitPartition.GetFixedWindowLimiter(
            Ip(c),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(15)
            }));

    o.AddPolicy("register", c =>
        RateLimitPartition.GetFixedWindowLimiter(
            Ip(c),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromHours(1)
            }));

    o.AddPolicy("reflect", c =>
        RateLimitPartition.GetFixedWindowLimiter(
            c.User.FindFirst("sub")?.Value ?? Ip(c),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 120,
                Window = TimeSpan.FromMinutes(1)
            }));
});

// Render sits behind a proxy: use the real client IP for rate limits
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;

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
{
    app.MapOpenApi(); // JSON at /openapi/v1.json
}

app.MapGet("/health", () =>
    Results.Ok(new { status = "ok", service = "MindPal.Api" }));

app.MapGet("/health/db", async (
    IConfiguration config,
    ILogger<Program> logger) =>
{
    var connectionString = config.GetConnectionString("MindPal");

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        return Results.Problem(
            "Connection string 'MindPal' is not configured.");
    }

    try
    {
        await using var connection =
            new NpgsqlConnection(connectionString);

        await connection.OpenAsync();

        await using var command =
            new NpgsqlCommand("SELECT 1", connection);

        await command.ExecuteScalarAsync();

        return Results.Ok(new
        {
            status = "ok",
            database = "connected"
        });
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database health check failed");

        return Results.Problem("Database connection failed.");
    }
});

app.MapGet("/health/ready", async (
    MindPalDbContext db,
    CancellationToken ct) =>
    await db.Database.CanConnectAsync(ct)
        ? Results.Ok(new { status = "ready" })
        : Results.Json(
            new { status = "not_ready" },
            statusCode: 503));

app.MapAuth();

app.MapConsents();

app.MapReflection();

app.Run();

// Lets the test project start the API
public partial class Program { }