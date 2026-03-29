import 'package:flutter/material.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LockMyLaptop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming in Phase 4')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
      ),
    );
  }
}
