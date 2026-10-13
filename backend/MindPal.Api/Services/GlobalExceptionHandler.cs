using System.Text.Json;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace MindPal.Api.Services;

// Every unexpected error leaves the API in the same format, with no stack trace.
public class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext ctx, Exception ex, CancellationToken ct)
    {
        if (ex is OperationCanceledException)   // the app closed the request
        {
            ctx.Response.StatusCode = 499;
            return true;
        }

        int status; string code, title;
        if (ex is BadHttpRequestException bad)
        {
            status = bad.StatusCode;
            code = status == 413 ? "payload_too_large" : "bad_request";
            title = status == 413 ? "Request body too large" : "Invalid request";
            logger.LogWarning("Bad request on {Path}: {Message}", ctx.Request.Path, bad.Message);
        }
        else
        {
            status = 500; code = "server_error"; title = "Something went wrong";
            logger.LogError(ex, "Unhandled exception on {Path}", ctx.Request.Path);
        }

        ctx.Response.StatusCode = status;
        var problem = new ProblemDetails { Status = status, Title = title };
        problem.Extensions["code"] = code;
        await ctx.Response.WriteAsJsonAsync(problem, (JsonSerializerOptions?)null, "application/problem+json", ct);
        return true;
    }
}