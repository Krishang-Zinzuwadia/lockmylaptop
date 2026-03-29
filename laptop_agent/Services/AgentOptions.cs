namespace LockMyLaptop.LaptopAgent.Services;

public sealed class AgentOptions
{
    public const string SectionName = "Agent";

    public string LaptopId { get; set; } = "laptop-local-001";
    public string CommandServiceBaseUrl { get; set; } = "http://localhost:5000";
}
