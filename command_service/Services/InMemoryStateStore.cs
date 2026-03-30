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
        var appDataRoot = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        _stateFilePath = Path.Combine(appDataRoot, "LockMyLaptop", "command_service", "store.json");

        var legacyStatePaths = GetLegacyStatePaths(hostEnvironment)
            .Where(path => !string.Equals(path, _stateFilePath, StringComparison.OrdinalIgnoreCase))
            .ToArray();

        if (!File.Exists(_stateFilePath))
        {
            var migrated = TryLoadFromCandidates(legacyStatePaths);
            if (migrated)
            {
                SaveStateNoThrow();
                return;
            }
        }

        LoadStateFromPath(_stateFilePath);
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

    private bool TryLoadFromCandidates(IEnumerable<string> candidatePaths)
    {
        foreach (var candidate in candidatePaths)
        {
            if (!File.Exists(candidate))
            {
                continue;
            }

            if (LoadStateFromPath(candidate))
            {
                return true;
            }
        }

        return false;
    }

    private bool LoadStateFromPath(string path)
    {
        try
        {
            if (!File.Exists(path))
            {
                return false;
            }

            var json = File.ReadAllText(path);
            var snapshot = JsonSerializer.Deserialize<PersistentSnapshot>(json);
            if (snapshot is null)
            {
                return false;
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
            return true;
        }
        catch
        {
            // Ignore state load errors and start fresh.
            return false;
        }
    }

    private static IEnumerable<string> GetLegacyStatePaths(IHostEnvironment hostEnvironment)
    {
        yield return Path.Combine(hostEnvironment.ContentRootPath, ".state", "store.json");
        yield return Path.Combine(AppContext.BaseDirectory, ".state", "store.json");
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
