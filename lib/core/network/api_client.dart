// ApiClient: a singleton wrapper around Dio providing typed request methods,
// interceptors, timeout, retry, file upload, download, and cancellation support.
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import '../models/api_response.dart';
import '../exceptions/api_exception.dart';
import 'network_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

// ApiClient is a configurable singleton. Call [initialize] before use.
class ApiClient {
  static ApiClient? _instance;

  final Dio _dio;
  // Optional global error callback
  final void Function(ApiException)? _onErrorCallback;
  // Simple broadcast stream for errors
  Stream<ApiException>? _errorStream;

  final Future<bool> Function(Dio)? _refreshTokenHandler;
  final Future<bool> Function()? _connectivityChecker;
  Completer<bool>? _refreshCompleter;

  ApiClient._(
    this._dio, {
    void Function(ApiException)? onError,
    Future<bool> Function(Dio)? refreshTokenHandler,
    Future<bool> Function()? connectivityChecker,
  })  : _onErrorCallback = onError,
        _refreshTokenHandler = refreshTokenHandler,
        _connectivityChecker = connectivityChecker {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (err, handler) async {
        try {
          final status = err.response?.statusCode;
          if (status == 401 && _refreshTokenHandler != null) {
            final options = err.requestOptions;
            final alreadyRetried = options.extra['retried_with_refresh'] as bool? ?? false;
            if (!alreadyRetried) {
              if (_refreshCompleter != null) {
                try {
                  await _refreshCompleter!.future;
                } on Exception catch (_) {
                  // Ignore
                }
              } else {
                _refreshCompleter = Completer<bool>();
                final localCompleter = _refreshCompleter;
                try {
                  final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
                  final refreshHandler = _refreshTokenHandler;
                  final refreshed = await refreshHandler(refreshDio);
                  localCompleter?.complete(refreshed);
                } catch (e) {
                  localCompleter?.complete(false);
                }
                _refreshCompleter = null;
              }

              final opts = err.requestOptions;
              opts.extra['retried_with_refresh'] = true;
              opts.headers.remove('Authorization');
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } on Exception catch (_) {
                // Ignore
              }
            }
          }
        } on Exception catch (_) {
          // Ignore
        }

        final apiEx = ApiException.fromDio(err);
        if (_onErrorCallback != null) {
          try {
            _onErrorCallback(apiEx);
          } on Exception catch (_) {
            // Ignore
          }
        }
        handler.next(err);
      },
    ));
  }

  /// Internal constructor for testing.
  @visibleForTesting
  ApiClient.forTest(
    Dio dio, {
    Future<bool> Function(Dio)? refreshTokenHandler,
    void Function(ApiException)? onError,
    Future<bool> Function()? connectivityChecker,
  })  : _dio = dio,
        _onErrorCallback = onError,
        _refreshTokenHandler = refreshTokenHandler,
        _connectivityChecker = connectivityChecker {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (err, handler) async {
        try {
          final status = err.response?.statusCode;
          if (status == 401 && _refreshTokenHandler != null) {
            final options = err.requestOptions;
            final alreadyRetried = options.extra['retried_with_refresh'] as bool? ?? false;
            if (!alreadyRetried) {
              if (_refreshCompleter != null) {
                try {
                  await _refreshCompleter!.future;
                } on Exception catch (_) {
                  // Ignore
                }
              } else {
                _refreshCompleter = Completer<bool>();
                final localCompleter = _refreshCompleter;
                try {
                  final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
                  final refreshHandler = _refreshTokenHandler;
                  final refreshed = await refreshHandler(refreshDio);
                  localCompleter?.complete(refreshed);
                } catch (e) {
                  localCompleter?.complete(false);
                }
                _refreshCompleter = null;
              }

              final opts = err.requestOptions;
              opts.extra['retried_with_refresh'] = true;
              opts.headers.remove('Authorization');
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } on Exception catch (_) {
                // Ignore
              }
            }
          }
        } on Exception catch (_) {
          // Ignore
        }

        final apiEx = ApiException.fromDio(err);
        if (_onErrorCallback != null) {
          try {
            _onErrorCallback(apiEx);
          } on Exception catch (_) {
            // Ignore
          }
        }
        handler.next(err);
      },
    ));
  }

  /// Initialize the singleton client. Call this once at app startup.
  static void initialize({
    required NetworkConfig config,
    TokenProvider? tokenProvider,
    bool enableLogging = false,
    void Function(ApiException)? onError,
    Future<bool> Function(Dio)? refreshTokenHandler,
    Future<bool> Function()? connectivityChecker,
    void Function(String line)? logPrint,
  }) {
    final dio = Dio(BaseOptions(baseUrl: config.baseUrl, headers: config.defaultHeaders));
    dio.options.connectTimeout = config.timeout;
    dio.options.receiveTimeout = config.timeout;
    dio.options.sendTimeout = config.timeout;

    if (tokenProvider != null) {
      dio.interceptors.add(AuthInterceptor(tokenProvider));
    }
    dio.interceptors.add(LoggingInterceptor(enabled: enableLogging, logPrint: logPrint));
    dio.interceptors.add(RetryInterceptor(dio: dio, maxRetries: config.maxRetries));

    _instance = ApiClient._(
      dio,
      onError: onError,
      refreshTokenHandler: refreshTokenHandler,
      connectivityChecker: connectivityChecker ?? config.connectivityChecker,
    );
  }

  /// Access the singleton instance.
  static ApiClient get instance {
    if (_instance == null) {
      throw StateError('ApiClient not initialized. Call ApiClient.initialize(...) first.');
    }
    return _instance!;
  }

  /// Reset the singleton instance (mainly for testing or user logout).
  static void reset() {
    _instance = null;
  }

  /// Helper to create a new CancelToken.
  static CancelToken createCancelToken() => CancelToken();

  Dio get dio => _dio;

  Stream<ApiException> get errorStream {
    _errorStream ??= (() {
      final controller = StreamController<ApiException>.broadcast();
      _dio.interceptors.add(InterceptorsWrapper(
        onError: (err, handler) {
          try {
            final apiEx = ApiException.fromDio(err);
            controller.add(apiEx);
          } on Exception catch (_) {
            // Ignore
          }
          handler.next(err);
        },
      ));
      return controller.stream;
    })();
    return _errorStream!;
  }

  Future<void> _assertConnectivity() async {
    final checker = _connectivityChecker;
    if (checker != null) {
      final hasConnection = await checker();
      if (!hasConnection) {
        throw ApiException('No internet connection', type: ApiErrorType.network);
      }
    }
  }

  /// Perform a GET request.
  Future<ApiResponse<T>> get<T>({
    required String url,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      await _assertConnectivity();
      final response = await _dio.get(
        url,
        queryParameters: params,
        options: Options(headers: headers),
        cancelToken: cancelToken,
      );
      return ApiResponse.success(response.data as T);
    } on DioException catch (e) {
      return ApiResponse.failure(ApiException.fromDio(e));
    } on ApiException catch (e) {
      return ApiResponse.failure(e);
    } catch (e) {
      return ApiResponse.failure(ApiException(e.toString()));
    }
  }

  /// POST request with optional body, query parameters, progress callbacks, and cancel token.
  Future<ApiResponse<T>> post<T>({
    required String url,
    dynamic body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await _assertConnectivity();
      dynamic data = body;
      final options = Options(headers: headers);

      // Handle automatic File upload if body contains File instances
      if (body is Map<String, dynamic>) {
        bool hasFile = false;
        final map = <String, dynamic>{};
        for (final entry in body.entries) {
          if (entry.value is File) {
            hasFile = true;
            final file = entry.value as File;
            map[entry.key] = await MultipartFile.fromFile(
              file.path,
              filename: file.path.split(Platform.pathSeparator).last,
            );
          } else {
            map[entry.key] = entry.value;
          }
        }
        if (hasFile) {
          data = FormData.fromMap(map);
          options.contentType = 'multipart/form-data';
        }
      }

      final response = await _dio.post(
        url,
        data: data,
        queryParameters: params,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return ApiResponse.success(response.data as T);
    } on DioException catch (e) {
      return ApiResponse.failure(ApiException.fromDio(e));
    } on ApiException catch (e) {
      return ApiResponse.failure(e);
    } catch (e) {
      return ApiResponse.failure(ApiException(e.toString()));
    }
  }

  /// PUT request.
  Future<ApiResponse<T>> put<T>({
    required String url,
    dynamic body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await _assertConnectivity();
      final response = await _dio.put(
        url,
        data: body,
        queryParameters: params,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return ApiResponse.success(response.data as T);
    } on DioException catch (e) {
      return ApiResponse.failure(ApiException.fromDio(e));
    } on ApiException catch (e) {
      return ApiResponse.failure(e);
    } catch (e) {
      return ApiResponse.failure(ApiException(e.toString()));
    }
  }

  /// DELETE request.
  Future<ApiResponse<T>> delete<T>({
    required String url,
    dynamic body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      await _assertConnectivity();
      final response = await _dio.delete(
        url,
        data: body,
        queryParameters: params,
        options: Options(headers: headers),
        cancelToken: cancelToken,
      );
      return ApiResponse.success(response.data as T);
    } on DioException catch (e) {
      return ApiResponse.failure(ApiException.fromDio(e));
    } on ApiException catch (e) {
      return ApiResponse.failure(e);
    } catch (e) {
      return ApiResponse.failure(ApiException(e.toString()));
    }
  }

  /// PATCH request.
  Future<ApiResponse<T>> patch<T>({
    required String url,
    dynamic body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await _assertConnectivity();
      final response = await _dio.patch(
        url,
        data: body,
        queryParameters: params,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return ApiResponse.success(response.data as T);
    } on DioException catch (e) {
      return ApiResponse.failure(ApiException.fromDio(e));
    } on ApiException catch (e) {
      return ApiResponse.failure(e);
    } catch (e) {
      return ApiResponse.failure(ApiException(e.toString()));
    }
  }

  /// Download a file to disk with progress callback and cancel token support.
  Future<ApiResponse<String>> downloadFile({
    required String url,
    required String savePath,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    bool deleteOnError = true,
  }) async {
    try {
      await _assertConnectivity();
      final response = await _dio.download(
        url,
        savePath,
        queryParameters: params,
        options: Options(headers: headers),
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
      );
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return ApiResponse.success(savePath);
      }
      return ApiResponse.failure(
        ApiException(
          'Failed to download file: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          type: ApiErrorType.server,
        ),
      );
    } on DioException catch (e) {
      return ApiResponse.failure(ApiException.fromDio(e));
    } on ApiException catch (e) {
      return ApiResponse.failure(e);
    } catch (e) {
      return ApiResponse.failure(ApiException(e.toString()));
    }
  }

  /// Upload a single file with optional extra form data, upload progress, and cancel token.
  Future<ApiResponse<T>> uploadFile<T>({
    required String url,
    required File file,
    String fileKey = 'file',
    String? filename,
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) async {
    try {
      await _assertConnectivity();
      final actualFilename = filename ?? file.path.split(Platform.pathSeparator).last;
      final multipartFile = await MultipartFile.fromFile(file.path, filename: actualFilename);

      final map = <String, dynamic>{
        fileKey: multipartFile,
      };
      if (data != null) {
        map.addAll(data);
      }

      final formData = FormData.fromMap(map);
      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: headers,
          contentType: 'multipart/form-data',
        ),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
      return ApiResponse.success(response.data as T);
    } on DioException catch (e) {
      return ApiResponse.failure(ApiException.fromDio(e));
    } on ApiException catch (e) {
      return ApiResponse.failure(e);
    } catch (e) {
      return ApiResponse.failure(ApiException(e.toString()));
    }
  }

  /// Upload multiple files with progress tracking and cancel token.
  Future<ApiResponse<T>> uploadFiles<T>({
    required String url,
    required List<File> files,
    String fileKey = 'files',
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) async {
    try {
      await _assertConnectivity();
      final multipartFiles = <MultipartFile>[];
      for (final f in files) {
        final filename = f.path.split(Platform.pathSeparator).last;
        multipartFiles.add(await MultipartFile.fromFile(f.path, filename: filename));
      }

      final map = <String, dynamic>{
        fileKey: multipartFiles,
      };
      if (data != null) {
        map.addAll(data);
      }

      final formData = FormData.fromMap(map);
      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: headers,
          contentType: 'multipart/form-data',
        ),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
      return ApiResponse.success(response.data as T);
    } on DioException catch (e) {
      return ApiResponse.failure(ApiException.fromDio(e));
    } on ApiException catch (e) {
      return ApiResponse.failure(e);
    } catch (e) {
      return ApiResponse.failure(ApiException(e.toString()));
    }
  }
}
