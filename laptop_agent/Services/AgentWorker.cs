using System.Net.Http.Json;
using LockMyLaptop.SharedContracts;
using Microsoft.Extensions.Options;

namespace LockMyLaptop.LaptopAgent.Services;

public sealed class AgentWorker(
    ILogger<AgentWorker> logger,
    IHttpClientFactory httpClientFactory,
    IOptions<AgentOptions> options) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Agent worker started.");
        var agentOptions = options.Value;
        var client = httpClientFactory.CreateClient();

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var endpoint = $"{agentOptions.CommandServiceBaseUrl.TrimEnd('/')}/api/pair/start-code";
                var response = await client.PostAsJsonAsync(
                    endpoint,
                    new StartCodeRequest(agentOptions.LaptopId),
                    stoppingToken);

                if (response.IsSuccessStatusCode)
                {
                    var payload = await response.Content.ReadFromJsonAsync<StartCodeResponse>(cancellationToken: stoppingToken);
                    if (payload is not null)
                    {
                        logger.LogInformation(
                            "Pairing code {Code} generated for laptop {LaptopId} (expires at {ExpiresAt:u}).",
                            payload.PairingCode,
                            agentOptions.LaptopId,
                            payload.ExpiresAt);
                    }
                }
                else
                {
                    logger.LogWarning("Failed to refresh pairing code: HTTP {StatusCode}.", (int)response.StatusCode);
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error requesting pairing code from command service.");
            }

            await Task.Delay(TimeSpan.FromSeconds(60), stoppingToken);
        }
    }
}
