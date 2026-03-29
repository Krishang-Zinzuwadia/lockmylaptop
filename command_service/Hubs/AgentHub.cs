using Microsoft.AspNetCore.SignalR;

namespace LockMyLaptop.CommandService.Hubs;

public sealed class AgentHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        await base.OnDisconnectedAsync(exception);
    }
}
