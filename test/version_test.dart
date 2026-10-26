import 'package:flutter_test/flutter_test.dart';
import 'package:prism_updater/src/version.dart';

void main() {
  group('PrismVersion.parse', () {
    test('parses simple versions', () {
      final v = PrismVersion.parse('1.2.3');
      expect(v.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
      expect(v.toString(), '1.2.3');
    });

    test('strips leading v', () {
      expect(PrismVersion.parse('v2.0.1').toString(), '2.0.1');
    });

    test('parses build metadata as fourth component', () {
      final v = PrismVersion.parse('1.2.3+4');
      expect(v.components, [1, 2, 3, 4]);
    });

    test('ignores non-numeric suffixes', () {
      expect(PrismVersion.parse('2.2.0-beta.1').components, [2, 2, 0, 1]);
    });

    test('throws on garbage', () {
      expect(
        () => PrismVersion.parse('not-a-version'),
        throwsA(isA<PrismVersionException>()),
      );
    });
  });

  group('PrismVersion comparison', () {
    test('compares component-wise with zero padding', () {
      expect(PrismVersion.parse('1.2.3') > PrismVersion.parse('1.2'), isTrue);
      expect(PrismVersion.parse('1.2.3') < PrismVersion.parse('1.3'), isTrue);
      expect(
        PrismVersion.parse('1.0') <= PrismVersion.parse('1.0.0'),
        isTrue,
      );
      expect(
        PrismVersion.parse('2.0') == PrismVersion.parse('2.0.0'),
        isTrue,
      );
    });

    test('distinguishes build numbers', () {
      expect(
        PrismVersion.parse('1.0.0+2') > PrismVersion.parse('1.0.0+1'),
        isTrue,
      );
    });

    test('hashCode matches equality', () {
      expect(
        PrismVersion.parse('1.2.3').hashCode,
        PrismVersion.parse('1.2.3.0').hashCode,
      );
    });
  });
}
