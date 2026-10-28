// Example usage of the core_dio_client package.

import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:core_dio_client/core_dio_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize client with base URL and token provider
  ApiClient.initialize(
    config: const NetworkConfig(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      maxRetries: 3,
      timeout: Duration(seconds: 10),
    ),
    tokenProvider: () async {
      // Read token from secure storage in production apps
      return 'demo_token';
    },
    enableLogging: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('core_dio_client Example')),
        body: const ExampleWidget(),
      ),
    );
  }
}

class ExampleWidget extends StatefulWidget {
  const ExampleWidget({super.key});

  @override
  State<ExampleWidget> createState() => _ExampleWidgetState();
}

class _ExampleWidgetState extends State<ExampleWidget> {
  String _result = 'No request triggered yet';
  double _uploadProgress = 0.0;
  double _downloadProgress = 0.0;
  CancelToken? _currentCancelToken;

  Future<void> _callApi() async {
    setState(() => _result = 'Fetching...');
    final client = ApiClient.instance;

    final res = await client.get<Map<String, dynamic>>(
      url: '/todos/1',
      headers: {'Accept-Language': 'en'},
    );

    setState(() {
      if (res.success) {
        _result = 'GET success: ${res.data}';
      } else {
        _result = 'Error: ${res.error}';
      }
    });
    developer.log('Call /todos/1 completed', name: 'ExampleWidget');
  }

  Future<File> _createTempFile() async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/sample_upload.txt');
    await file.writeAsString('core_dio_client sample payload ${DateTime.now()}');
    return file;
  }

  Future<void> _uploadFileWithProgress() async {
    setState(() {
      _uploadProgress = 0.0;
      _result = 'Starting file upload...';
    });

    try {
      final file = await _createTempFile();
      final res = await ApiClient.instance.uploadFile<Map<String, dynamic>>(
        url: 'https://httpbin.org/post',
        file: file,
        fileKey: 'attachment',
        data: {'uploader': 'Flutter Developer'},
        onSendProgress: (sent, total) {
          if (total > 0) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );

      setState(() {
        if (res.success) {
          _result = 'Upload complete (100%)';
        } else {
          _result = 'Upload failed: ${res.error}';
        }
      });
    } catch (e) {
      setState(() => _result = 'Upload error: $e');
    }
  }

  Future<void> _downloadFileWithProgress() async {
    setState(() {
      _downloadProgress = 0.0;
      _result = 'Starting file download...';
    });

    try {
      final dir = Directory.systemTemp;
      final targetPath = '${dir.path}/downloaded_sample.jpg';

      final res = await ApiClient.instance.downloadFile(
        url: 'https://picsum.photos/200/300',
        savePath: targetPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        if (res.success) {
          _result = 'Download complete: $targetPath';
        } else {
          _result = 'Download failed: ${res.error}';
        }
      });
    } catch (e) {
      setState(() => _result = 'Download error: $e');
    }
  }

  Future<void> _triggerCancellableRequest() async {
    _currentCancelToken = ApiClient.createCancelToken();
    setState(() => _result = 'Request initiated. Press Cancel Request to abort.');

    final res = await ApiClient.instance.get<Map<String, dynamic>>(
      url: 'https://httpbin.org/delay/5',
      cancelToken: _currentCancelToken,
    );

    setState(() {
      if (res.success) {
        _result = 'Finished delayed request: ${res.data}';
      } else {
        _result = 'Result: ${res.error}';
      }
    });
  }

  void _cancelActiveRequest() {
    if (_currentCancelToken != null && !_currentCancelToken!.isCancelled) {
      _currentCancelToken!.cancel('Operation cancelled by user');
      setState(() => _result = 'Request cancelled by user action.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              _result,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _callApi,
            child: const Text('Perform GET Request'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _uploadFileWithProgress,
            child: const Text('Upload File with Progress'),
          ),
          if (_uploadProgress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _uploadProgress),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _downloadFileWithProgress,
            child: const Text('Download File with Progress'),
          ),
          if (_downloadProgress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _downloadProgress),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _triggerCancellableRequest,
            child: const Text('Trigger Cancellable Request (5s Delay)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _cancelActiveRequest,
            child: const Text('Cancel Active Request'),
          ),
        ],
      ),
    );
  }
}
