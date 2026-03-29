import 'package:flutter/material.dart';
import 'app_api.dart';

void main() {
  runApp(const LockMyLaptopApp());
}

class LockMyLaptopApp extends StatelessWidget {
  const LockMyLaptopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LockMyLaptop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D3E)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final AppApi _api = AppApi();
  bool _isLoading = false;
  String? _pairToken;
  String? _laptopId;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pairDevice() async {
    final code = _codeController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 4-digit code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _api.pair(
        pairingCode: code,
        mobileDeviceId: 'android-local-001',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pairToken = response.pairToken;
        _laptopId = response.laptopId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paired with ${response.laptopId}')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pairing failed. Check code and retry.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPairingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter 4-digit laptop code',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '0000',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _pairDevice,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_laptopId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Connected to $_laptopId'),
            ),
          SizedBox(
            width: 220,
            height: 220,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lock action coming in Phase 3')),
                );
              },
              style: ElevatedButton.styleFrom(shape: const CircleBorder()),
              child: const Icon(Icons.power_settings_new, size: 72),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sleep action coming in Phase 3')),
              );
            },
            icon: const Icon(Icons.hotel),
            label: const Text('Sleep Laptop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LockMyLaptop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _pairToken == null ? null : () {},
          ),
        ],
      ),
      body: _pairToken == null ? _buildPairingView() : _buildPowerView(),
    );
  }
}
