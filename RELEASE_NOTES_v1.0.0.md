# Release Notes - core_dio_client v1.0.0

## Highlights

- Stable initial release of core_dio_client.
- Production-ready Dio wrapper for Flutter and Dart applications.
- Features: ApiClient singleton, GET/POST/PUT/DELETE/PATCH, download with progress, single and multi-file uploads with progress, request cancellation with CancelToken, offline pre-flight connectivity check, auth token refresh queue, exponential backoff retry, and structured logging.

## Detailed Changelog

- feat(download): added downloadFile method with real-time onReceiveProgress callback and savePath destination.
- feat(upload): added uploadFile and uploadFiles multipart helpers with onSendProgress tracking.
- feat(cancellation): integrated CancelToken support across all HTTP methods.
- feat(connectivity): added connectivityChecker callback to fail fast when offline.
- feat(auth): thread-safe 401 token refresh queue to eliminate race conditions.
- feat(retry): exponential backoff with randomized jitter on network errors and 5xx status codes.
- feat(logging): pretty-printed request/response logs with sensitive header redaction and body truncation.
- feat(errors): structured ApiResponse<T> wrapper and ApiErrorType classification.
- test: added test suite covering download, upload, cancellation, retry, and auth refresh flows.

## Usage

Add to your pubspec.yaml:

```yaml
dependencies:
  core_dio_client: ^1.0.0
```

Or via Git:

```yaml
dependencies:
  core_dio_client:
    git:
      url: https://github.com/harmish66/core_dio_client.git
      ref: v1.0.0
```
