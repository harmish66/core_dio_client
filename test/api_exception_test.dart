import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:core_dio_client/core/exceptions/api_exception.dart';

void main() {
  test('ApiException.fromDio maps response and message', () {
    final response = Response(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: 400,
      statusMessage: 'Bad Request',
      data: {'message': 'Invalid input'},
    );

    final dioError = DioException(requestOptions: RequestOptions(path: '/test'), response: response);
    final ex = ApiException.fromDio(dioError);

    expect(ex.statusCode, 400);
    expect(ex.message, 'Invalid input');
  });

  test('ApiException.fromDio handles timeout', () {
    final dioError = DioException(requestOptions: RequestOptions(path: '/timeout'), type: DioExceptionType.connectionTimeout, message: 'connect timeout');
    final ex = ApiException.fromDio(dioError);
    expect(ex.message.toLowerCase(), contains('timed out'));
  });
}
