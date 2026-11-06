import 'location_service.dart';

/// How a send attempt ended (PBI-20, PBI-21, PBI-24).
enum SosOutcome { sent, failed, noDefaultContact, noNetwork }

class SosResult {
  const SosResult({
    required this.outcome,
    this.contactName,
    this.locationIncluded = false,
  });

  final SosOutcome outcome;

  /// The default contact the alert was addressed to, for the result screen.
  final String? contactName;

  /// Whether the message carried a map link (PBI-24, AC 1).
  final bool locationIncluded;

  bool get wasSent => outcome == SosOutcome.sent;

  @override
  String toString() =>
      'SosResult(${outcome.name}, $contactName, location: $locationIncluded)';
}

/// Sends the emergency SMS. Deem's package (PBI-20, PBI-21) implements this.
///
/// The SOS controller calls [send] once when the countdown ends or the user
/// presses "Send now", and again only if the user presses Retry. It never
/// calls it after a cancel or an interruption.
///
/// [location] has already been fetched within the 5-second limit while the
/// countdown was running, so [send] does not need to wait for a fix. When
/// [LocationResult.isAvailable] is false the message should say that the
/// location is unavailable (PBI-21, AC 2 and 4); [LocationResult.mapLink]
/// gives the link when it is available.
///
/// [send] should not throw. If it does, the controller treats it as
/// [SosOutcome.failed].
abstract class SosSender {
  Future<SosResult> send({required LocationResult location});
}

/// Stand-in until the real sender is ready, so the SOS screens can be built
/// and tried. It sends nothing.
class StubSosSender implements SosSender {
  StubSosSender({
    this.outcome = SosOutcome.sent,
    this.contactName = 'Test contact',
    this.delay = const Duration(milliseconds: 800),
  });

  final SosOutcome outcome;
  final String? contactName;
  final Duration delay;

  @override
  Future<SosResult> send({required LocationResult location}) async {
    await Future<void>.delayed(delay);
    return SosResult(
      outcome: outcome,
      contactName: contactName,
      locationIncluded: outcome == SosOutcome.sent && location.isAvailable,
    );
  }
}
