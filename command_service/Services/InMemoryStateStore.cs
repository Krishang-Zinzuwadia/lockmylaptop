using System.Collections.Concurrent;
using System.Text.Json;
using LockMyLaptop.SharedContracts;
using Microsoft.Extensions.Hosting;

namespace LockMyLaptop.CommandService.Services;

public sealed record CommandCacheEntry(Guid CommandId, string State, DateTimeOffset CreatedAt);

public sealed class InMemoryStateStore
{
    private readonly object _sync = new();
    private readonly ConcurrentDictionary<Guid, TaskCompletionSource<CommandResultMessage>> _pendingCommands = new();
    private readonly string _stateFilePath;

    public InMemoryStateStore(IHostEnvironment hostEnvironment)
    {
        _stateFilePath = Path.Combine(hostEnvironment.ContentRootPath, ".state", "store.json");
        LoadState();
    }

    public string? ActiveLaptopId { get; set; }
    public string? ActiveMobileDeviceId { get; set; }
    public string? ActivePairTokenHash { get; set; }
    public DateTimeOffset? PairExpiryUtc { get; set; }
    public string? CurrentPairingCodePlain { get; set; }
    public string? CurrentPairingCodeHash { get; set; }
    public DateTimeOffset? PairingCodeExpiryUtc { get; set; }
    public int FailedCodeAttempts { get; set; }
    public DateTimeOffset? PairingCooldownUntilUtc { get; set; }
    public string? LaptopConnectionId { get; set; }
    public DateTimeOffset? LastCommandAtUtc { get; set; }
    public Dictionary<string, CommandCacheEntry> IdempotencyCache { get; } = new(StringComparer.Ordinal);

    public TResult Read<TResult>(Func<InMemoryStateStore, TResult> selector)
    {
        lock (_sync)
        {
            return selector(this);
        }
    }

    public void Write(Action<InMemoryStateStore> mutator)
    {
        lock (_sync)
        {
            mutator(this);
            SaveStateNoThrow();
        }
    }

    public Task<CommandResultMessage> CreatePendingCommand(Guid commandId)
    {
        var tcs = new TaskCompletionSource<CommandResultMessage>(TaskCreationOptions.RunContinuationsAsynchronously);
        _pendingCommands[commandId] = tcs;
        return tcs.Task;
    }

    public void CompletePendingCommand(CommandResultMessage result)
    {
        if (_pendingCommands.TryRemove(result.CommandId, out var tcs))
        {
            tcs.TrySetResult(result);
        }
    }

    public void CancelPendingCommand(Guid commandId)
    {
        if (_pendingCommands.TryRemove(commandId, out var tcs))
        {
            tcs.TrySetCanceled();
        }
    }

    public void CleanupIdempotencyCache(DateTimeOffset nowUtc, TimeSpan maxAge)
    {
        var toRemove = IdempotencyCache
            .Where(x => nowUtc - x.Value.CreatedAt > maxAge)
            .Select(x => x.Key)
            .ToArray();

        foreach (var key in toRemove)
        {
            IdempotencyCache.Remove(key);
        }
    }

    private void SaveStateNoThrow()
    {
        try
        {
            var snapshot = new PersistentSnapshot
            {
                ActiveLaptopId = ActiveLaptopId,
                ActiveMobileDeviceId = ActiveMobileDeviceId,
                ActivePairTokenHash = ActivePairTokenHash,
                PairExpiryUtc = PairExpiryUtc,
                CurrentPairingCodePlain = CurrentPairingCodePlain,
                CurrentPairingCodeHash = CurrentPairingCodeHash,
                PairingCodeExpiryUtc = PairingCodeExpiryUtc,
                FailedCodeAttempts = FailedCodeAttempts,
                PairingCooldownUntilUtc = PairingCooldownUntilUtc,
                LastCommandAtUtc = LastCommandAtUtc
            };

            Directory.CreateDirectory(Path.GetDirectoryName(_stateFilePath)!);
            var json = JsonSerializer.Serialize(snapshot, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(_stateFilePath, json);
        }
        catch
        {
            // Ignore persistence failures and continue serving in-memory state.
        }
    }

    private void LoadState()
    {
        try
        {
            if (!File.Exists(_stateFilePath))
            {
                return;
            }

            var json = File.ReadAllText(_stateFilePath);
            var snapshot = JsonSerializer.Deserialize<PersistentSnapshot>(json);
            if (snapshot is null)
            {
                return;
            }

            ActiveLaptopId = snapshot.ActiveLaptopId;
            ActiveMobileDeviceId = snapshot.ActiveMobileDeviceId;
            ActivePairTokenHash = snapshot.ActivePairTokenHash;
            PairExpiryUtc = snapshot.PairExpiryUtc;
            CurrentPairingCodePlain = snapshot.CurrentPairingCodePlain;
            CurrentPairingCodeHash = snapshot.CurrentPairingCodeHash;
            PairingCodeExpiryUtc = snapshot.PairingCodeExpiryUtc;
            FailedCodeAttempts = snapshot.FailedCodeAttempts;
            PairingCooldownUntilUtc = snapshot.PairingCooldownUntilUtc;
            LastCommandAtUtc = snapshot.LastCommandAtUtc;
        }
        catch
        {
            // Ignore state load errors and start fresh.
        }
    }

    private sealed class PersistentSnapshot
    {
        public string? ActiveLaptopId { get; set; }
        public string? ActiveMobileDeviceId { get; set; }
        public string? ActivePairTokenHash { get; set; }
        public DateTimeOffset? PairExpiryUtc { get; set; }
        public string? CurrentPairingCodePlain { get; set; }
        public string? CurrentPairingCodeHash { get; set; }
        public DateTimeOffset? PairingCodeExpiryUtc { get; set; }
        public int FailedCodeAttempts { get; set; }
        public DateTimeOffset? PairingCooldownUntilUtc { get; set; }
        public DateTimeOffset? LastCommandAtUtc { get; set; }
    }
}
