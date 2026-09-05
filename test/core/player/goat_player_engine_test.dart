import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/player/engine/player_engine_factory.dart';
import 'package:goat_player/core/player/engine/tizen_player_engine.dart';
import 'package:goat_player/core/player/engine/webos_player_engine.dart';
import 'package:goat_player/core/player/player_service.dart';

void main() {
  group('GoatPlayerEngine Abstraction Layer', () {
    test('TizenPlayerEngine opens, plays, pauses, seeks, and updates state correctly', () async {
      final engine = TizenPlayerEngine();
      expect(engine.state.playing, isFalse);
      expect(engine.state.isLive, isFalse);

      await engine.open('http://iptv.example/live/123.ts', isLive: true);
      expect(engine.state.lastOpenedUrl, 'http://iptv.example/live/123.ts');
      expect(engine.state.isLive, isTrue);
      expect(engine.state.playing, isTrue);

      await engine.pause();
      expect(engine.state.playing, isFalse);

      await engine.play();
      expect(engine.state.playing, isTrue);

      await engine.seek(const Duration(seconds: 45));
      expect(engine.state.position, const Duration(seconds: 45));

      await engine.setVolume(75.0);
      expect(engine.state.volume, 75.0);

      await engine.stop();
      expect(engine.state.playing, isFalse);
      expect(engine.state.position, Duration.zero);
      expect(engine.state.lastOpenedUrl, isNull);

      await engine.dispose();
    });

    test('WebOsPlayerEngine opens, plays, pauses, seeks, and updates state correctly', () async {
      final engine = WebOsPlayerEngine();
      expect(engine.state.playing, isFalse);

      await engine.open('http://iptv.example/movie/456.mp4', isLive: false, startPosition: const Duration(seconds: 120));
      expect(engine.state.lastOpenedUrl, 'http://iptv.example/movie/456.mp4');
      expect(engine.state.isLive, isFalse);
      expect(engine.state.playing, isTrue);

      await engine.pause();
      expect(engine.state.playing, isFalse);

      await engine.playOrPause();
      expect(engine.state.playing, isTrue);

      await engine.setVolume(50.0);
      expect(engine.state.volume, 50.0);

      await engine.stop();
      expect(engine.state.playing, isFalse);

      await engine.dispose();
    });

    test('PlayerEngineFactory supports mock engine injection', () {
      final mock = TizenPlayerEngine();
      PlayerEngineFactory.setMockEngine(mock);

      final engine = PlayerEngineFactory.create();
      expect(identical(engine, mock), isTrue);

      PlayerEngineFactory.setMockEngine(null);
    });

    test('PlayerService operates transparently over GoatPlayerEngine', () async {
      final mock = TizenPlayerEngine();
      final service = PlayerService(customEngine: mock);

      await service.open('http://iptv.example/series/789.mkv', isLive: false);
      expect(service.lastOpenedUrl, 'http://iptv.example/series/789.mkv');
      expect(service.engine.state.playing, isTrue);

      await service.pause();
      expect(service.engine.state.playing, isFalse);

      await service.play();
      expect(service.engine.state.playing, isTrue);

      await service.setVolume(80.0);
      expect(service.engine.state.volume, 80.0);

      await service.stop();
      expect(service.engine.state.playing, isFalse);

      await service.disposeAsync();
    });
  });
}
