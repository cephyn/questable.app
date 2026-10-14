import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quest_cards/src/services/google_pse_client.dart';

void main() {
  const apiKey = 'AIzaSyTestSecretKey123';

  test('search errors do not expose the API key', () async {
    final httpClient = MockClient((request) async {
      throw http.ClientException('Connection refused', request.url);
    });
    final client = GooglePSEClient(
      apiKey: apiKey,
      searchEngineId: 'test-cx',
      httpClient: httpClient,
    );

    await expectLater(
      client.search('dungeon quest'),
      throwsA(
        predicate(
          (e) =>
              !e.toString().contains(apiKey) &&
              e.toString().contains('[REDACTED]'),
        ),
      ),
    );
  });
}
