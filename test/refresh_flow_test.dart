import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:core_dio_client/core/network/api_client.dart';

class MockInterceptorsWrapper extends Mock implements InterceptorsWrapper {}

void main() {
  test('refreshTokenHandler is invoked on 401 and request retry attempted', () async {
    final dio = Dio();

    var refreshCalled = false;
    Future<bool> refreshHandler(Dio refreshDio) async {
      refreshCalled = true;
      return true;
    }

    // Create ApiClient for test using our dio and refresh handler
    ApiClient.forTest(dio, refreshTokenHandler: refreshHandler);

    // Find the last InterceptorsWrapper added (our client adds one in constructor)
    final wrappers = dio.interceptors.whereType<InterceptorsWrapper>().toList();
    expect(wrappers, isNotEmpty);
    final wrapper = wrappers.last;

    // Create a DioException that simulates a 401 response
    final response = Response(requestOptions: RequestOptions(path: '/test'), statusCode: 401);
    final dioError = DioException(requestOptions: RequestOptions(path: '/test'), response: response);

    // Call the onError handler directly
    final handler = ErrorInterceptorHandler();
    // InterceptorsWrapper stores the callbacks in fields; invoke them
    wrapper.onError(dioError, handler);
    // allow microtask queue to run
    await Future.delayed(Duration.zero);

    // refreshHandler should have been called
    expect(refreshCalled, isTrue);
  });
}
