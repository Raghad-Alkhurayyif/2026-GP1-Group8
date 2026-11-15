import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mata_app/models/emergency_contact.dart';
import 'package:mata_app/sos/android_sms_sender.dart';
import 'package:mata_app/sos/location_service.dart';
import 'package:mata_app/sos/sos_controller.dart';
import 'package:mata_app/sos/sos_sender.dart';
import 'package:mata_app/sos/sos_setup.dart';

// Reserved fictional North American 555-01xx range; mocked dispatch only.
const contact = EmergencyContact(
  id: 'fixture',
  name: 'Fixture',
  phoneNumber:
      '+1'
      '202'
      '5550123',
  isDefault: true,
);
const unavailable = LocationResult.failed(LocationStatus.unavailable);

class FakeLocation extends LocationService {
  Future<LocationResult>? pending;
  @override
  Future<bool> needsExplanation() async => false;
  @override
  Future<LocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 5),
  }) => pending ?? Future.value(unavailable);
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermissionState> permissionState() async =>
      LocationPermissionState.granted;
}

class FakeSender implements SosSender {
  final prepared = <EmergencyContact>[];
  int sends = 0;
  Future<SosResult?>? preparation;
  SosResult result = const SosResult(outcome: SosOutcome.sent);
  @override
  Future<SosResult?> prepare(EmergencyContact contact) {
    prepared.add(contact);
    return preparation ?? Future.value(null);
  }

  @override
  Future<SosResult> send({required LocationResult location}) async {
    sends++;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SosController controller(
    FakeSender sender,
    FakeLocation location, {
    Future<EmergencyContact?> Function()? load,
  }) => SosController(
    sender: sender,
    locationService: location,
    loadDefaultContact: load ?? () async => contact,
  );

  test('sender selection follows explicit test mode', () {
    expect(
      createSosSender(),
      const bool.fromEnvironment('SOS_TEST_MODE')
          ? isA<StubSosSender>()
          : isA<AndroidSmsSender>(),
    );
    expect(isTestSender(StubSosSender()), isTrue);
  });

  testWidgets('prepares before five-second countdown and dispatches once', (
    tester,
  ) async {
    final sender = FakeSender();
    final sos = controller(sender, FakeLocation());
    addTearDown(sos.dispose);
    await sos.activate();
    expect(sender.prepared, [contact]);
    expect(sos.secondsLeft, 5);
    await tester.pump(const Duration(seconds: 4));
    expect(sender.sends, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(sender.sends, 1);
    sos.sendNow();
    await tester.pump();
    expect(sender.sends, 1);
  });

  testWidgets('cancel countdown and late preparation never dispatch', (
    tester,
  ) async {
    final sender = FakeSender();
    final ready = Completer<SosResult?>();
    sender.preparation = ready.future;
    final sos = controller(sender, FakeLocation());
    addTearDown(sos.dispose);
    final activation = sos.activate();
    await tester.pump();
    sos.cancel();
    ready.complete(null);
    await activation;
    await tester.pump(const Duration(seconds: 6));
    expect(sos.phase, SosPhase.cancelled);
    expect(sender.sends, 0);
  });

  testWidgets('Send Now remains cancellable while location is pending', (
    tester,
  ) async {
    final sender = FakeSender();
    final location = Completer<LocationResult>();
    final sos = controller(sender, FakeLocation()..pending = location.future);
    addTearDown(sos.dispose);
    await sos.activate();
    sos.sendNow();
    sos.sendNow();
    sos.cancel();
    location.complete(unavailable);
    await tester.pump();
    expect(sender.sends, 0);
    expect(sos.phase, SosPhase.cancelled);
  });

  testWidgets('Send Now dispatches once without waiting for timer', (
    tester,
  ) async {
    final sender = FakeSender();
    final sos = controller(sender, FakeLocation());
    addTearDown(sos.dispose);
    await sos.activate();
    sos.sendNow();
    sos.sendNow();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(sender.sends, 1);
  });

  testWidgets('backgrounding countdown prevents dispatch', (tester) async {
    final sender = FakeSender();
    final sos = controller(sender, FakeLocation());
    addTearDown(sos.dispose);
    await sos.activate();
    sos.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));
    expect(sender.sends, 0);
    expect(sos.cancelReason, SosCancelReason.interrupted);
  });

  testWidgets(
    'permission failure never starts countdown; safe retry retains recipient',
    (tester) async {
      final sender = FakeSender()
        ..preparation = Future.value(
          const SosResult(
            outcome: SosOutcome.failed,
            reason: 'permission_denied',
            retryAllowed: true,
          ),
        );
      var loads = 0;
      final sos = controller(
        sender,
        FakeLocation(),
        load: () async {
          loads++;
          return contact;
        },
      );
      addTearDown(sos.dispose);
      await sos.activate();
      expect(sos.phase, SosPhase.finished);
      expect(sender.sends, 0);
      sender.preparation = null;
      await sos.retry();
      expect(loads, 1);
      expect(sender.prepared, [contact, contact]);
      expect(sos.secondsLeft, 5);
      sos.cancel();
    },
  );

