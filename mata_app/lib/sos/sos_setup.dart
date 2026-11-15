import '../services/emergency_contact_service.dart';
import 'location_service.dart';
import 'sos_controller.dart';
import 'sos_sender.dart';
import 'android_sms_sender.dart';

/// Builds the sender the SOS screen uses.
///
/// Real Android SMS is the default. Enable simulation explicitly with
/// --dart-define=SOS_TEST_MODE=true (including on emulators).
SosSender createSosSender() => const bool.fromEnvironment('SOS_TEST_MODE')
    ? StubSosSender()
    : AndroidSmsSender();

/// Whether [sender] is the stand-in that sends nothing. The result screen
/// says so, so that a test run is never mistaken for a real alert.
bool isTestSender(SosSender sender) => sender is StubSosSender;

/// Wires one SOS activation to the location service and to the default
/// contact saved by the emergency contacts service.
SosController createSosController({
  SosSender? sender,
  LocationService? locationService,
  EmergencyContactService? contactService,
}) {
  final contacts = contactService ?? EmergencyContactService();

  return SosController(
    sender: sender ?? createSosSender(),
    locationService: locationService ?? LocationService(),
    loadDefaultContact: contacts.getDefaultContact,
  );
}
