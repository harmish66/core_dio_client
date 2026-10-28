# core_dio_client

[![pub package](https://img.shields.io/pub/v/core_dio_client.svg?style=flat-square)](https://pub.dev/packages/core_dio_client)
[![pub points](https://img.shields.io/pub/points/core_dio_client?style=flat-square)](https://pub.dev/packages/core_dio_client/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://github.com/harmish66/core_dio_client/blob/main/LICENSE)
[![platform](https://img.shields.io/badge/platform-flutter%20%7C%20dart-blue?style=flat-square)](https://pub.dev/packages/core_dio_client)

A production-ready HTTP network client for Flutter and Dart built on Dio. Provides auto-retry, auth token refresh, structured logging, request cancellation, and progress tracking for downloads and uploads.

---

## Architectural Flow

```text
[ Application Layer ]
         |
         v
[ ApiClient Singleton ]
         |
         +--> [ Connectivity Check ] -> Fails immediately if offline
         |
         +--> [ AuthInterceptor ] -> Injects Bearer token from secure storage
         |
         +--> [ LoggingInterceptor ] -> Formats output, redacts sensitive headers
         |
         +--> [ RetryInterceptor ] -> Exponential backoff with jitter on 5xx/network errors
         |
         +--> [ 401 Refresh Handler ] -> Synchronized token refresh queue
         |
         v
[ Remote Server / API ]
```

---

## Feature Matrix

| Feature | Supported | Details |
| :--- | :--- | :--- |
| HTTP Methods | Yes | Full typed support for GET, POST, PUT, PATCH, DELETE |
| File Uploads | Yes | Single and multi-file multipart uploads with onSendProgress callback |
| File Downloads | Yes | Direct file saving with onReceiveProgress callback |
| Request Cancellation | Yes | CancelToken support across every network operation |
| Pre-Flight Connectivity | Yes | Custom checker callback to prevent wasteful timeouts when offline |
| 401 Token Refresh | Yes | Thread-safe queue preventing duplicate refresh network calls |
| Auto-Retry Mechanism | Yes | Exponential backoff with randomized jitter on network errors and 5xx |
| Structured Logging | Yes | Formatted request and response logs with sensitive header redaction |
| Structured Errors | Yes | Normalized ApiException with ApiErrorType classification |

---

## Installation

Add `core_dio_client` to your `pubspec.yaml`:

```yaml
dependencies:
  core_dio_client: ^1.0.0
```

Fetch the package:

```bash
flutter pub get
```

Import it in your Dart code:

```dart
import 'package:core_dio_client/core_dio_client.dart';
```

---

## Quick Start

### 1. Initialize ApiClient

Configure the client once during application bootstrap (for example, in `main.dart`):

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

---

## Usage Scenarios

### Scenario 1: Standard Requests

```dart
final client = ApiClient.instance;

// GET Request with query parameters
final profileResponse = await client.get<Map<String, dynamic>>(
  url: '/users/profile',
  params: {'include_details': true},
);

if (profileResponse.success) {
  final data = profileResponse.data;
  print('User: ${data?['name']}');
} else {
  final error = profileResponse.error as ApiException;
  print('Error [${error.statusCode}]: ${error.message}');
}

// POST Request with JSON payload
final createResponse = await client.post<Map<String, dynamic>>(
  url: '/users',
  body: {
    'name': 'Alex Morgan',
    'email': 'alex@example.com',
  },
);
```

### Scenario 2: File Download with Progress Tracking

```dart
final response = await ApiClient.instance.downloadFile(
  url: 'https://example.com/assets/document.pdf',
  savePath: '/storage/documents/document.pdf',
  onReceiveProgress: (receivedBytes, totalBytes) {
    if (totalBytes > 0) {
      final percentage = (receivedBytes / totalBytes * 100).toStringAsFixed(0);
      print('Download: $percentage% ($receivedBytes / $totalBytes bytes)');
    }
  },
);

if (response.success) {
  print('Saved to: ${response.data}');
}
```

### Scenario 3: Single and Multi-File Multipart Uploads

#### Single File
```dart
final file = File('/storage/pictures/avatar.jpg');

final response = await ApiClient.instance.uploadFile<Map<String, dynamic>>(
  url: '/users/avatar',
  file: file,
  fileKey: 'avatar',
  data: {'description': 'Profile picture'},
  onSendProgress: (sentBytes, totalBytes) {
    if (totalBytes > 0) {
      final percentage = (sentBytes / totalBytes * 100).toStringAsFixed(0);
      print('Upload progress: $percentage%');
    }
  },
);
```

#### Multiple Files
```dart
final files = [
  File('/storage/invoices/inv_01.pdf'),
  File('/storage/invoices/inv_02.pdf'),
];

final response = await ApiClient.instance.uploadFiles<Map<String, dynamic>>(
  url: '/invoices/batch',
  files: files,
  fileKey: 'documents',
  data: {'fiscal_year': 2026},
  onSendProgress: (sent, total) {
    print('Batch upload: $sent / $total bytes');
  },
);
```

### Scenario 4: Request Cancellation

Use `CancelToken` to abort long-running requests when a screen is closed or when the user navigates away:

```dart
final cancelToken = ApiClient.createCancelToken();

// Initiate request
final requestFuture = ApiClient.instance.get<dynamic>(
  url: '/reports/large-export',
  cancelToken: cancelToken,
);

// Cancel when needed
void onUserCancelled() {
  cancelToken.cancel('User aborted operation');
}

final response = await requestFuture;
if (!response.success) {
  final error = response.error as ApiException;
  if (error.type == ApiErrorType.cancelled) {
    print('Operation was cancelled.');
  }
}
```

### Scenario 5: Pre-Flight Offline Connectivity Check

Avoid unnecessary request timeouts by verifying network reachability before dispatching requests:

```dart
ApiClient.initialize(
  config: NetworkConfig(
    baseUrl: 'https://api.example.com',
    connectivityChecker: () async {
      // Connect to your favorite network status library
      return await internetChecker.hasConnection;
    },
  ),
);
```

If the callback returns `false`, `ApiClient` throws an `ApiException` with `ApiErrorType.network` immediately without executing network calls.

### Scenario 6: Synchronized 401 Token Refresh

When multiple requests encounter a 401 Unauthorized status simultaneously, `ApiClient` queues the requests, executes a single token refresh call, and replays all pending requests with the refreshed token:

```dart
ApiClient.initialize(
  config: const NetworkConfig(baseUrl: 'https://api.example.com'),
  tokenProvider: () async => await storage.read(key: 'access_token'),
  refreshTokenHandler: (refreshDio) async {
    final currentRefreshToken = await storage.read(key: 'refresh_token');
    try {
      final res = await refreshDio.post(
        '/auth/token/refresh',
        data: {'refresh_token': currentRefreshToken},
      );
      final newAccessToken = res.data['access_token'];
      await storage.write(key: 'access_token', value: newAccessToken);
      return true;
    } catch (_) {
      // Return false if refresh token has expired
      return false;
    }
  },
);
```

### Scenario 7: Structured Logging with Sensitive Data Redaction

Headers containing authentication tokens or cookies are automatically masked with `<REDACTED>`:

```dart
ApiClient.initialize(
  config: const NetworkConfig(baseUrl: 'https://api.example.com'),
  enableLogging: true,
  logPrint: (logLine) {
    // Pipe directly to your production logger or Crashlytics
    debugPrint(logLine);
  },
);
```

---

## Configuration Reference

### NetworkConfig

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `baseUrl` | `String` | Required | Target API base URL |
| `defaultHeaders` | `Map<String, String>` | `{}` | Headers attached to every outgoing request |
| `timeout` | `Duration` | `30s` | Connect, receive, and send timeout duration |
| `maxRetries` | `int` | `2` | Number of exponential backoff retry attempts |
| `connectivityChecker` | `Future<bool> Function()?` | `null` | Pre-flight internet reachability hook |

### ApiErrorType

| Enum Value | Description |
| :--- | :--- |
| `network` | No internet connection, host lookup failure, or socket failure |
| `timeout` | Connection, send, or receive timeout exceeded |
| `cancelled` | Request cancelled via CancelToken |
| `server` | HTTP response status 500 through 599 |
| `client` | HTTP response status 400 through 499 (excluding handled 401) |
| `parse` | Data parsing or JSON decoding failure |
| `unknown` | Unclassified exception |

---

## Repository and Support

- GitHub Repository: [https://github.com/harmish66/core_dio_client](https://github.com/harmish66/core_dio_client)
- Issue Tracker: [https://github.com/harmish66/core_dio_client/issues](https://github.com/harmish66/core_dio_client/issues)
- Package Registry: [https://pub.dev/packages/core_dio_client](https://pub.dev/packages/core_dio_client)

---

## License

MIT License. See [LICENSE](https://github.com/harmish66/core_dio_client/blob/main/LICENSE) for full details.