  for (final outcome in [
    SosOutcome.sent,
    SosOutcome.failed,
    SosOutcome.partial,
    SosOutcome.unknown,
  ]) {
    testWidgets(
      '$outcome cannot be retried without explicit pre-dispatch safety',
      (tester) async {
        final sender = FakeSender()..result = SosResult(outcome: outcome);
        final sos = controller(sender, FakeLocation());
        addTearDown(sos.dispose);
        await sos.activate();
        sos.sendNow();
        await tester.pump();
        await sos.retry();
        expect(sender.sends, 1);
      },
    );
  }

  testWidgets('Firestore errors differ from missing default contact', (
    tester,
  ) async {
    final sender = FakeSender();
    final failed = controller(
      sender,
      FakeLocation(),
      load: () async => throw StateError('offline'),
    );
    final absent = controller(sender, FakeLocation(), load: () async => null);
    addTearDown(failed.dispose);
    addTearDown(absent.dispose);
    await failed.activate();
    await absent.activate();
    expect(failed.result?.reason, 'contact_unavailable');
    expect(absent.phase, SosPhase.noDefaultContact);
    expect(sender.prepared, isEmpty);
  });

  group('Android sender channel', () {
    const channel = MethodChannel('mata/sms');
    final calls = <MethodCall>[];
    var permission = 'granted';
    var status = 'sent';
    var preparationStatus = 'ready';
    var throwOnSend = false;
    setUp(() {
      calls.clear();
      permission = 'granted';
      status = 'sent';
      preparationStatus = 'ready';
      throwOnSend = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'send' && throwOnSend) {
              throw PlatformException(code: 'interrupted');
            }
            return switch (call.method) {
              'requestPermission' => permission,
              'prepare' => {'status': preparationStatus, 'subscriptionId': 7},
              _ => status,
            };
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('validates contact, freezes recipient/SIM, composes location and deduplicates', () async {
      final sender = AndroidSmsSender(channel: channel);
      expect(await sender.prepare(contact), isNull);
      final first = sender.send(location: const LocationResult.found(0, 0));
      final second = sender.send(location: unavailable);
      expect(identical(first, second), isTrue);
      expect((await first).outcome, SosOutcome.sent);
      final send = calls.singleWhere((call) => call.method == 'send');
      expect(send.arguments['recipient'], contact.phoneNumber);
      expect(send.arguments['subscriptionId'], 7);
      expect(
        send.arguments['message'],
        contains('https://maps.google.com/?q=0.000000,0.000000'),
      );
      expect(send.arguments['attemptId'], isNotEmpty);
    });

    test('invalid saved phone causes no permission request or send', () async {
      final result = await AndroidSmsSender(channel: channel)
          .prepare(contact.copyWith(phoneNumber: 'invalid'));
      expect(result?.reason, 'invalid_contact');
      expect(calls, isEmpty);
    });

    test('permission denial does not resolve SIM or send', () async {
      permission = 'denied';
      final result = await AndroidSmsSender(channel: channel).prepare(contact);
      expect(result?.reason, 'permission_denied');
      expect(calls.map((call) => call.method), ['requestPermission']);
    });

    for (final failure in [
      'no_default_sim',
      'sim_not_ready',
      'unsupported_device',
    ]) {
      test('$failure fails preparation without dispatch', () async {
        preparationStatus = failure;
        final result = await AndroidSmsSender(channel: channel)
            .prepare(contact);
        expect(result?.reason, failure);
        expect(calls.where((call) => call.method == 'send'), isEmpty);
      });
    }

    test('channel interruption is unknown and cannot be retried', () async {
      throwOnSend = true;
      final sender = AndroidSmsSender(channel: channel);
      expect(await sender.prepare(contact), isNull);
      final result = await sender.send(location: unavailable);
      expect(result.outcome, SosOutcome.unknown);
      expect(result.retryAllowed, isFalse);
      await sender.send(location: unavailable);
      expect(calls.where((call) => call.method == 'send').length, 1);
    });

    for (final entry in {
      'partial': SosOutcome.partial,
      'unknown': SosOutcome.unknown,
      'failed': SosOutcome.failed,
    }.entries) {
      test('${entry.key} is not safe to retry', () async {
        status = entry.key;
        final sender = AndroidSmsSender(channel: channel);
        await sender.prepare(contact);
        final result = await sender.send(location: unavailable);
        expect(result.outcome, entry.value);
        expect(result.retryAllowed, isFalse);
        expect(
          calls.last.arguments['message'],
          contains('My location is unavailable.'),
        );
      });
    }
  });
}
