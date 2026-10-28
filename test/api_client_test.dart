import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core_dio_client/core/network/api_client.dart';
import 'package:core_dio_client/data/sources/api_service.dart';
import 'package:core_dio_client/data/repositories/api_repository.dart';
import 'package:core_dio_client/core/models/api_response.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue([]);
    registerFallbackValue({});
  });

  test('ApiRepository.fetchItems returns list on success', () async {
    final mock = MockApiClient();

    when(() => mock.get<List<dynamic>>(
          url: '/items',
          params: any(named: 'params'),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => ApiResponse.success([{'id': 1, 'name': 'Item1'}]));

    final service = ApiService(client: mock);
    final repo = ApiRepository(service);

    final res = await repo.fetchItems();

    expect(res.success, isTrue);
    expect(res.data, isNotNull);
    expect(res.data!.length, 1);
  });
}
