import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:core_dio_client/core_dio_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ApiClient.initialize(
    config: const NetworkConfig(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      defaultHeaders: {'Accept': 'application/json'},
      timeout: Duration(seconds: 15),
      maxRetries: 2,
    ),
    tokenProvider: () async => null,
    enableLogging: true,
  );

  runApp(const ConsumerApp());
}

class ConsumerApp extends StatelessWidget {
  const ConsumerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ConsumerHome(),
    );
  }
}

class ConsumerHome extends StatefulWidget {
  const ConsumerHome({super.key});

  @override
  State<ConsumerHome> createState() => _ConsumerHomeState();
}

class _ConsumerHomeState extends State<ConsumerHome> {
  String _output = 'No call yet';

  Future<void> _fetchTodo() async {
    setState(() => _output = 'Loading...');
    final res = await ApiClient.instance.get<Map<String, dynamic>>(url: '/todos/1');
    if (res.success) {
      developer.log('Fetched todo', name: 'consumer');
      setState(() => _output = res.data.toString());
    } else {
      developer.log('Fetch error: ${res.error}', name: 'consumer');
      setState(() => _output = 'Error: ${res.error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consumer App')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_output, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchTodo,
                child: const Text('Fetch Todo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
