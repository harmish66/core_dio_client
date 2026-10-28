## 1.0.0

* Initial release under `core_dio_client`.
* Complete Dio wrapper providing singleton access and typed HTTP operations (GET, POST, PUT, DELETE, PATCH).
* Added `downloadFile` method with real-time `onReceiveProgress` tracking.
* Added `uploadFile` and `uploadFiles` multipart helpers with `onSendProgress` tracking.
* Added `CancelToken` integration across all HTTP methods for request cancellation.
* Added `connectivityChecker` pre-flight callback in `NetworkConfig` to fail fast when offline.
* Thread-safe 401 token refresh queue and retry flow via `refreshTokenHandler`.
* Exponential backoff retry interceptor with jitter for network errors and 5xx responses.
* Configurable, structured logging interceptor with sensitive header redaction and body truncation.
* Standardized `ApiResponse<T>` wrapper and categorized `ApiException` error handling.
