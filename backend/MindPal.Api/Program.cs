using System.Net;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using MindPal.Api.Admin;
using MindPal.Api.Auth;
using MindPal.Api.Consents;
using MindPal.Api.Data;
using MindPal.Api.Email;
using MindPal.Api.Reflection;
using MindPal.Api.Services;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient();

// Email: Brevo HTTPS API when Email:Provider is "Brevo" (deployment),
// Gmail SMTP otherwise (local development). Secrets come from User Secrets
// or environment variables.
if (string.Equals(builder.Configuration["Email:Provider"], "Brevo",
        StringComparison.OrdinalIgnoreCase))
{
    builder.Services.AddHttpClient<IEmailSender, BrevoEmailSender>(
        c => c.Timeout = TimeSpan.FromSeconds(15));
}
else
{
    builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();
}

// Request body limit: 20 KB (SRS v1.1)
builder.WebHost.ConfigureKestrel(o =>
    o.Limits.MaxRequestBodySize = 20 * 1024);

// Database context
builder.Services.AddDbContext<MindPalDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("MindPal")));

// ---- JWT settings (secret must come from User Secrets/environment) ----
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
          ?? new JwtOptions();

if (string.IsNullOrWhiteSpace(jwt.Key) ||
    Encoding.UTF8.GetByteCount(jwt.Key) < 32)
{
    throw new InvalidOperationException(
        "Jwt:Key is missing or shorter than 32 bytes. " +
        "Set it with 'dotnet user-secrets set Jwt:Key <value>'.");
}

builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton<TokenService>();

builder.Services.AddAuthentication(
        JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;

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

        // Reject tokens belonging to deleted or suspended accounts.
        o.Events = new JwtBearerEvents
        {
            OnTokenValidated = async ctx =>
            {
                if (!Guid.TryParse(
                        ctx.Principal?.FindFirst("sub")?.Value,
                        out var userId))
                {
                    ctx.Fail("Invalid token");
                    return;
                }

                var db = ctx.HttpContext.RequestServices
                    .GetRequiredService<MindPalDbContext>();

                var status = await db.Users
                    .AsNoTracking()
                    .Where(u => u.Id == userId)
                    .Select(u => u.Status)
                    .FirstOrDefaultAsync(
                        ctx.HttpContext.RequestAborted);

                if (!AccountDeletion.CanSignIn(status))
                {
                    ctx.Fail("Account is not active");
                }
            }
        };
    });

builder.Services.AddAuthorization(o =>
    o.AddPolicy("admin", p => p
        .RequireAuthenticatedUser()
        .RequireRole("admin")));

// Browser access for the admin portal only (Cors:AdminOrigins, comma-separated).
var adminOrigins = (builder.Configuration["Cors:AdminOrigins"] ?? "")
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

if (adminOrigins.Length == 0 && builder.Environment.IsDevelopment())
    adminOrigins = ["http://localhost:5173", "http://localhost:4173"];

builder.Services.AddCors(o => o.AddPolicy("admin-portal", p =>
{
    if (adminOrigins.Length > 0)
        p.WithOrigins(adminOrigins).AllowAnyHeader().AllowAnyMethod();
}));

// ---- Problem details (RFC 9457) ----
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

// Reflection service
builder.Services.AddScoped<IReflectionEngine, GeminiReflectionEngine>();

// Account deletion background service
builder.Services.AddHostedService<AccountPurgeService>();

// Housekeeping: removes expired sign-in tokens and e-mail codes
builder.Services.AddHostedService<TokenCleanupService>();

// First admin account (only when Admin:Email and Admin:Password are set)
builder.Services.AddHostedService<AdminSeeder>();

// ---- Rate limiting (SRS v1.1) ----
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    o.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = 429;
        ctx.HttpContext.Response.ContentType = "application/problem+json";

        await ctx.HttpContext.Response.WriteAsync(
            "{\"type\":\"about:blank\",\"title\":\"Too many requests\"," +
            "\"status\":429,\"code\":\"rate_limited\"}",
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

    o.AddPolicy("admin", c =>
        RateLimitPartition.GetFixedWindowLimiter(
            c.User.FindFirst("sub")?.Value ?? Ip(c),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 120,
                Window = TimeSpan.FromMinutes(1)
            }));

    o.AddPolicy("telemetry", c =>
        RateLimitPartition.GetFixedWindowLimiter(
            c.User.FindFirst("sub")?.Value ?? Ip(c),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window = TimeSpan.FromMinutes(1)
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

// Render sits behind a proxy: use the real client IP for rate limits.
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
app.UseCors("admin-portal");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
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
app.MapAccount();
app.MapFeedback();
app.MapAdmin();

app.Run();

// Lets the test project start the API.
public partial class Program { }