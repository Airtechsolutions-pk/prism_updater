import 'package:flutter_test/flutter_test.dart';
import 'package:prism_updater/src/update_policy.dart';
import 'package:prism_updater/src/version.dart';

void main() {
  group('UpdatePolicy.evaluate', () {
    test('returns upToDate when current equals latest', () {
      const policy = UpdatePolicy();
      final result = policy.evaluate(
        PrismVersion.parse('2.1.0'),
        {UpdateChannel.stable: PrismVersion.parse('2.1.0')},
      );
      expect(result.decision, UpdateDecision.upToDate);
      expect(result.isUpdateAvailable, isFalse);
    });

    test('returns softUpdate when a newer version exists', () {
      const policy = UpdatePolicy();
      final result = policy.evaluate(
        PrismVersion.parse('2.0.0'),
        {UpdateChannel.stable: PrismVersion.parse('2.1.0')},
      );
      expect(result.decision, UpdateDecision.softUpdate);
      expect(result.latest, PrismVersion.parse('2.1.0'));
    });

    test('returns forcedUpdate below minimum', () {
      final policy = UpdatePolicy(minimumVersion: PrismVersion.parse('1.9.0'));
      final result = policy.evaluate(
        PrismVersion.parse('1.8.2'),
        {UpdateChannel.stable: PrismVersion.parse('2.1.0')},
      );
      expect(result.decision, UpdateDecision.forcedUpdate);
      expect(result.isForced, isTrue);
    });

    test('forcedUpdate wins even when latest equals current', () {
      final policy = UpdatePolicy(minimumVersion: PrismVersion.parse('2.0.0'));
      final result = policy.evaluate(
        PrismVersion.parse('1.5.0'),
        {UpdateChannel.stable: PrismVersion.parse('1.5.0')},
      );
      expect(result.decision, UpdateDecision.forcedUpdate);
    });

    test('resolves latest across enabled channels', () {
      const policy = UpdatePolicy(channels: {UpdateChannel.stable});
      final result = policy.evaluate(
        PrismVersion.parse('1.0.0'),
        {
          UpdateChannel.stable: PrismVersion.parse('2.0.0'),
          UpdateChannel.beta: PrismVersion.parse('3.0.0'),
        },
      );
      // Beta channel is not enabled, so latest is 2.0.0.
      expect(result.latest, PrismVersion.parse('2.0.0'));
    });

    test('returns upToDate when no channel data is available', () {
      const policy = UpdatePolicy();
      final result = policy.evaluate(
        PrismVersion.parse('1.0.0'),
        const {},
      );
      expect(result.decision, UpdateDecision.upToDate);
    });

    test('fromJson parses latest and minimum maps', () {
      final policy = UpdatePolicy.fromJson({
        'latest': {'stable': '2.1.0', 'beta': '2.2.0'},
        'minimum': {'stable': '1.9.0'},
      });
      expect(policy.channels, {UpdateChannel.stable, UpdateChannel.beta});
      final result = policy.evaluate(
        PrismVersion.parse('1.0.0'),
        {
          UpdateChannel.stable: PrismVersion.parse('2.1.0'),
          UpdateChannel.beta: PrismVersion.parse('2.2.0'),
        },
      );
      expect(result.decision, UpdateDecision.forcedUpdate);
    });
  });
}
