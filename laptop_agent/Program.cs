using LockMyLaptop.LaptopAgent.Services;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "LockMyLaptop Agent";
});

builder.Services.AddSingleton<PowerController>();
builder.Services.AddHostedService<AgentWorker>();

var host = builder.Build();
host.Run();
