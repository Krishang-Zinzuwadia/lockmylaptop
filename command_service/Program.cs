using System.Security.Cryptography;
using System.Text;
using LockMyLaptop.CommandService.Hubs;
using LockMyLaptop.CommandService.Services;
using LockMyLaptop.SharedContracts;
using Microsoft.AspNetCore.SignalR;

var builder = WebApplication.CreateBuilder(args);

if (OperatingSystem.IsWindows())
{
	builder.Host.UseWindowsService();
}

builder.Services.AddSignalR();
builder.Services.AddSingleton<InMemoryStateStore>();

var app = builder.Build();

app.MapGet("/api/status", () => Results.Ok(new { service = "command_service", status = "ok" }));

app.MapPost("/api/pair/start-code", (StartCodeRequest request, InMemoryStateStore store) =>
{
	if (string.IsNullOrWhiteSpace(request.LaptopId))
	{
		return Results.BadRequest(new { error = "laptop_id_required" });
	}

	var now = DateTimeOffset.UtcNow;
	var normalizedLaptopId = request.LaptopId.Trim();

	var response = store.Read(s =>
	{
		if (string.Equals(s.ActiveLaptopId, normalizedLaptopId, StringComparison.Ordinal) &&
			!string.IsNullOrWhiteSpace(s.CurrentPairingCodePlain) &&
			s.PairingCodeExpiryUtc.HasValue &&
			now < s.PairingCodeExpiryUtc.Value)
		{
			return new StartCodeResponse(s.CurrentPairingCodePlain!, s.PairingCodeExpiryUtc.Value);
		}

		var code = RandomNumberGenerator.GetInt32(0, 10000).ToString("D4");
		var expiresAt = now.AddSeconds(90);

		s.ActiveLaptopId = normalizedLaptopId;
		s.CurrentPairingCodePlain = code;
		s.CurrentPairingCodeHash = HashValue(code);
		s.PairingCodeExpiryUtc = expiresAt;
		s.FailedCodeAttempts = 0;
		s.PairingCooldownUntilUtc = null;

		return new StartCodeResponse(code, expiresAt);
	});

	return Results.Ok(response);
});

app.MapPost("/api/pair/confirm", (PairRequest request, InMemoryStateStore store) =>
{
	if (string.IsNullOrWhiteSpace(request.PairingCode) || request.PairingCode.Length != 4)
	{
		return Results.BadRequest(new { error = "invalid_code_format" });
	}

	if (string.IsNullOrWhiteSpace(request.MobileDeviceId))
	{
		return Results.BadRequest(new { error = "mobile_device_id_required" });
	}

	var now = DateTimeOffset.UtcNow;
	var submittedCodeHash = HashValue(request.PairingCode);
	var result = store.Read(s =>
	{
		if (s.PairingCooldownUntilUtc.HasValue && now < s.PairingCooldownUntilUtc.Value)
		{
			return (ok: false, status: "cooldown", pair: (PairResponse?)null);
		}

		if (string.IsNullOrWhiteSpace(s.CurrentPairingCodeHash) ||
			!s.PairingCodeExpiryUtc.HasValue ||
			now > s.PairingCodeExpiryUtc.Value)
		{
			return (ok: false, status: "expired", pair: (PairResponse?)null);
		}

		if (!string.Equals(submittedCodeHash, s.CurrentPairingCodeHash, StringComparison.Ordinal))
		{
			s.FailedCodeAttempts += 1;
			if (s.FailedCodeAttempts >= 5)
			{
				s.PairingCooldownUntilUtc = now.AddMinutes(1);
			}

			return (ok: false, status: "invalid", pair: (PairResponse?)null);
		}

		var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
		var pairedAt = DateTimeOffset.UtcNow;

		s.ActiveMobileDeviceId = request.MobileDeviceId.Trim();
		s.ActivePairTokenHash = HashValue(token);
		s.PairExpiryUtc = pairedAt.AddDays(30);
		s.FailedCodeAttempts = 0;
		s.PairingCooldownUntilUtc = null;

		var response = new PairResponse(token, s.ActiveLaptopId ?? "unknown", pairedAt);
		return (ok: true, status: "ok", pair: response);
	});

	if (result.ok)
	{
		return Results.Ok(result.pair);
	}

	return result.status switch
	{
		"cooldown" => Results.StatusCode(StatusCodes.Status429TooManyRequests),
		"expired" => Results.BadRequest(new { error = "pairing_code_expired" }),
		_ => Results.BadRequest(new { error = "invalid_pairing_code" })
	};
});

app.MapPost("/api/pair/unpair", (UnpairRequest request, InMemoryStateStore store) =>
{
	if (string.IsNullOrWhiteSpace(request.PairToken))
	{
		return Results.BadRequest(new { error = "pair_token_required" });
	}

	var submittedTokenHash = HashValue(request.PairToken);
	var result = store.Read(s =>
	{
		if (string.IsNullOrWhiteSpace(s.ActivePairTokenHash) ||
			!string.Equals(s.ActivePairTokenHash, submittedTokenHash, StringComparison.Ordinal))
		{
			return false;
		}

		s.ActivePairTokenHash = null;
		s.PairExpiryUtc = null;
		s.ActiveMobileDeviceId = null;
		s.LastCommandAtUtc = null;
		s.IdempotencyCache.Clear();
		return true;
	});

	if (!result)
	{
		return Results.Unauthorized();
	}

	return Results.Ok(new { status = "unpaired" });
});

