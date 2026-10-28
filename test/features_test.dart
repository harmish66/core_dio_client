import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:core_dio_client/core_dio_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    mockDio = MockDio();
    when(() => mockDio.interceptors).thenReturn(Interceptors());
  });

  group('New Features in core_dio_client', () {
    test('downloadFile successfully saves file and reports progress', () async {
      when(() => mockDio.download(
            any(),
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            deleteOnError: any(named: 'deleteOnError'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          )).thenAnswer((invocation) async {
        final progress = invocation.namedArguments[#onReceiveProgress] as ProgressCallback?;
        progress?.call(50, 100);
        progress?.call(100, 100);
        return Response(
          requestOptions: RequestOptions(path: '/download'),
          statusCode: 200,
        );
      });

      final client = ApiClient.forTest(mockDio);
      int receivedBytes = 0;

      final res = await client.downloadFile(
        url: '/test.zip',
        savePath: '/tmp/test.zip',
        onReceiveProgress: (received, total) {
          receivedBytes = received;
        },
      );

      expect(res.success, isTrue);
      expect(res.data, '/tmp/test.zip');
      expect(receivedBytes, 100);
    });

    test('uploadFile sends multipart formData and reports progress', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onSendProgress: any(named: 'onSendProgress'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          )).thenAnswer((invocation) async {
        final progress = invocation.namedArguments[#onSendProgress] as ProgressCallback?;
        progress?.call(100, 100);
        return Response(
          requestOptions: RequestOptions(path: '/upload'),
          statusCode: 201,
          data: {'status': 'uploaded'},
        );
      });

      final client = ApiClient.forTest(mockDio);
      final tempFile = File('${Directory.systemTemp.path}/test_upload.txt');
      await tempFile.writeAsString('test upload content');

      int sentBytes = 0;
      final res = await client.uploadFile<Map<String, dynamic>>(
        url: '/upload',
        file: tempFile,
        onSendProgress: (sent, total) {
          sentBytes = sent;
        },
      );

      expect(res.success, isTrue);
      expect(res.data?['status'], 'uploaded');
      expect(sentBytes, 100);
    });

    test('uploadFiles handles multiple files in single request', () async {
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onSendProgress: any(named: 'onSendProgress'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          )).thenAnswer((_) async {
        return Response(
          requestOptions: RequestOptions(path: '/upload-multiple'),
          statusCode: 200,
          data: {'count': 2},
        );
      });

      final client = ApiClient.forTest(mockDio);
      final file1 = File('${Directory.systemTemp.path}/f1.txt')..writeAsStringSync('1');
      final file2 = File('${Directory.systemTemp.path}/f2.txt')..writeAsStringSync('2');

      final res = await client.uploadFiles<Map<String, dynamic>>(
        url: '/upload-multiple',
        files: [file1, file2],
      );

      expect(res.success, isTrue);
      expect(res.data?['count'], 2);
    });

    test('connectivityChecker prevents network calls when offline', () async {
      final client = ApiClient.forTest(
        mockDio,
        connectivityChecker: () async => false, // simulate offline
      );

      final res = await client.get<Map<String, dynamic>>(url: '/status');

      expect(res.success, isFalse);
      expect(res.error, isA<ApiException>());
      final error = res.error as ApiException;
      expect(error.type, ApiErrorType.network);
      expect(error.message, 'No internet connection');
      verifyNever(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')));
    });

    test('cancellation returns ApiErrorType.cancelled when request is aborted', () async {
      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/delayed'),
          type: DioExceptionType.cancel,
          message: 'Operation was cancelled',
        ),
      );

      final client = ApiClient.forTest(mockDio);
      final cancelToken = ApiClient.createCancelToken();

      final res = await client.get<dynamic>(url: '/delayed', cancelToken: cancelToken);

      expect(res.success, isFalse);
      final err = res.error as ApiException;
      expect(err.type, ApiErrorType.cancelled);
      expect(err.message, 'Request cancelled');
    });
  });
}
