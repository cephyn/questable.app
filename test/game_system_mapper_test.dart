import 'package:flutter_test/flutter_test.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:quest_cards/src/services/game_system_mapper.dart';
import 'package:quest_cards/src/services/game_system_service.dart';

class FakeGameSystemLookupService implements GameSystemLookupService {
  final Map<String, StandardGameSystem?> exactMatches = {};
  List<StandardGameSystem> allSystems = [];
  StandardGameSystem? lastUpdatedSystem;

  @override
  Future<StandardGameSystem?> findGameSystemByName(String name) async {
    return exactMatches[name];
  }

  @override
  Future<List<StandardGameSystem>> getAllGameSystems() async {
    return allSystems;
  }

  @override
  Future<void> updateGameSystem(StandardGameSystem gameSystem) async {
    lastUpdatedSystem = gameSystem;
  }
}

void main() {
  late GameSystemMapper mapper;
  late FakeGameSystemLookupService fakeGameSystemService;

  setUp(() {
    fakeGameSystemService = FakeGameSystemLookupService();
    mapper = GameSystemMapper(gameSystemService: fakeGameSystemService);
  });

  group('GameSystemMapper', () {
    test('findBestMatch returns exact match with confidence 1.0', () async {
      // Arrange
      final testSystem = StandardGameSystem(
        id: '1',
        standardName: 'Dungeons & Dragons',
        aliases: ['D&D', 'DnD'],
      );
      fakeGameSystemService.exactMatches['dungeons & dragons'] = testSystem;

      // Act
      final result = await mapper.findBestMatch('Dungeons & Dragons');

      // Assert
      expect(result.system, equals(testSystem));
      expect(result.confidence, equals(1.0));
      expect(result.matchType, equals('exact'));
      expect(result.isExactMatch, isTrue);
    });

    test('findBestMatch returns null for empty input', () async {
      // Act
      final result = await mapper.findBestMatch('');

      // Assert
      expect(result.system, isNull);
      expect(result.confidence, equals(0.0));
      expect(result.matchType, equals('empty'));
    });

    test('findBestMatch finds fuzzy match for similar name', () async {
      // Arrange
      final testSystems = [
        StandardGameSystem(
          id: '1',
          standardName: 'Dungeons & Dragons',
          aliases: ['D&D'],
        ),
        StandardGameSystem(id: '2', standardName: 'Pathfinder', aliases: []),
      ];
      fakeGameSystemService.exactMatches['dungeon and dragons'] = null;
      fakeGameSystemService.allSystems = testSystems;

      // Act
      final result = await mapper.findBestMatch('dungeon and dragons');

      // Assert
      expect(result.system?.id, equals('1'));
      expect(result.confidence, greaterThan(0.7));
      expect(result.matchType, contains('similarity'));
    });

    test('findBestMatch identifies acronym matches', () async {
      // Arrange
      final testSystems = [
        StandardGameSystem(
          id: '1',
          standardName: 'Dungeons & Dragons',
          aliases: [],
        ),
      ];
      fakeGameSystemService.exactMatches['d&d'] = null;
      fakeGameSystemService.allSystems = testSystems;

      // Act
      final result = await mapper.findBestMatch('D&D');

      // Assert
      expect(result.system?.id, equals('1'));
      expect(result.confidence, greaterThan(0.8));
      expect(result.matchType, contains('acronym'));
    });
  });
}