app.MapPost("/api/commands/lock", (PowerCommandRequest request, InMemoryStateStore store, IHubContext<AgentHub> hub, CancellationToken cancellationToken) =>
	DispatchPowerCommand(request, CommandType.LockWorkstation, store, hub, cancellationToken));

app.MapPost("/api/commands/sleep", (PowerCommandRequest request, InMemoryStateStore store, IHubContext<AgentHub> hub, CancellationToken cancellationToken) =>
	DispatchPowerCommand(request, CommandType.Sleep, store, hub, cancellationToken));

app.MapPost("/api/commands/shutdown", (PowerCommandRequest request, InMemoryStateStore store, IHubContext<AgentHub> hub, CancellationToken cancellationToken) =>
	DispatchPowerCommand(request, CommandType.Shutdown, store, hub, cancellationToken));

app.MapHub<AgentHub>("/hubs/agent");

app.Run();

static async Task<IResult> DispatchPowerCommand(
	PowerCommandRequest request,
	CommandType commandType,
	InMemoryStateStore store,
	IHubContext<AgentHub> hub,
	CancellationToken cancellationToken)
{
	if (string.IsNullOrWhiteSpace(request.PairToken))
	{
		return Results.BadRequest(new { error = "pair_token_required" });
	}

	var now = DateTimeOffset.UtcNow;
	var submittedTokenHash = HashValue(request.PairToken);
	var idempotencyKey = string.IsNullOrWhiteSpace(request.IdempotencyKey)
		? null
		: request.IdempotencyKey.Trim();

	var state = store.Read(s =>
	{
		s.CleanupIdempotencyCache(now, TimeSpan.FromMinutes(5));

		if (string.IsNullOrWhiteSpace(s.ActivePairTokenHash) ||
			!string.Equals(submittedTokenHash, s.ActivePairTokenHash, StringComparison.Ordinal) ||
			!s.PairExpiryUtc.HasValue ||
			now > s.PairExpiryUtc.Value)
		{
			return (ok: false, error: "invalid_or_expired_pair", laptopId: (string?)null, connectionId: (string?)null, cached: (CommandCacheEntry?)null);
		}

		if (s.LastCommandAtUtc.HasValue && now - s.LastCommandAtUtc.Value < TimeSpan.FromMilliseconds(400))
		{
			return (ok: false, error: "rate_limited", laptopId: (string?)null, connectionId: (string?)null, cached: (CommandCacheEntry?)null);
		}

		if (idempotencyKey is not null && s.IdempotencyCache.TryGetValue(idempotencyKey, out var cached))
		{
			return (ok: false, error: "idempotent_replay", laptopId: (string?)null, connectionId: (string?)null, cached);
		}

		if (string.IsNullOrWhiteSpace(s.LaptopConnectionId) || string.IsNullOrWhiteSpace(s.ActiveLaptopId))
		{
			return (ok: false, error: "laptop_offline", laptopId: (string?)null, connectionId: (string?)null, cached: (CommandCacheEntry?)null);
		}

		s.LastCommandAtUtc = now;

		return (ok: true, error: (string?)null, laptopId: s.ActiveLaptopId, connectionId: s.LaptopConnectionId, cached: (CommandCacheEntry?)null);
	});

	if (state.error == "idempotent_replay" && state.cached is not null)
	{
		return Results.Ok(new
		{
			commandId = state.cached.CommandId,
			state = state.cached.State,
			commandType = commandType.ToString(),
			idempotentReplay = true
		});
	}

	if (!state.ok)
	{
		if (state.error == "rate_limited")
		{
			return Results.StatusCode(StatusCodes.Status429TooManyRequests);
		}

		return state.error == "laptop_offline"
			? Results.BadRequest(new { error = "laptop_offline" })
			: Results.Unauthorized();
	}

	var commandId = Guid.NewGuid();
	var responseTask = store.CreatePendingCommand(commandId);
	var envelope = new DispatchCommandMessage(
		commandId,
		state.laptopId!,
		commandType,
		now,
		now.AddSeconds(20));

	try
	{
		await hub.Clients.Client(state.connectionId!).SendAsync("DispatchCommand", envelope, cancellationToken);
	}
	catch
	{
		store.CancelPendingCommand(commandId);
		return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
	}

	var completed = await Task.WhenAny(responseTask, Task.Delay(TimeSpan.FromSeconds(20), cancellationToken));
	if (completed != responseTask)
	{
		store.CancelPendingCommand(commandId);
		if (idempotencyKey is not null)
		{
			store.Write(s => s.IdempotencyCache[idempotencyKey] = new CommandCacheEntry(commandId, "timeout", DateTimeOffset.UtcNow));
		}
		return Results.StatusCode(StatusCodes.Status504GatewayTimeout);
	}

	var result = await responseTask;
	if (result.Success)
	{
		if (idempotencyKey is not null)
		{
			store.Write(s => s.IdempotencyCache[idempotencyKey] = new CommandCacheEntry(commandId, "succeeded", DateTimeOffset.UtcNow));
		}

		return Results.Ok(new { commandId, state = "succeeded", commandType = commandType.ToString() });
	}

	if (idempotencyKey is not null)
	{
		store.Write(s => s.IdempotencyCache[idempotencyKey] = new CommandCacheEntry(commandId, "failed", DateTimeOffset.UtcNow));
	}

	return Results.Problem(
		title: "command_failed",
		detail: result.Error ?? "Unknown execution failure",
		statusCode: StatusCodes.Status500InternalServerError);
}

static string HashValue(string value)
{
	var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value));
	return Convert.ToHexString(bytes);
}
