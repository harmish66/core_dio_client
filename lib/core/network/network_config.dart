/// Network configuration for ApiClient.
class NetworkConfig {
  /// Base URL of the API (e.g. https://api.example.com)
  final String baseUrl;

  /// Default headers applied to every request
  final Map<String, String> defaultHeaders;

  /// Request timeout
  final Duration timeout;

  /// Number of automatic retry attempts for transient failures
  final int maxRetries;

  /// Optional connectivity checker callback.
  /// If provided and returns false, requests fail fast with network error.
  final Future<bool> Function()? connectivityChecker;

  const NetworkConfig({
    required this.baseUrl,
    this.defaultHeaders = const {},
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 2,
    this.connectivityChecker,
  });
}
