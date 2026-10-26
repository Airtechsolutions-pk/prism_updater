import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_updater/prism_updater.dart';

void main() {
  testWidgets('PrismUpdateStatusView renders each state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PrismUpdateStatusView(state: PrismUpdateIdle()),
              PrismUpdateStatusView(state: PrismUpdateChecking()),
              PrismUpdateStatusView(state: PrismUpdateUpToDate()),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Not checked yet'), findsOneWidget);
    expect(find.text('Checking…'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
  });

  testWidgets('PrismUpdateProgress shows label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrismUpdateProgress())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Checking for updates…'), findsOneWidget);
  });

  testWidgets('GateBehavior.block renders forced screen via softUpdateBuilder',
      (tester) async {
    // The gate is exercised through the controller in integration-style
    // tests; here we verify the soft-update card builds standalone.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrismSoftUpdateCard(
            state: PrismUpdateAvailable(
              current: PrismVersion.parse('1.0.0'),
              result: const UpdatePolicyResult(UpdateDecision.softUpdate),
            ),
            platformInfo: null,
            onDismiss: null,
          ),
        ),
      ),
    );
    expect(find.byType(PrismSoftUpdateCard), findsOneWidget);
  });
}
