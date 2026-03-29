using LockMyLaptop.CommandService.Services;
using LockMyLaptop.SharedContracts;
using Microsoft.AspNetCore.SignalR;

namespace LockMyLaptop.CommandService.Hubs;

public sealed class AgentHub(InMemoryStateStore store) : Hub
{
    public Task RegisterLaptop(string laptopId)
    {
        store.Write(s =>
        {
            s.ActiveLaptopId = laptopId;
            s.LaptopConnectionId = Context.ConnectionId;
        });

        return Task.CompletedTask;
    }

    public Task CommandResult(CommandResultMessage message)
    {
        store.CompletePendingCommand(message);
        return Task.CompletedTask;
    }

    public override async Task OnConnectedAsync()
    {
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        store.Write(s =>
        {
            if (s.LaptopConnectionId == Context.ConnectionId)
            {
                s.LaptopConnectionId = null;
            }
        });

        await base.OnDisconnectedAsync(exception);
    }
}
