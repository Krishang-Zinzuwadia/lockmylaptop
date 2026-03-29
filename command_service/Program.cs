using System.Security.Cryptography;
using LockMyLaptop.CommandService.Hubs;
using LockMyLaptop.CommandService.Services;
using LockMyLaptop.SharedContracts;

var builder = WebApplication.CreateBuilder(args);

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

	var code = RandomNumberGenerator.GetInt32(0, 10000).ToString("D4");
	var expiresAt = DateTimeOffset.UtcNow.AddSeconds(90);

	store.Write(s =>
	{
		s.ActiveLaptopId = request.LaptopId.Trim();
		s.CurrentPairingCode = code;
		s.PairingCodeExpiryUtc = expiresAt;
		s.FailedCodeAttempts = 0;
		s.PairingCooldownUntilUtc = null;
	});

	return Results.Ok(new StartCodeResponse(code, expiresAt));
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
	var result = store.Read(s =>
	{
		if (s.PairingCooldownUntilUtc.HasValue && now < s.PairingCooldownUntilUtc.Value)
		{
			return (ok: false, status: "cooldown", pair: (PairResponse?)null);
		}

		if (string.IsNullOrWhiteSpace(s.CurrentPairingCode) ||
			!s.PairingCodeExpiryUtc.HasValue ||
			now > s.PairingCodeExpiryUtc.Value)
		{
			return (ok: false, status: "expired", pair: (PairResponse?)null);
		}

		if (!string.Equals(request.PairingCode, s.CurrentPairingCode, StringComparison.Ordinal))
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

		s.ActivePairToken = token;
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

app.MapHub<AgentHub>("/hubs/agent");

app.Run();
