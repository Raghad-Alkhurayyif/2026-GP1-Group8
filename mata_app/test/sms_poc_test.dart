import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mata_app/sms_poc_main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mata/sms_poc');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'requestPermission' ? 'granted' : 'sent';
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('startup never invokes native SMS and requires authorization', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SmsPocScreen()));
    expect(calls, isEmpty);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text('No SMS has been sent.'), findsOneWidget);
  });

  test('send success is explicitly not delivery confirmation', () {
    expect(smsPocStatus('sent'), contains('NOT confirmed'));
    expect(smsPocStatus('partial'), contains('Do not automatically retry'));
    expect(smsPocStatus('unknown'), contains('may have been sent'));
    expect(smsPocStatus('no_default_sim'), contains('dual-SIM'));
  });

  testWidgets('explicit confirmation sends once and locks repeated taps', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SmsPocScreen()));
    // Synthetic, unassigned country prefix; never leaves the mocked channel.
    await tester.enterText(find.byType(TextField).first, '+999${'1' * 8}');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.text('Send real SMS'));
    await tester.pumpAndSettle();
    expect(calls, ['requestPermission', 'send']);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('NOT confirmed'), findsOneWidget);
  });

  testWidgets('permission denial does not dispatch SMS', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return 'denied';
        });
    await tester.pumpWidget(const MaterialApp(home: SmsPocScreen()));
    await tester.enterText(find.byType(TextField).first, '+999${'1' * 8}');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send real SMS'));
    await tester.pumpAndSettle();
    expect(calls, ['requestPermission']);
  });
}
