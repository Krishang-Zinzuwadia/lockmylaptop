namespace LockMyLaptop.SharedContracts;

public enum CommandType
{
    LockWorkstation = 1,
    Sleep = 2
}

public sealed record DispatchCommandMessage(
    Guid CommandId,
    string LaptopId,
    CommandType CommandType,
    DateTimeOffset IssuedAt,
    DateTimeOffset ExpiresAt);

public sealed record CommandResultMessage(
    Guid CommandId,
    bool Success,
    string? Error,
    DateTimeOffset CompletedAt);

public sealed record StartCodeRequest(string LaptopId);
public sealed record StartCodeResponse(string PairingCode, DateTimeOffset ExpiresAt);

public sealed record PairRequest(string PairingCode, string MobileDeviceId);
public sealed record PairResponse(string PairToken, string LaptopId, DateTimeOffset PairedAt);
public sealed record UnpairRequest(string PairToken);
public sealed record PowerCommandRequest(string PairToken);
