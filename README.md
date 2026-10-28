# core_dio_client

A production-ready HTTP network client for Flutter and Dart built on Dio with auto-retry, auth token refresh, structured logging, request cancellation, and progress tracking for downloads and uploads.

## Features

- Configurable singleton ApiClient wrapping Dio
- Typed HTTP request methods: GET, POST, PUT, DELETE, and PATCH
- File download with real-time `onReceiveProgress` callback
- Single and multi-file multipart uploads with `onSendProgress` callback
- Request cancellation support across all methods using `CancelToken`
- Pre-flight network connectivity checker hook to fail fast when offline
- Synchronized token refresh flow on 401 Unauthorized errors
- Automatic retry with exponential backoff and randomized jitter
- Structured console request and response logging with header redaction and body truncation
- Structured `ApiResponse<T>` result wrapper and categorized `ApiException` error types

## Installation

Add `core_dio_client` to your `pubspec.yaml`:

```yaml
dependencies:
  core_dio_client: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize the client

Initialize `ApiClient` once during application bootstrap (for example, in your `main()` function):

```dart
import 'package:flutter/material.dart';
import 'package:core_dio_client/core_dio_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ApiClient.initialize(
    config: const NetworkConfig(
      baseUrl: 'https://api.example.com',
      timeout: Duration(seconds: 15),
      maxRetries: 3,
      defaultHeaders: {
        'Accept': 'application/json',
      },
    ),
    tokenProvider: () async {
      // Return your persisted bearer token from secure storage
      return await secureStorage.read(key: 'auth_token');
    },
    enableLogging: true,
  );

  runApp(const MyApp());
}
```

### 2. Standard Requests

```dart
final client = ApiClient.instance;

// GET request
final response = await client.get<Map<String, dynamic>>(
  url: '/users/profile',
  params: {'include_details': true},
);

if (response.success) {
  print('User profile: ${response.data}');
} else {
  final error = response.error as ApiException;
  print('Error (${error.statusCode}): ${error.message}');
}

// POST request
final createResponse = await client.post<Map<String, dynamic>>(
  url: '/users',
  body: {
    'name': 'Alex Morgan',
    'role': 'Developer',
  },
);
```

### 3. File Download with Progress

Download files directly to disk while tracking download progress:

```dart
final response = await ApiClient.instance.downloadFile(
  url: 'https://example.com/files/report.pdf',
  savePath: '/local/storage/path/report.pdf',
  onReceiveProgress: (receivedBytes, totalBytes) {
    if (totalBytes > 0) {
      final percentage = (receivedBytes / totalBytes * 100).toStringAsFixed(0);
      print('Download progress: $percentage% ($receivedBytes / $totalBytes bytes)');
    }
  },
);

if (response.success) {
  print('File saved to: ${response.data}');
}
```

### 4. File Upload with Progress

#### Single File Upload
```dart
final file = File('/path/to/avatar.png');

final response = await ApiClient.instance.uploadFile<Map<String, dynamic>>(
  url: '/users/avatar',
  file: file,
  fileKey: 'avatar',
  data: {'description': 'Profile image'},
  onSendProgress: (sentBytes, totalBytes) {
    if (totalBytes > 0) {
      final percentage = (sentBytes / totalBytes * 100).toStringAsFixed(0);
      print('Upload progress: $percentage%');
    }
  },
);
```

#### Multiple Files Upload
```dart
final files = [
  File('/path/to/doc1.pdf'),
  File('/path/to/doc2.pdf'),
];

final response = await ApiClient.instance.uploadFiles<Map<String, dynamic>>(
  url: '/documents/batch',
  files: files,
  fileKey: 'attachments',
  data: {'category': 'invoices'},
);
```

### 5. Request Cancellation

Cancel ongoing requests at any time using `CancelToken`:

```dart
final cancelToken = ApiClient.createCancelToken();

// Start long-running request
final future = ApiClient.instance.get<dynamic>(
  url: '/large-dataset',
  cancelToken: cancelToken,
);

// Cancel the operation when user navigates away or presses cancel
cancelToken.cancel('User navigated away');

final response = await future;
if (!response.success) {
  final error = response.error as ApiException;
  if (error.type == ApiErrorType.cancelled) {
    print('Request was cancelled.');
  }
}
```

### 6. Offline Pre-Flight Connectivity Check

Avoid unnecessary request timeouts by checking network state before firing requests:

```dart
ApiClient.initialize(
  config: NetworkConfig(
    baseUrl: 'https://api.example.com',
    connectivityChecker: () async {
      // Replace with your connectivity check logic (e.g. connectivity_plus)
      return await checkInternetReachability();
    },
  ),
);
```

### 7. Token Refresh on 401 Unauthorized

Handle expired access tokens transparently without race conditions:

```dart
ApiClient.initialize(
  config: const NetworkConfig(baseUrl: 'https://api.example.com'),
  tokenProvider: () async => await secureStorage.read(key: 'access_token'),
  refreshTokenHandler: (refreshDio) async {
    final refreshToken = await secureStorage.read(key: 'refresh_token');
    try {
      final refreshResponse = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newAccessToken = refreshResponse.data['access_token'];
      await secureStorage.write(key: 'access_token', value: newAccessToken);
      return true;
    } catch (_) {
      // Clear credentials and prompt login
      return false;
    }
  },
);
```

### 8. Logging and Redaction

The built-in `LoggingInterceptor` formats request and response payloads with automatic redaction of sensitive headers (`Authorization`, `Cookie`, `Set-Cookie`):

```dart
ApiClient.initialize(
  config: const NetworkConfig(baseUrl: 'https://api.example.com'),
  enableLogging: true,
  logPrint: (line) {
    // Optionally redirect logs to your custom logger or Crashlytics
    debugPrint(line);
  },
);
```

## Error Handling

All client methods return an `ApiResponse<T>`:

```dart
final response = await ApiClient.instance.get<Map<String, dynamic>>(url: '/item/1');

if (response.success) {
  print('Result: ${response.data}');
} else {
  final error = response.error as ApiException;
  print('Error message: ${error.message}');
  print('Status code: ${error.statusCode}');
  print('Error type: ${error.type}'); // network, timeout, cancelled, server, client, parse, unknown
}
```

## Repository and Publisher Details

- Repository: `https://github.com/harmish66/core_dio_client`
- Issue Tracker: `https://github.com/harmish66/core_dio_client/issues`

## License

MIT
