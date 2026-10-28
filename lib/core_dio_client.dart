// Public exports for the core_dio_client package.
export 'core/network/api_client.dart';
export 'core/network/network_config.dart';
export 'core/network/interceptors/auth_interceptor.dart';
export 'core/network/interceptors/logging_interceptor.dart';
export 'core/network/interceptors/retry_interceptor.dart';
export 'core/models/api_response.dart';
export 'core/exceptions/api_exception.dart';
export 'data/repositories/api_repository.dart';
export 'data/sources/api_service.dart';

// Re-export essential Dio types so consumers don't need direct Dio dependency
export 'package:dio/dio.dart' show CancelToken, ProgressCallback, FormData, MultipartFile, Options;
