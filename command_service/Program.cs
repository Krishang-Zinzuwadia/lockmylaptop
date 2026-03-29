using LockMyLaptop.CommandService.Hubs;
using LockMyLaptop.CommandService.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSignalR();
builder.Services.AddSingleton<InMemoryStateStore>();

var app = builder.Build();

app.MapGet("/api/status", () => Results.Ok(new { service = "command_service", status = "ok" }));
app.MapHub<AgentHub>("/hubs/agent");

app.Run();
