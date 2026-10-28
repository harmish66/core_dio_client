import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:core_dio_client/core/network/interceptors/auth_interceptor.dart';

void main() {
  test('AuthInterceptor adds Authorization header when token present', () async {
    final interceptor = AuthInterceptor(() async => 'abc123');
    final options = RequestOptions(path: '/');
    final handler = RequestInterceptorHandler();

    interceptor.onRequest(options, handler);
    // onRequest may complete asynchronously; allow microtask queue to run
    await Future.delayed(Duration.zero);

    expect(options.headers['Authorization'], 'Bearer abc123');
  });

  test('AuthInterceptor leaves headers unchanged when no token', () async {
    final interceptor = AuthInterceptor(() async => null);
    final options = RequestOptions(path: '/');
    final handler = RequestInterceptorHandler();

    interceptor.onRequest(options, handler);
    await Future.delayed(Duration.zero);

    expect(options.headers.containsKey('Authorization'), isFalse);
  });
}
