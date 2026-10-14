using System.Net;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using MindPal.Api.Reflection;
using Xunit;

namespace MindPal.Api.Tests;

public class GeminiReflectionEngineTests
{
    private sealed class FakeHandler(params HttpResponseMessage[] responses) : HttpMessageHandler
    {
        private readonly Queue<HttpResponseMessage> _queue = new(responses);

        public List<string> Urls { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken ct)
        {
            Urls.Add(request.RequestUri!.ToString());
            return Task.FromResult(_queue.Dequeue());
        }
    }

    private sealed class FakeFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) =>
            new(handler, disposeHandler: false);
    }

    private static HttpResponseMessage Ok()
    {
        var inner = JsonSerializer.Serialize(new
        {
            acknowledgement = "That sounds hard.",
            thinkingPattern = "catastrophizing",
            questions = new[] { "What do you know for sure?" },
            balancedThought = "One result does not decide everything.",
            nextStep = "Take a short walk."
        });

        var body = JsonSerializer.Serialize(new
        {
            candidates = new[]
            {
                new
                {
                    content = new
                    {
                        parts = new[] { new { text = inner } }
                    }
                }
            }
        });

        return new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(body)
        };
    }

    private static HttpResponseMessage Fail(HttpStatusCode code) =>
        new(code) { Content = new StringContent("{}") };

    private static HttpResponseMessage WithContent(string content) =>
        new(HttpStatusCode.OK) { Content = new StringContent(content) };

    private static GeminiReflectionEngine Engine(
        FakeHandler handler,
        bool withFallback = true)
    {
        var settings = new Dictionary<string, string?>
        {
            ["Gemini:ApiKey"] = "test-key",
            ["Gemini:Model"] = "primary-model",
            ["Gemini:RetryDelayMs"] = "0"
        };

        if (withFallback)
            settings["Gemini:FallbackModel"] = "fallback-model";

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(settings)
            .Build();

        return new GeminiReflectionEngine(
            new FakeFactory(handler),
            config,
            NullLogger<GeminiReflectionEngine>.Instance);
    }

    [Fact]
    public async Task Retries_once_on_503_then_succeeds()
    {
        var handler = new FakeHandler(
            Fail(HttpStatusCode.ServiceUnavailable),
            Ok());

        var result = await Engine(handler)
            .ReflectAsync("hello", CancellationToken.None);

        Assert.Equal("primary-model", result.ModelUsed);
        Assert.Equal(2, handler.Urls.Count);
    }

    [Fact]
    public async Task Uses_fallback_model_when_primary_keeps_failing()
    {
        var handler = new FakeHandler(
            Fail(HttpStatusCode.ServiceUnavailable),
            Fail(HttpStatusCode.ServiceUnavailable),
            Ok());

        var result = await Engine(handler)
            .ReflectAsync("hello", CancellationToken.None);

        Assert.Equal("fallback-model", result.ModelUsed);
        Assert.Contains("fallback-model", handler.Urls[2]);
    }

    [Fact]
    public async Task Does_not_retry_a_400_on_the_same_model()
    {
        var handler = new FakeHandler(
            Fail(HttpStatusCode.BadRequest),
            Ok());

        var result = await Engine(handler)
            .ReflectAsync("hello", CancellationToken.None);

        Assert.Equal("fallback-model", result.ModelUsed);
        Assert.Equal(2, handler.Urls.Count);
    }

    [Fact]
    public async Task Throws_error_after_all_attempts_fail()
    {
        var handler = new FakeHandler(
            Fail(HttpStatusCode.ServiceUnavailable),
            Fail(HttpStatusCode.ServiceUnavailable),
            Fail(HttpStatusCode.ServiceUnavailable),
            Fail(HttpStatusCode.ServiceUnavailable));

        var ex = await Assert.ThrowsAsync<ReflectionException>(
            () => Engine(handler).ReflectAsync("hello", CancellationToken.None));

        Assert.Equal("error", ex.Status);
        Assert.Equal(4, handler.Urls.Count); // 2 models x 2 attempts
    }

    [Fact]
    public void Attempt_cap_blocks_at_30_per_hour()
    {
        Assert.False(ReflectionLimits.IsAttemptCapExceeded(29));
        Assert.True(ReflectionLimits.IsAttemptCapExceeded(30));
    }

    [Fact]
    public async Task Invalid_json_throws_error_after_all_attempts_fail()
    {
        var handler = new FakeHandler(
            WithContent("{"),
            WithContent("{"),
            WithContent("{"),
            WithContent("{"));

        var ex = await Assert.ThrowsAsync<ReflectionException>(
            () => Engine(handler).ReflectAsync("hello", CancellationToken.None));

        Assert.Equal("error", ex.Status);
        Assert.Equal(4, handler.Urls.Count); // 2 models x 2 attempts
    }

    [Fact]
    public async Task Missing_provider_payload_throws_error_after_all_attempts_fail()
    {
        var handler = new FakeHandler(
            WithContent("{}"),
            WithContent("{}"),
            WithContent("{}"),
            WithContent("{}"));

        var ex = await Assert.ThrowsAsync<ReflectionException>(
            () => Engine(handler).ReflectAsync("hello", CancellationToken.None));

        Assert.Equal("error", ex.Status);
        Assert.Equal(4, handler.Urls.Count); // 2 models x 2 attempts
    }
}