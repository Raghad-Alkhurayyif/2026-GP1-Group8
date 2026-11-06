import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mata_app/sos/location_service.dart';

import 'fakes.dart';

void main() {
  late FakePlatform platform;
  late FakePromptRecord record;
  late LocationService service;

  setUp(() {
    platform = FakePlatform();
    record = FakePromptRecord();
    service = LocationService(platform: platform, promptRecord: record);
  });

  group('permission state', () {
    test('never asked before means the explanation is needed', () async {
      expect(await service.permissionState(),
          LocationPermissionState.notRequested);
      expect(await service.needsExplanation(), isTrue);
    });

    test('asked and declined means denied, with no explanation', () async {
      record.requested = true;
      expect(await service.permissionState(), LocationPermissionState.denied);
      expect(await service.needsExplanation(), isFalse);
    });

    test('granted and permanently denied are reported as such', () async {
      platform.permission = LocationPermission.whileInUse;
      expect(await service.permissionState(), LocationPermissionState.granted);
      platform.permission = LocationPermission.always;
      expect(await service.permissionState(), LocationPermissionState.granted);
      platform.permission = LocationPermission.deniedForever;
      expect(await service.permissionState(),
          LocationPermissionState.deniedForever);
    });
  });

  group('requesting permission', () {
    test('asks once and remembers that it asked', () async {
      final state = await service.requestPermission();
      expect(state, LocationPermissionState.granted);
      expect(platform.requestCount, 1);
      expect(record.requested, isTrue);
    });

    test('after a refusal it does not ask again', () async {
      platform.answerToRequest = LocationPermission.denied;
      expect(await service.requestPermission(), LocationPermissionState.denied);
      expect(await service.requestPermission(), LocationPermissionState.denied);
      expect(platform.requestCount, 1);
    });
  });

  group('getting the location', () {
    test('returns the coordinates and a map link when granted', () async {
      platform.permission = LocationPermission.whileInUse;
      final result = await service.getCurrentLocation();
      expect(result.status, LocationStatus.ok);
      expect(result.mapLink, 'https://maps.google.com/?q=24.713600,46.675300');
    });

    test('never shows the permission dialog', () async {
      final result = await service.getCurrentLocation();
      expect(result.status, LocationStatus.denied);
      expect(result.mapLink, isNull);
      expect(platform.requestCount, 0);
      expect(platform.fixCount, 0);
    });

    test('reports permanently denied', () async {
      platform.permission = LocationPermission.deniedForever;
      expect((await service.getCurrentLocation()).status,
          LocationStatus.deniedForever);
    });

    test('reports services switched off', () async {
      platform.permission = LocationPermission.whileInUse;
      platform.servicesOn = false;
      expect((await service.getCurrentLocation()).status,
          LocationStatus.servicesOff);
    });

    test('gives up after 5 seconds', () {
      fakeAsync((async) {
        platform.permission = LocationPermission.whileInUse;
        platform.fixDelay = const Duration(seconds: 30);
        LocationResult? result;
        service.getCurrentLocation().then((r) => result = r);
        async.elapse(const Duration(milliseconds: 4900));
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 200));
        expect(result?.status, LocationStatus.timeout);
      });
    });

    test('turns platform errors into a result instead of throwing', () async {
      platform.permission = LocationPermission.whileInUse;
      platform.fixError = const LocationServiceDisabledException();
      expect((await service.getCurrentLocation()).status,
          LocationStatus.servicesOff);
      platform.fixError = Exception('GPS broke');
      expect((await service.getCurrentLocation()).status,
          LocationStatus.unavailable);
    });
  });
}
