import 'package:flutter/material.dart';

void main() {
  print('HELLO FLUTTER');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HELLO FLUTTER',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HELLO FLUTTER'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'HELLO FLUTTER 👋',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          debugPrint('Button tapped — HELLO FLUTTER!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('HELLO FLUTTER!')),
          );
        },
        icon: const Icon(Icons.handshake),
        label: const Text('Tap Me'),
      ),
    );
  }
}
