import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_updater/prism_updater.dart';


PrismUpdatePlatformInfo fakePlatform({required bool storeFlow}) =>
    PrismUpdatePlatformInfo(
      isWeb: !storeFlow,
      isAndroid: storeFlow,
      isIOS: false,
      isWindows: false,
      isMacOS: false,
      isLinux: false,
    );

/// Source whose behavior is controlled per-test.
class _ConfigurableSource implements PrismUpdateSource {
  _ConfigurableSource(this.latest);

  Map<UpdateChannel, PrismVersion> latest;
  Object? error;

  @override
  Future<Map<UpdateChannel, PrismVersion>> fetchLatest() async {
    final err = error;
    if (err != null) throw err;
    return latest;
  }
}

PrismUpdateController buildController({
  required PrismUpdateSource source,
  required PrismVersion current,
  UpdatePolicy policy = const UpdatePolicy(),
  bool storeFlow = true,
}) {
  return PrismUpdateController(
    source: source,
    policy: policy,
    currentVersion: current,
    platformInfo: fakePlatform(storeFlow: storeFlow),
    autoCheck: false,
  );
}

void main() {
  group('PrismUpdateGate', () {
    testWidgets('renders child when up to date', (tester) async {
      final source = _ConfigurableSource(
        {UpdateChannel.stable: PrismVersion.parse('1.0.0')},
      );
      final controller = buildController(
        source: source,
        current: PrismVersion.parse('1.0.0'),
      );
      await controller.checkNow();

      await tester.pumpWidget(
        MaterialApp(
          home: PrismUpdateGate(
            controller: controller,
            child: const Text('app content'),
          ),
        ),
      );
      expect(find.text('app content'), findsOneWidget);
      expect(find.byType(PrismForceUpdateScreen), findsNothing);
      controller.dispose();
    });

    testWidgets('blocks behind forced update screen', (tester) async {
      final source = _ConfigurableSource(
        {UpdateChannel.stable: PrismVersion.parse('9.0.0')},
      );
      final controller = buildController(
        source: source,
        current: PrismVersion.parse('1.0.0'),
        policy: UpdatePolicy(minimumVersion: PrismVersion.parse('2.0.0')),
      );
      await controller.checkNow();

      await tester.pumpWidget(
        MaterialApp(
          home: PrismUpdateGate(
            controller: controller,
            child: const Text('app content'),
          ),
        ),
      );
      expect(find.text('app content'), findsNothing);
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Update now'), findsOneWidget);
      // No skip button on forced screens.
      expect(find.text('Maybe later'), findsNothing);
      controller.dispose();
    });

    testWidgets('banner behavior shows card over app content',
        (tester) async {
      final source = _ConfigurableSource(
        {UpdateChannel.stable: PrismVersion.parse('1.1.0')},
      );
      final controller = buildController(
        source: source,
        current: PrismVersion.parse('1.0.0'),
      );
      await controller.checkNow();

      await tester.pumpWidget(
        MaterialApp(
          home: PrismUpdateGate(
            controller: controller,
            behavior: GateBehavior.banner,
            child: const Text('app content'),
          ),
        ),
      );
      // App stays usable…
      expect(find.text('app content'), findsOneWidget);
      // …and the update card is layered on top.
      expect(find.byType(PrismSoftUpdateCard), findsOneWidget);
      controller.dispose();
    });

    testWidgets('custom forcedBuilder overrides default screen',
        (tester) async {
      final source = _ConfigurableSource(
        {UpdateChannel.stable: PrismVersion.parse('9.0.0')},
      );
      final controller = buildController(
        source: source,
        current: PrismVersion.parse('1.0.0'),
        policy: UpdatePolicy(minimumVersion: PrismVersion.parse('2.0.0')),
      );
      await controller.checkNow();

      await tester.pumpWidget(
        MaterialApp(
          home: PrismUpdateGate(
            controller: controller,
            forcedBuilder: (context) => const Text('custom forced UI'),
            child: const Text('app content'),
          ),
        ),
      );
      expect(find.text('custom forced UI'), findsOneWidget);
      expect(find.text('Update required'), findsNothing);
      controller.dispose();
    });

    testWidgets('checking state renders child by default', (tester) async {
      final source = _ConfigurableSource(
        {UpdateChannel.stable: PrismVersion.parse('1.0.0')},
      );
      final controller = buildController(
        source: source,
        current: PrismVersion.parse('1.0.0'),
      );
      // Do NOT resolve the check yet.

      await tester.pumpWidget(
        MaterialApp(
          home: PrismUpdateGate(
            controller: controller,
            child: const Text('app content'),
          ),
        ),
      );
      expect(find.text('app content'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('failure renders child by default (never breaks the app)',
        (tester) async {
      final source = _ConfigurableSource(
        {UpdateChannel.stable: PrismVersion.parse('1.0.0')},
      )..error = Exception('network down');
      final controller = buildController(
        source: source,
        current: PrismVersion.parse('1.0.0'),
      );
      await controller.checkNow();
      expect(controller.state, isA<PrismUpdateFailure>());

      await tester.pumpWidget(
        MaterialApp(
          home: PrismUpdateGate(
            controller: controller,
            child: const Text('app content'),
          ),
        ),
      );
      expect(find.text('app content'), findsOneWidget);
      controller.dispose();
    });
  });

  group('PrismForceUpdateScreen', () {
    testWidgets('shows notes and skip action when dismissible',
        (tester) async {
      var skipped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PrismForceUpdateScreen(
            canDismiss: true,
            onSkip: () => skipped = true,
            platformInfo: fakePlatform(storeFlow: true),
            state: PrismUpdateAvailable(
              current: PrismVersion.parse('1.0.0'),
              result: UpdatePolicyResult(
                UpdateDecision.softUpdate,
                latest: PrismVersion.parse('2.0.0'),
              ),
              notes: 'Faster and shinier',
            ),
          ),
        ),
      );

      expect(find.text('A new version is available'), findsOneWidget);
      expect(find.text('Faster and shinier'), findsOneWidget);
      expect(find.text('Maybe later'), findsOneWidget);

      await tester.tap(find.text('Maybe later'));
      expect(skipped, isTrue);
    });
  });

  group('PrismSoftUpdateCard', () {
    testWidgets('shows version and dismisses', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrismSoftUpdateCard(
              onDismiss: () => dismissed = true,
              platformInfo: fakePlatform(storeFlow: true),
              state: PrismUpdateAvailable(
                current: PrismVersion.parse('1.0.0'),
                result: UpdatePolicyResult(
                  UpdateDecision.softUpdate,
                  latest: PrismVersion.parse('2.0.0'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Version 2.0.0 available'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);
    });
  });
}
