import 'dart:convert';

import 'package:http/http.dart' as http;

class PairResponse {
  PairResponse({required this.pairToken, required this.laptopId});

  final String pairToken;
  final String laptopId;

  factory PairResponse.fromJson(Map<String, dynamic> json) {
    return PairResponse(
      pairToken: json['pairToken'] as String,
      laptopId: json['laptopId'] as String,
    );
  }
}

class AppApi {
  AppApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'http://10.0.2.2:5000';

  final http.Client _client;
  final String _baseUrl;

  Future<PairResponse> pair({
    required String pairingCode,
    required String mobileDeviceId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/pair/confirm');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pairingCode': pairingCode,
        'mobileDeviceId': mobileDeviceId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Pairing failed: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return PairResponse.fromJson(payload);
  }

  Future<void> lock({required String pairToken}) async {
    await _sendPowerCommand(endpoint: '/api/commands/lock', pairToken: pairToken);
  }

  Future<void> sleep({required String pairToken}) async {
    await _sendPowerCommand(endpoint: '/api/commands/sleep', pairToken: pairToken);
  }

  Future<void> _sendPowerCommand({
    required String endpoint,
    required String pairToken,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pairToken': pairToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Power command failed: ${response.body}');
    }
  }
}
