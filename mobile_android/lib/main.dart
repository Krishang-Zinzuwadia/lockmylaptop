import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_api.dart';

const Color kBlackBg = Color(0xFF050805);
const Color kBlackSurface = Color(0xFF0A100A);
const Color kLightGreen = Color(0xFF8DFF6A);
const Color kTextLight = Color(0xFFE8FCE5);
const Color kFieldBorder = Color(0xFF2E5A2A);

enum PowerAction { lock, sleep, shutdown }

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
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBlackBg,
        colorScheme: const ColorScheme.dark(
          primary: kLightGreen,
          secondary: kLightGreen,
          surface: kBlackSurface,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: kTextLight,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: kLightGreen,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: kTextLight),
          bodyMedium: TextStyle(color: kTextLight),
          titleLarge: TextStyle(color: kLightGreen, fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: kBlackSurface,
          labelStyle: TextStyle(color: kLightGreen),
          hintStyle: TextStyle(color: Color(0xFF8FBF84)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kFieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kLightGreen, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kLightGreen,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: kBlackSurface,
          contentTextStyle: TextStyle(color: kLightGreen),
        ),
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
  final TextEditingController _apiUrlController = TextEditingController();
  final AppApi _api = AppApi();
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _pairToken;
  String? _laptopId;
  PowerAction _selectedAction = PowerAction.lock;

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = _api.baseUrl;
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('api_url');
    final savedPairToken = prefs.getString('pair_token');
    final savedLaptopId = prefs.getString('laptop_id');
    final savedAction = prefs.getString('power_action');

    if (savedUrl != null && savedUrl.isNotEmpty) {
      _api.setBaseUrl(savedUrl);
      _apiUrlController.text = savedUrl;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pairToken = savedPairToken;
      _laptopId = savedLaptopId;
      _selectedAction = _powerActionFromString(savedAction);
      _isInitializing = false;
    });
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', _api.baseUrl);
    await prefs.setString('power_action', _powerActionToString(_selectedAction));

    if (_pairToken != null && _laptopId != null) {
      await prefs.setString('pair_token', _pairToken!);
      await prefs.setString('laptop_id', _laptopId!);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pair_token');
    await prefs.remove('laptop_id');
  }

  Future<void> _openSettings() async {
    final shouldUnpair = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _apiUrlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.1.10:5000',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Unpair this phone from the connected laptop?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unpair'),
            ),
          ],
        );
      },
    );

    _api.setBaseUrl(_apiUrlController.text);
    await _persistSession();
    if (!mounted) {
      return;
    }

    if (shouldUnpair == null || shouldUnpair == false) {
      return;
    }

    if (shouldUnpair != true || _pairToken == null) {
      return;
    }

    try {
      await _api.unpair(pairToken: _pairToken!);
      if (!mounted) {
        return;
      }

      setState(() {
        _pairToken = null;
        _laptopId = null;
        _codeController.clear();
      });

      await _clearSession();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devices unpaired successfully')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unpair failed')),
      );
    }
  }

  Future<void> _sendLock() async {
    if (_pairToken == null) {
      return;
    }

    try {
      switch (_selectedAction) {
        case PowerAction.lock:
          await _api.lock(pairToken: _pairToken!);
          break;
        case PowerAction.sleep:
          await _api.sleep(pairToken: _pairToken!);
          break;
        case PowerAction.shutdown:
          await _api.shutdown(pairToken: _pairToken!);
          break;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_powerActionLabel(_selectedAction)} command sent')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_powerActionLabel(_selectedAction)} command failed')),
      );
    }
  }

  PowerAction _powerActionFromString(String? value) {
    return switch (value) {
      'sleep' => PowerAction.sleep,
      'shutdown' => PowerAction.shutdown,
      _ => PowerAction.lock,
    };
  }

  String _powerActionToString(PowerAction action) {
    return switch (action) {
      PowerAction.lock => 'lock',
      PowerAction.sleep => 'sleep',
      PowerAction.shutdown => 'shutdown',
    };
  }

  String _powerActionLabel(PowerAction action) {
    return switch (action) {
      PowerAction.lock => 'Lock',
      PowerAction.sleep => 'Sleep',
      PowerAction.shutdown => 'Shut Down',
    };
  }

  IconData _powerActionIcon(PowerAction action) {
    return switch (action) {
      PowerAction.lock => Icons.lock,
      PowerAction.sleep => Icons.bedtime,
      PowerAction.shutdown => Icons.power_off,
    };
  }

  @override
  void dispose() {
    _codeController.dispose();
    _apiUrlController.dispose();
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

      await _persistSession();
      if (!mounted) {
        return;
      }

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
              onPressed: _sendLock,
              style: ElevatedButton.styleFrom(shape: const CircleBorder()),
              child: const Icon(Icons.power_settings_new, size: 72),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kBlackSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kFieldBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PowerAction>(
                value: _selectedAction,
                isExpanded: true,
                dropdownColor: kBlackSurface,
                iconEnabledColor: kLightGreen,
                borderRadius: BorderRadius.circular(14),
                style: const TextStyle(
                  color: kTextLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                selectedItemBuilder: (context) {
                  return PowerAction.values
                      .map(
                        (action) => Row(
                          children: [
                            Icon(_powerActionIcon(action), color: kLightGreen, size: 18),
                            const SizedBox(width: 10),
                            Text('Power Action: ${_powerActionLabel(action)}'),
                          ],
                        ),
                      )
                      .toList();
                },
                items: PowerAction.values
                    .map(
                      (action) => DropdownMenuItem<PowerAction>(
                        value: action,
                        child: Row(
                          children: [
                            Icon(_powerActionIcon(action), color: kLightGreen, size: 18),
                            const SizedBox(width: 10),
                            Text(_powerActionLabel(action)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedAction = value;
                  });

                  await _persistSession();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LockMyLaptop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _pairToken == null ? null : _openSettings,
          ),
        ],
      ),
      body: _pairToken == null ? _buildPairingView() : _buildPowerView(),
    );
  }
}
