import 'package:country_coder/country_coder.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// The number shown when the country is unknown or not in
/// [ambulanceNumbers]. Phones treat 112 as an emergency number on every GSM
/// network, even without a SIM card, and the network connects the call to
/// its own emergency service.
const String fallbackEmergencyNumber = '112';

/// The ambulance number for each country, by ISO 3166-1 alpha-2 code.
///
/// Only countries whose number differs from 112, or where 112 is not the
/// main public number, are listed; every other country gets
/// [fallbackEmergencyNumber]. Checked against the List of emergency
/// telephone numbers (Wikipedia, November 2026). Review before each release.
const Map<String, String> ambulanceNumbers = {
  // Gulf and the wider Middle East
  'SA': '997', // Saudi Red Crescent
  'AE': '998',
  'KW': '112',
  'QA': '999',
  'BH': '999',
  'OM': '9999',
  'JO': '911',
  'LB': '140',
  'SY': '110',
  'PS': '101',
  'IL': '101',
  'IR': '115',
  'TR': '112',
  // North Africa
  'EG': '123',
  'MA': '15',
  'DZ': '14',
  'TN': '190',
  // Asia
  'PK': '1122',
  'BD': '999',
  'IN': '112',
  'MY': '999',
  'SG': '995',
  'PH': '911',
  'CN': '120',
  'HK': '999',
  'TW': '119',
  'JP': '119',
  'KR': '119',
  'TH': '1669',
  'VN': '115',
  // Europe outside the 112-only countries
  'GB': '999',
  'CH': '144',
  'AT': '144',
  'NO': '113',
  // Americas
  'US': '911',
  'CA': '911',
  'MX': '911',
  'BR': '192',
  'AR': '107',
  'CL': '131',
  // Oceania
  'AU': '000',
  'NZ': '111',
};

/// The ambulance number for [countryCode], or 112 when it is unknown.
String emergencyNumberFor(String? countryCode) {
  if (countryCode == null) return fallbackEmergencyNumber;
  return ambulanceNumbers[countryCode.trim().toUpperCase()] ??
      fallbackEmergencyNumber;
}

/// Where the country came from, best first.
enum CountrySource { location, network, sim, unknown }

/// The country the SOS screens call for, and the number to dial there.
class EmergencyNumber {
  const EmergencyNumber._(this.countryCode, this.source);

  const EmergencyNumber.unknown()
      : countryCode = null,
        source = CountrySource.unknown;

  /// Upper-case ISO 3166-1 alpha-2 code, or null when unknown.
  final String? countryCode;
  final CountrySource source;

  String get number => emergencyNumberFor(countryCode);

  @override
  String toString() => 'EmergencyNumber($countryCode, ${source.name}, $number)';
}

/// What the device can tell about the country, kept behind an interface so
/// the logic can be tested without a phone. [DeviceCountryAccess] is the
/// real one.
abstract class CountryAccess {
  /// The country of the mobile network the phone is on now, which follows
  /// the phone abroad. Works without internet or location permission.
  Future<String?> networkCountry();

  /// The country that issued the SIM card. Wrong when roaming, so it is
  /// used only after the network.
  Future<String?> simCountry();

  /// The last position the phone already knows, only if the location
  /// permission was granted earlier. Never asks for it.
  Future<({double latitude, double longitude})?> lastKnownPosition();

  /// The country that contains a point, from borders built into the app.
  Future<String?> countryAt(double latitude, double longitude);
}

class DeviceCountryAccess implements CountryAccess {
  DeviceCountryAccess();

  static const _channel = MethodChannel('mata/telephony');

  @override
  Future<String?> networkCountry() =>
      _channel.invokeMethod<String>('networkCountryIso');

  @override
  Future<String?> simCountry() =>
      _channel.invokeMethod<String>('simCountryIso');

  @override
  Future<({double latitude, double longitude})?> lastKnownPosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    return (latitude: position.latitude, longitude: position.longitude);
  }

  /// The borders take up to a second to parse, so they are parsed once, off
  /// the main thread, and shared by every later lookup.
  static Future<CountryCoder>? _coder;

  static Future<CountryCoder> _loadCoder() {
    return _coder ??= () async {
      final coder = CountryCoder.instance;
      if (!coder.ready) {
        try {
          coder.load(await compute(CountryCoder.prepareData, null));
        } catch (_) {
          _coder = null; // let a later lookup try again
          rethrow;
        }
      }
      return coder;
    }();
  }

  @override
  Future<String?> countryAt(double latitude, double longitude) async {
    final coder = await _loadCoder();
    return coder.iso1A2Code(lon: longitude, lat: latitude);
  }
}

/// Works out which emergency number the SOS screens should offer.
///
/// The best answer is the GPS fix (from the alert or the last known
/// position), then the mobile network's country, then the SIM card's
/// country, then 112. Nothing is sent anywhere and nothing is stored. No step throws; a
/// step that fails is skipped.
class EmergencyNumberResolver {
  EmergencyNumberResolver({CountryAccess? access})
      : _access = access ?? DeviceCountryAccess();

  final CountryAccess _access;

  /// Called when the SOS screen opens, before the alert's own fix exists.
  ///
  /// Gives the network or SIM answer first, because it is instant, and
  /// then the answer from the last known position if there is one, because
  /// the borders take a moment to load.
  Stream<EmergencyNumber> resolve() async* {
    final network = _clean(await _try(_access.networkCountry));
    final sim = network == null ? _clean(await _try(_access.simCountry)) : null;
    yield network != null
        ? EmergencyNumber._(network, CountrySource.network)
        : sim != null
            ? EmergencyNumber._(sim, CountrySource.sim)
            : const EmergencyNumber.unknown();

    final position = await _try(_access.lastKnownPosition);
    if (position != null) {
      final fromGps =
          await fromPosition(position.latitude, position.longitude);
      if (fromGps != null) yield fromGps;
    }
  }

  /// The country at a GPS fix, or null when the point is outside every
  /// country (for example at sea) or the lookup fails.
  Future<EmergencyNumber?> fromPosition(
    double latitude,
    double longitude,
  ) async {
    final code =
        _clean(await _try(() => _access.countryAt(latitude, longitude)));
    return code == null
        ? null
        : EmergencyNumber._(code, CountrySource.location);
  }

  static Future<T?> _try<T>(Future<T?> Function() step) async {
    try {
      return await step();
    } catch (_) {
      return null;
    }
  }

  /// Accepts only a two-letter code, upper-cased.
  static String? _clean(String? code) {
    final value = code?.trim().toUpperCase();
    if (value == null || !RegExp(r'^[A-Z]{2}$').hasMatch(value)) return null;
    return value;
  }
}
