import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:mata_app/sos/location_service.dart';
import 'package:mata_app/sos/sos_sender.dart';

class FakePlatform implements LocationPlatformAccess {
  bool servicesOn = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission answerToRequest = LocationPermission.whileInUse;
  Duration fixDelay = Duration.zero;
  Object? fixError;
  int requestCount = 0;
  int fixCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => servicesOn;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    permission = answerToRequest;
    return permission;
  }

  @override
  Future<({double latitude, double longitude})> getCurrentPosition() async {
    fixCount++;
    await Future<void>.delayed(fixDelay);
    if (fixError != null) throw fixError!;
    return (latitude: 24.7136, longitude: 46.6753);
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class FakePromptRecord implements PermissionPromptRecord {
  FakePromptRecord([this.requested = false]);
  bool requested;

  @override
  Future<bool> wasRequested() async => requested;

  @override
  Future<void> markRequested() async => requested = true;
}

class RecordingSender implements SosSender {
  RecordingSender({this.outcome = SosOutcome.sent, this.throwError = false});

  SosOutcome outcome;
  bool throwError;
  final List<LocationResult> calls = [];

  @override
  Future<SosResult> send({required LocationResult location}) async {
    calls.add(location);
    if (throwError) throw StateError('SMS failed');
    return SosResult(
      outcome: outcome,
      contactName: 'Sara',
      locationIncluded: location.isAvailable,
    );
  }
}
