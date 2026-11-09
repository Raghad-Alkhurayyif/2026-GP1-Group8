import '../services/emergency_contact_service.dart';
import 'location_service.dart';
import 'sos_controller.dart';
import 'sos_sender.dart';

/// The number the SOS screens offer to call when the alert cannot reach the
/// default contact (PBI-21, PBI-24). 997 is the Saudi Red Crescent ambulance.
const String emergencyServicesNumber = '997';

/// Builds the sender the SOS screen uses.
///
/// The real SMS sender (PBI-20, PBI-21) plugs in here: replace
/// [StubSosSender] with it. Nothing else in the screens needs to change.
SosSender createSosSender() => StubSosSender();

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
    loadDefaultContactName: () async =>
        (await contacts.getDefaultContact())?.name,
  );
}
