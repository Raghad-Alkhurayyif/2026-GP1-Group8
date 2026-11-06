import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether a location fix was obtained for an SOS alert, and if not, why.
enum LocationStatus {
  /// A fix was obtained; [LocationResult.latitude] and
  /// [LocationResult.longitude] are set.
  ok,

  /// The user declined the permission, or has not been asked yet.
  denied,

  /// The user declined the permission permanently. Only the system settings
  /// can turn it back on.
  deniedForever,

  /// Location services are switched off on the device.
  servicesOff,

  /// No fix arrived within the time limit (5 seconds by default).
  timeout,

  /// The platform reported some other error.
  unavailable,
}

/// The outcome of one location request. Nothing in it is saved anywhere:
/// it lives only as long as the alert that uses it.
class LocationResult {
  const LocationResult.found(double this.latitude, double this.longitude)
      : status = LocationStatus.ok;

  const LocationResult.failed(this.status)
      : assert(status != LocationStatus.ok),
        latitude = null,
        longitude = null;

  final LocationStatus status;
  final double? latitude;
  final double? longitude;

  bool get isAvailable => status == LocationStatus.ok;

  /// A map link to the coordinates for the SMS, or null without a fix.
  String? get mapLink => isAvailable
      ? 'https://maps.google.com/?q=${latitude!.toStringAsFixed(6)},'
          '${longitude!.toStringAsFixed(6)}'
      : null;

  @override
  String toString() => isAvailable
      ? 'LocationResult(ok, $latitude, $longitude)'
      : 'LocationResult(${status.name})';
}

/// Where the location permission stands, as the SOS screens need to know it.
enum LocationPermissionState {
  /// The app has never asked. PBI-23: explain why before asking.
  notRequested,

  /// Asked before and declined. PBI-23: do not ask again during SOS; the
  /// settings screen offers a way to turn it back on.
  denied,

  /// Declined permanently. Only the system settings can turn it back on.
  deniedForever,

  /// Granted.
  granted,
}

/// What the device itself can do, kept behind an interface so the logic can
/// be tested without a phone. [GeolocatorPlatformAccess] is the real one.
abstract class LocationPlatformAccess {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<({double latitude, double longitude})> getCurrentPosition();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorPlatformAccess implements LocationPlatformAccess {
  const GeolocatorPlatformAccess();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<({double latitude, double longitude})> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return (latitude: position.latitude, longitude: position.longitude);
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Remembers whether the app has already shown the system permission
/// dialog. Android reports "denied" both before the first request and after
/// a refusal, so this flag is the only way to tell the two apart. It is a
/// yes/no flag; no location is ever stored.
abstract class PermissionPromptRecord {
  Future<bool> wasRequested();
  Future<void> markRequested();
}

class SharedPreferencesPromptRecord implements PermissionPromptRecord {
  const SharedPreferencesPromptRecord();

  static const _key = 'sos.locationPermissionRequested';

  @override
  Future<bool> wasRequested() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> markRequested() async =>
      (await SharedPreferences.getInstance()).setBool(_key, true);
}

/// Location for the SOS alert (PBI-21, PBI-23).
///
/// [getCurrentLocation] never shows a dialog and never throws: it always
/// returns a [LocationResult] within the time limit, so the alert can go out
/// without a location when one cannot be had.
class LocationService {
  LocationService({
    LocationPlatformAccess platform = const GeolocatorPlatformAccess(),
    PermissionPromptRecord promptRecord = const SharedPreferencesPromptRecord(),
  })  : _platform = platform, // ignore: prefer_initializing_formals
        _promptRecord = promptRecord; // ignore: prefer_initializing_formals

  static const Duration defaultTimeout = Duration(seconds: 5);

  final LocationPlatformAccess _platform;
  final PermissionPromptRecord _promptRecord;

  /// Reads the permission state without asking the user anything.
  Future<LocationPermissionState> permissionState() async {
    try {
      final permission = await _platform.checkPermission();
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return LocationPermissionState.granted;
        case LocationPermission.deniedForever:
          return LocationPermissionState.deniedForever;
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return await _promptRecord.wasRequested()
              ? LocationPermissionState.denied
              : LocationPermissionState.notRequested;
      }
    } catch (_) {
      return LocationPermissionState.denied;
    }
  }

  /// True when the explanation screen should be shown before the system
  /// dialog, which is only before the very first request (PBI-23, AC 1, 4).
  Future<bool> needsExplanation() async =>
      await permissionState() == LocationPermissionState.notRequested;

  /// Shows the system permission dialog. Call it only after the explanation
  /// screen. It asks once: after a refusal it returns the state without
  /// asking again, so the user is never prompted repeatedly (PBI-23, AC 4).
  Future<LocationPermissionState> requestPermission() async {
    final current = await permissionState();
    if (current != LocationPermissionState.notRequested) return current;
    await _promptRecord.markRequested();
    try {
      await _platform.requestPermission();
    } catch (_) {
      // A request already in progress or a platform error: fall through and
      // report whatever the state now is.
    }
    return permissionState();
  }

  Future<bool> isLocationServiceEnabled() async {
    try {
      return await _platform.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Gets one fix for the alert. Never asks for permission, never throws,
  /// and always returns within [timeout] (PBI-21, AC 2).
  Future<LocationResult> getCurrentLocation({
    Duration timeout = defaultTimeout,
  }) {
    return _locate().timeout(
      timeout,
      onTimeout: () => const LocationResult.failed(LocationStatus.timeout),
    );
  }

  Future<LocationResult> _locate() async {
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationStatus.servicesOff);
      }
      switch (await permissionState()) {
        case LocationPermissionState.notRequested:
        case LocationPermissionState.denied:
          return const LocationResult.failed(LocationStatus.denied);
        case LocationPermissionState.deniedForever:
          return const LocationResult.failed(LocationStatus.deniedForever);
        case LocationPermissionState.granted:
          break;
      }
      final position = await _platform.getCurrentPosition();
      return LocationResult.found(position.latitude, position.longitude);
    } on LocationServiceDisabledException {
      return const LocationResult.failed(LocationStatus.servicesOff);
    } on PermissionDeniedException {
      return const LocationResult.failed(LocationStatus.denied);
    } catch (_) {
      return const LocationResult.failed(LocationStatus.unavailable);
    }
  }

  /// For the settings option that turns location back on (PBI-23, AC 4).
  /// Opens the app's page in the system settings.
  Future<bool> openAppSettings() => _platform.openAppSettings();

  /// For the "turn on location" option when services are off (PBI-23, AC 5).
  Future<bool> openLocationSettings() => _platform.openLocationSettings();
}
