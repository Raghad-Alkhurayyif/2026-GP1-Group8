import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mata_app/sos/location_service.dart';
import 'package:mata_app/sos/sos_controller.dart';
import 'package:mata_app/sos/sos_sender.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlatform platform;
  late FakePromptRecord record;
  late RecordingSender sender;
  String? defaultContact;

  SosController makeController() => SosController(
        sender: sender,
        locationService:
            LocationService(platform: platform, promptRecord: record),
        loadDefaultContactName: () async => defaultContact,
      );

  setUp(() {
    platform = FakePlatform()..permission = LocationPermission.whileInUse;
    record = FakePromptRecord(true);
    sender = RecordingSender();
    defaultContact = 'Sara';
  });

  void tick(FakeAsync async, [int seconds = 0]) {
    async.flushMicrotasks();
    async.elapse(Duration(seconds: seconds));
    async.flushMicrotasks();
  }

  test('counts down and sends when the countdown ends', () {
    fakeAsync((async) {
      final c = makeController();
      c.activate();
      tick(async);
      expect(c.phase, SosPhase.countingDown);
      expect(c.secondsLeft, 5);
      expect(c.contactName, 'Sara');

      tick(async, 4);
      expect(c.secondsLeft, 1);
      expect(sender.calls, isEmpty);

      tick(async, 1);
      expect(c.phase, SosPhase.finished);
      expect(sender.calls, hasLength(1));
      expect(sender.calls.single.isAvailable, isTrue);
      expect(c.result!.wasSent, isTrue);
      expect(c.result!.locationIncluded, isTrue);
    });
  });

  test('cancel stops the alert and nothing is ever sent', () {
    fakeAsync((async) {
      final c = makeController();
      c.activate();
      tick(async, 2);
      c.cancel();
      tick(async, 30);
      expect(c.phase, SosPhase.cancelled);
      expect(c.cancelReason, SosCancelReason.user);
      expect(sender.calls, isEmpty);
    });
  });

  test('cancel while still checking the contact sends nothing', () {
    fakeAsync((async) {
      final c = makeController();
      c.activate();
      c.cancel();
      tick(async, 30);
      expect(c.phase, SosPhase.cancelled);
      expect(sender.calls, isEmpty);
    });
  });

  test('send now skips the rest of the countdown', () {
    fakeAsync((async) {
      final c = makeController();
      c.activate();
      tick(async, 1);
      c.sendNow();
      tick(async);
      expect(c.phase, SosPhase.finished);
      expect(sender.calls, hasLength(1));
      tick(async, 30);
      expect(sender.calls, hasLength(1), reason: 'sent exactly once');
    });
  });

  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    test('leaving the app (${state.name}) during the countdown sends nothing',
        () {
      fakeAsync((async) {
        final c = makeController();
        c.activate();
        tick(async, 2);
        c.didChangeAppLifecycleState(state);
        tick(async, 30);
        expect(c.phase, SosPhase.cancelled);
        expect(c.cancelReason, SosCancelReason.interrupted);
        expect(sender.calls, isEmpty);
      });
    });
  }

  test('a brief "inactive" (notification shade) does not cancel', () {
    fakeAsync((async) {
      final c = makeController();
      c.activate();
      tick(async, 2);
      c.didChangeAppLifecycleState(AppLifecycleState.inactive);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      tick(async, 3);
      expect(sender.calls, hasLength(1));
    });
  });

  test('closing the SOS screen during the countdown sends nothing', () {
    fakeAsync((async) {
      final c = makeController();
      c.activate();
      tick(async, 2);
      c.dispose();
      tick(async, 30);
      expect(sender.calls, isEmpty);
    });
  });

  test('with no default contact nothing is sent and the fallback shows', () {
    fakeAsync((async) {
      defaultContact = null;
      final c = makeController();
      c.activate();
      tick(async, 30);
      expect(c.phase, SosPhase.noDefaultContact);
      expect(sender.calls, isEmpty);
    });
  });

  test('a first-time user sees the explanation before the system dialog', () {
    fakeAsync((async) {
      record.requested = false;
      platform.permission = LocationPermission.denied;
      final c = makeController();
      c.activate();
      tick(async, 30);
      expect(c.phase, SosPhase.explainLocation);
      expect(platform.requestCount, 0);
      expect(sender.calls, isEmpty);

      c.continueAfterExplanation();
      tick(async);
      expect(platform.requestCount, 1);
      expect(c.phase, SosPhase.countingDown);
      tick(async, 5);
      expect(sender.calls.single.isAvailable, isTrue);
    });
  });

  test('declining the permission still sends, without a location', () {
    fakeAsync((async) {
      record.requested = false;
      platform.permission = LocationPermission.denied;
      platform.answerToRequest = LocationPermission.denied;
      final c = makeController();
      c.activate();
      tick(async);
      c.continueAfterExplanation();
      tick(async);
      expect(c.expectedLocationProblem, LocationStatus.denied);
      tick(async, 5);
      expect(sender.calls.single.status, LocationStatus.denied);
      expect(c.result!.locationIncluded, isFalse);
    });
  });

  test('a user who declined before is not asked again', () {
    fakeAsync((async) {
      platform.permission = LocationPermission.denied;
      final c = makeController();
      c.activate();
      tick(async);
      expect(c.phase, SosPhase.countingDown);
      tick(async, 5);
      expect(platform.requestCount, 0);
      expect(sender.calls.single.status, LocationStatus.denied);
    });
  });

  test('location services off is flagged during the countdown', () {
    fakeAsync((async) {
      platform.servicesOn = false;
      final c = makeController();
      c.activate();
      tick(async);
      expect(c.expectedLocationProblem, LocationStatus.servicesOff);
      tick(async, 5);
      expect(sender.calls.single.status, LocationStatus.servicesOff);
    });
  });

  test('a slow fix does not hold the alert back past 5 seconds', () {
    fakeAsync((async) {
      platform.fixDelay = const Duration(minutes: 1);
      final c = makeController();
      c.activate();
      tick(async, 1);
      c.sendNow();
      tick(async, 3);
      expect(c.phase, SosPhase.sending);
      tick(async, 1); // 5 seconds after the fix was started
      expect(c.phase, SosPhase.finished);
      expect(sender.calls.single.status, LocationStatus.timeout);
    });
  });

  test('a sender that throws is reported as a failure, and retry works', () {
    fakeAsync((async) {
      sender.throwError = true;
      final c = makeController();
      c.activate();
      tick(async, 5);
      expect(c.result!.outcome, SosOutcome.failed);

      sender.throwError = false;
      c.retry();
      tick(async);
      expect(sender.calls, hasLength(2));
      expect(c.result!.wasSent, isTrue);
    });
  });

  test('cancel is not possible once sending has started', () {
    fakeAsync((async) {
      platform.fixDelay = const Duration(seconds: 3);
      final c = makeController();
      c.activate();
      tick(async);
      c.sendNow();
      tick(async);
      expect(c.phase, SosPhase.sending);
      expect(c.canCancel, isFalse);
      c.cancel();
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      tick(async, 5);
      expect(sender.calls, hasLength(1));
    });
  });

  test('pressing SOS twice starts only one countdown', () {
    fakeAsync((async) {
      final c = makeController();
      c.activate();
      c.activate();
      tick(async);
      c.activate();
      tick(async, 10);
      expect(sender.calls, hasLength(1));
    });
  });
}
