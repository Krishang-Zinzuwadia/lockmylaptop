using System.Net.Http.Json;
using LockMyLaptop.SharedContracts;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Options;

namespace LockMyLaptop.LaptopAgent.Services;

public sealed class AgentWorker(
    ILogger<AgentWorker> logger,
    IHttpClientFactory httpClientFactory,
    PowerController powerController,
    IOptions<AgentOptions> options) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Agent worker started.");
        var agentOptions = options.Value;
        var client = httpClientFactory.CreateClient();
        var hubUrl = $"{agentOptions.CommandServiceBaseUrl.TrimEnd('/')}/hubs/agent";

        var connection = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .WithAutomaticReconnect()
            .Build();

        connection.On<DispatchCommandMessage>("DispatchCommand", async message =>
        {
            var success = false;
            string? error = null;

            try
            {
                success = message.CommandType switch
                {
                    CommandType.LockWorkstation => powerController.Lock(),
                    CommandType.Sleep => powerController.Sleep(),
                    CommandType.Shutdown => powerController.Shutdown(),
                    _ => false
                };

                if (!success)
                {
                    error = "command_execution_failed";
                }
            }
            catch (Exception ex)
            {
                success = false;
                error = ex.Message;
                logger.LogError(ex, "Power command execution failed for {CommandId}", message.CommandId);
            }

            var result = new CommandResultMessage(
                message.CommandId,
                success,
                error,
                DateTimeOffset.UtcNow);

            await connection.InvokeAsync("CommandResult", result);
        });

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (connection.State == HubConnectionState.Disconnected)
                {
                    await connection.StartAsync(stoppingToken);
                    await connection.InvokeAsync("RegisterLaptop", agentOptions.LaptopId, stoppingToken);
                    logger.LogInformation("Connected to command hub for laptop {LaptopId}.", agentOptions.LaptopId);
                }

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

        await connection.DisposeAsync();
    }
}
