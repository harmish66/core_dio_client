// ApiService: a thin data source layer over ApiClient. Keeps separation of concerns.
import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/models/api_response.dart';
import '../../core/network/api_client.dart';

class ApiService {
  final ApiClient client;

  ApiService({required this.client});

  Future<ApiResponse<T>> get<T>({
    required String url,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return client.get<T>(
      url: url,
      params: params,
      headers: headers,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<T>> post<T>({
    required String url,
    dynamic body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return client.post<T>(
      url: url,
      body: body,
      params: params,
      headers: headers,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<ApiResponse<T>> put<T>({
    required String url,
    dynamic body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return client.put<T>(
      url: url,
      body: body,
      params: params,
      headers: headers,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<ApiResponse<T>> patch<T>({
    required String url,
    dynamic body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return client.patch<T>(
      url: url,
      body: body,
      params: params,
      headers: headers,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<ApiResponse<T>> delete<T>({
    required String url,
    dynamic body,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return client.delete<T>(
      url: url,
      body: body,
      params: params,
      headers: headers,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<String>> downloadFile({
    required String url,
    required String savePath,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
    bool deleteOnError = true,
  }) {
    return client.downloadFile(
      url: url,
      savePath: savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      params: params,
      headers: headers,
      deleteOnError: deleteOnError,
    );
  }

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
  }) {
    return client.uploadFile<T>(
      url: url,
      file: file,
      fileKey: fileKey,
      filename: filename,
      data: data,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      headers: headers,
    );
  }
}
