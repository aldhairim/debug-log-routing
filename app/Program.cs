using System.Diagnostics;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Serilog;
using Serilog.Events;
using Serilog.Formatting.Compact;

// Required for gRPC over plain HTTP/2 (h2c) — Alloy receiver uses unencrypted gRPC on port 4317.
// Without this, .NET's gRPC client silently fails to connect to non-TLS endpoints.
AppContext.SetSwitch("System.Net.Http.SocketsHttpHandler.Http2UnencryptedSupport", true);

// Map LOG_LEVEL env var to Serilog level (default: info)
var logLevel = (Environment.GetEnvironmentVariable("LOG_LEVEL") ?? "info").ToLower() switch
{
    "debug"            => LogEventLevel.Debug,
    "warn" or "warning" => LogEventLevel.Warning,
    "error"            => LogEventLevel.Error,
    _                  => LogEventLevel.Information
};

// Logs go to stdout only — Alloy reads /var/log/pods and routes:
//   debug        → S3 (s3-pipeline)
//   info/warn/error → Grafana Cloud (existing pipeline)
// No OTel log exporter — avoids duplicates and the "back door" to Grafana Cloud.
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Is(logLevel)
    .Enrich.FromLogContext()
    .Enrich.With<ActivityEnricher>()              // adds trace_id + span_id from current OTel Activity
    .Enrich.With<LevelEnricher>()                 // adds lowercase "level" field so Alloy filters match
    .Enrich.With<DeploymentEnvironmentEnricher>() // adds deployment_environment so App O11y log correlation works
    .WriteTo.Console(new CompactJsonFormatter())
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();

var otlpEndpoint = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT")
    ?? "http://grafana-k8s-monitoring-alloy-receiver.monitoring.svc.cluster.local:4317";

// OTel: traces + metrics via OTLP — log exporter intentionally omitted
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r
        .AddService(serviceName: "countdown-backend", serviceVersion: "1.0.0")
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "production",
            ["service.namespace"]      = "countdown",
            ["service.instance.id"]    = Environment.GetEnvironmentVariable("POD_NAME") ?? Environment.MachineName
        }))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint)))
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint)));

var app = builder.Build();

app.UseSerilogRequestLogging();

app.MapGet("/health", (ILogger<Program> logger) =>
{
    logger.LogDebug("Health check");
    return Results.Ok(new { status = "ok", service = "countdown-backend" });
});

app.MapGet("/api/releases", (ILogger<Program> logger) =>
{
    var releases = new[]
    {
        new { id = 1, name = "v1.0.0", date = "2025-01-15" },
        new { id = 2, name = "v1.1.0", date = "2025-03-20" },
        new { id = 3, name = "v2.0.0", date = "2025-06-01" },
    };
    logger.LogDebug("Releases response {@Releases}", releases);
    return Results.Ok(releases);
});

app.MapGet("/api/slow", (ILogger<Program> logger) =>
{
    var elapsedMs = Random.Shared.Next(800, 2000);
    logger.LogWarning("Slow response detected: {ElapsedMs}ms exceeds threshold of 500ms", elapsedMs);
    return Results.Ok(new { message = "slow response", elapsedMs });
});

app.MapGet("/api/error", (ILogger<Program> logger) =>
{
    try
    {
        throw new InvalidOperationException("Downstream service unavailable");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Failed to process request: {Reason}", ex.Message);
        return Results.Problem("Internal server error", statusCode: 500);
    }
});

Log.Information("countdown-backend starting up");
app.Run();

// Enriches every log entry with trace_id and span_id from the active OTel Activity.
// These fields appear in the stdout JSON, so Grafana Cloud can correlate logs with
// traces without needing an OTel log exporter.
public class ActivityEnricher : Serilog.Core.ILogEventEnricher
{
    public void Enrich(Serilog.Events.LogEvent logEvent, Serilog.Core.ILogEventPropertyFactory propertyFactory)
    {
        var activity = Activity.Current;
        if (activity is null) return;
        logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("trace_id", activity.TraceId.ToString()));
        logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("span_id", activity.SpanId.ToString()));
    }
}

// Adds deployment_environment to every log entry so Alloy can promote it as a Loki label.
// App O11y's Logs tab filters by deployment_environment="production" — without this label
// the query returns no data because it's not attached by the file pipeline automatically.
public class DeploymentEnvironmentEnricher : Serilog.Core.ILogEventEnricher
{
    private static readonly string Value =
        Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "production";

    public void Enrich(Serilog.Events.LogEvent logEvent, Serilog.Core.ILogEventPropertyFactory propertyFactory)
        => logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("deployment_environment", Value));
}

// Adds a lowercase "level" field (e.g. "debug", "info") to every log entry.
// Serilog's CompactJsonFormatter uses "@l" for level, but the Alloy pipeline filter
// looks for "level" — this bridges the two formats without changing the Alloy config.
public class LevelEnricher : Serilog.Core.ILogEventEnricher
{
    public void Enrich(Serilog.Events.LogEvent logEvent, Serilog.Core.ILogEventPropertyFactory propertyFactory)
    {
        var level = logEvent.Level switch
        {
            LogEventLevel.Debug       => "debug",
            LogEventLevel.Information => "info",
            LogEventLevel.Warning     => "warning",
            LogEventLevel.Error       => "error",
            LogEventLevel.Fatal       => "fatal",
            _                         => "verbose"
        };
        logEvent.AddPropertyIfAbsent(propertyFactory.CreateProperty("level", level));
    }
}
