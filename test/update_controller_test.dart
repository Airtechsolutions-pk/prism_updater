import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prism_updater/src/update_controller.dart';
import 'package:prism_updater/src/update_platform.dart';
import 'package:prism_updater/src/update_policy.dart';
import 'package:prism_updater/src/update_source.dart';
import 'package:prism_updater/src/version.dart';

PrismUpdatePlatformInfo fakePlatform({bool web = false}) =>
    PrismUpdatePlatformInfo(
      isWeb: web,
      isAndroid: !web,
      isIOS: false,
      isWindows: false,
      isMacOS: false,
      isLinux: false,
    );

void main() {
  group('StaticUpdateSource', () {
    test('returns the fixed map', () async {
      final source = StaticUpdateSource({
        UpdateChannel.stable: PrismVersion.parse('3.0.0'),
      });
      expect(
        await source.fetchLatest(),
        {UpdateChannel.stable: PrismVersion.parse('3.0.0')},
      );
    });
  });

  group('RemoteUpdateSource', () {
    test('fetches and parses latest versions', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'latest': {'stable': '2.1.0', 'beta': '2.2.0'},
          }),
          200,
        ),
      );
      final source = RemoteUpdateSource(
        url: Uri.parse('https://example.com/updates.json'),
        client: client,
      );
      final latest = await source.fetchLatest();
      expect(latest[UpdateChannel.stable], PrismVersion.parse('2.1.0'));
      expect(latest[UpdateChannel.beta], PrismVersion.parse('2.2.0'));
    });

    test('exposes download url per platform and notes', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'latest': {'stable': '2.1.0'},
            'urls': {'windows': 'https://example.com/app.exe'},
            'notes': {'2.1.0': 'Bug fixes'},
          }),
          200,
        ),
      );
      final source = RemoteUpdateSource(
        url: Uri.parse('https://example.com/updates.json'),
        client: client,
      );
      await source.fetchLatest();
      expect(
        source.downloadUrlFor('windows'),
        Uri.parse('https://example.com/app.exe'),
      );
      expect(
        source.notesFor(PrismVersion.parse('2.1.0')),
        'Bug fixes',
      );
      expect(source.minimumVersion, isNull);
    });

    test('throws on non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('oops', 500),
      );
      final source = RemoteUpdateSource(
        url: Uri.parse('https://example.com/updates.json'),
        client: client,
      );
      await expectLater(source.fetchLatest(), throwsA(isA<http.ClientException>()));
    });
  });

  group('PrismUpdateController', () {
    test('starts checking immediately and emits available', () async {
      final controller = PrismUpdateController(
        source: StaticUpdateSource({
          UpdateChannel.stable: PrismVersion.parse('2.0.0'),
        }),
        currentVersion: PrismVersion.parse('1.0.0'),
        platformInfo: fakePlatform(),
        autoCheck: false,
      );
      await controller.checkNow();
      final state = controller.state;
      expect(state, isA<PrismUpdateAvailable>());
      final available = state as PrismUpdateAvailable;
      expect(available.isForced, isFalse);
      expect(available.latest, PrismVersion.parse('2.0.0'));
      controller.dispose();
    });

    test('emits upToDate when current is latest', () async {
      final controller = PrismUpdateController(
        source: StaticUpdateSource({
          UpdateChannel.stable: PrismVersion.parse('1.0.0'),
        }),
        currentVersion: PrismVersion.parse('1.0.0'),
        platformInfo: fakePlatform(),
        autoCheck: false,
      );
      await controller.checkNow();
      expect(controller.state, isA<PrismUpdateUpToDate>());
      controller.dispose();
    });

    test('emits forced state below minimum version', () async {
      final controller = PrismUpdateController(
        source: StaticUpdateSource({
          UpdateChannel.stable: PrismVersion.parse('2.0.0'),
        }),
        policy: UpdatePolicy(minimumVersion: PrismVersion.parse('1.5.0')),
        currentVersion: PrismVersion.parse('1.0.0'),
        platformInfo: fakePlatform(),
        autoCheck: false,
      );
      await controller.checkNow();
      final state = controller.state as PrismUpdateAvailable;
      expect(state.isForced, isTrue);
      controller.dispose();
    });

    test('notifies listeners with each state transition', () async {
      final controller = PrismUpdateController(
        source: StaticUpdateSource({
          UpdateChannel.stable: PrismVersion.parse('2.0.0'),
        }),
        currentVersion: PrismVersion.parse('1.0.0'),
        platformInfo: fakePlatform(),
        autoCheck: false,
      );
      final states = <PrismUpdateState>[];
      controller.addListener(() => states.add(controller.state));
      await controller.checkNow();
      expect(states.first, isA<PrismUpdateChecking>());
      expect(states.last, isA<PrismUpdateAvailable>());
      controller.dispose();
    });

    test('emits failure when the source throws', () async {
      final controller = PrismUpdateController(
        source: _ThrowingSource(),
        currentVersion: PrismVersion.parse('1.0.0'),
        platformInfo: fakePlatform(),
        autoCheck: false,
      );
      await controller.checkNow();
      expect(controller.state, isA<PrismUpdateFailure>());
      controller.dispose();
    });
  });
}

class _ThrowingSource implements PrismUpdateSource {
  @override
  Future<Map<UpdateChannel, PrismVersion>> fetchLatest() async {
    throw Exception('network down');
  }
}
