using System.Net;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using MindPal.Api.Email;

namespace MindPal.Api.Tests;

public class EmailSenderTests
{
    private sealed class CaptureHandler(HttpStatusCode status) : HttpMessageHandler
    {
        public HttpRequestMessage? Request;
        public string? Body;

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken ct)
        {
            Request = request;
            Body = request.Content is null
                ? null
                : await request.Content.ReadAsStringAsync(ct);
            return new HttpResponseMessage(status)
            {
                Content = new StringContent("{\"code\":\"x\",\"message\":\"m\"}")
            };
        }
    }

    private static BrevoEmailSender Make(
        CaptureHandler handler, string? apiKey = "key-123", string? sender = "me@example.com")
    {
        var values = new Dictionary<string, string?>
        {
            ["Email:Brevo:ApiKey"] = apiKey,
            ["Email:Brevo:SenderEmail"] = sender,
            ["Email:Brevo:SenderName"] = "MindPal Team"
        };
        var config = new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        return new BrevoEmailSender(
            new HttpClient(handler), config, NullLogger<BrevoEmailSender>.Instance);
    }

    [Fact]
    public async Task Brevo_PostsCodeToTheApiWithKeyHeader()
    {
        var h = new CaptureHandler(HttpStatusCode.Created);
        await Make(h).SendVerificationCodeAsync("ali@example.com", "Ali", "123456");

        Assert.Equal(HttpMethod.Post, h.Request!.Method);
        Assert.Equal(BrevoEmailSender.Endpoint, h.Request.RequestUri!.ToString());
        Assert.Equal("key-123", h.Request.Headers.GetValues("api-key").Single());

        using var doc = JsonDocument.Parse(h.Body!);
        var root = doc.RootElement;
        Assert.Equal("me@example.com", root.GetProperty("sender").GetProperty("email").GetString());
        Assert.Equal("ali@example.com", root.GetProperty("to")[0].GetProperty("email").GetString());
        Assert.Contains("123456", root.GetProperty("textContent").GetString());
        Assert.Contains("123456", root.GetProperty("htmlContent").GetString());
        Assert.Equal("Your MindPal verification code", root.GetProperty("subject").GetString());
    }

    [Fact]
    public async Task Brevo_ResetEmailUsesResetWording()
    {
        var h = new CaptureHandler(HttpStatusCode.Created);
        await Make(h).SendPasswordResetCodeAsync("ali@example.com", "Ali", "654321");

        using var doc = JsonDocument.Parse(h.Body!);
        Assert.Equal("Your MindPal password reset code",
            doc.RootElement.GetProperty("subject").GetString());
    }

    [Fact]
    public async Task Brevo_RejectedRequest_Throws()
    {
        var h = new CaptureHandler(HttpStatusCode.Unauthorized);
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Make(h).SendVerificationCodeAsync("ali@example.com", "Ali", "123456"));
        Assert.DoesNotContain("123456", ex.Message);
        Assert.DoesNotContain("key-123", ex.Message);
    }

    [Theory]
    [InlineData(null, "me@example.com")]
    [InlineData("", "me@example.com")]
    [InlineData("key", null)]
    public async Task Brevo_MissingSettings_Throw(string? apiKey, string? sender)
    {
        var h = new CaptureHandler(HttpStatusCode.Created);
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            Make(h, apiKey, sender).SendVerificationCodeAsync("a@b.com", "A", "111111"));
        Assert.Null(h.Request);
    }

    [Fact]
    public void Templates_EncodeTheNameInHtmlOnly()
    {
        var c = EmailTemplates.Verification("<b>Ali</b>", "123456");
        Assert.DoesNotContain("<b>Ali</b>", c.Html);
        Assert.Contains("&lt;b&gt;", c.Html);
        Assert.Contains("<b>Ali</b>", c.Text);
    }
}
