# SOS Android SMS integration

Normal app: `flutter run -d <phone-id> -t lib/main.dart`.
This now sends real SIM SMS after the SOS countdown. Use an authorized test
contact and a physical Android phone with active SIM, SMS credit, and coverage.
Select the intended default SMS SIM in Android settings before activating SOS.
Dual-SIM “ask every time” configurations without a valid default are refused;
Ma’ta never silently chooses slot 0 or changes the selected SIM mid-countdown.

Explicit simulation (including emulator development):

```
flutter run -t lib/main.dart --dart-define=SOS_TEST_MODE=true
```

Simulation retains the Firestore default-contact check and location flow, but
uses StubSosSender and never requests SMS permission or dispatches native SMS.
The countdown and success screen identify test mode. Do a full restart/rebuild
when changing this compile-time flag. There is no fallback from real SMS to
simulated success.

## Flow and safety

- Load the signed-in user's default contact through EmergencyContactService.
  Validate the saved international mobile number with phone_numbers_parser;
  freeze that immutable recipient for this activation, including safe retries.
- Request SEND_SMS, then prepare/check the configured default SMS subscription
  and SIM readiness before the countdown. Missing permission/SIM/device support
  produces existing-style result feedback and emergency-call fallback.
- Preserve location explanation/permission and the five-second countdown.
  Compose a short help request plus LocationResult.mapLink, or explicitly state
  that location is unavailable. No new location persistence is introduced.
- Countdown completion and Send Now enter the same guarded send path. While an
  outstanding bounded location request completes, Cancel/backgrounding still
  invalidates the activation. Only then does native dispatch become irreversible.
- Native code rechecks permission and rejects a changed default SMS SIM before
  dispatch. Both channels share one dispatcher and persistent attempt-ID records.
- Sender caches its send future so duplicate calls cannot produce a second SMS.
  Native storage contains IDs/statuses, not contact numbers or message bodies.
- Successful sent callbacks mean Android reported sending all parts, never
  delivery/receipt. Partial callbacks and timeout/interruption have distinct
  feedback and no retry action. Unexpected channel errors are unknown.
- Only known pre-dispatch failures offer Try Again; this repeats preparation
  and countdown with the same recipient. No automatic retries occur, even for
  native failed/no-service callbacks. An intentionally new SOS activation is a
  new alert and can send again; there is no global exactly-once delivery claim.

The production `mata/sms` channel is available in release builds. The separate
`mata/sms_poc` channel retains its debug-only gate and manual confirmation.
`mata/telephony` remains unchanged. No SMS composer is opened by SOS.

## Verification on a physical Android phone

1. Sign in, save an authorized recipient and select them as the default contact.
2. Activate SOS, grant SMS permission, complete location permission if prompted.
   Verify the countdown starts only after SMS preparation.
3. Cancel before expiry: verify no SMS arrives. Repeat with Send Now while a
   location fix is delayed, cancelling before dispatch. Background the countdown
   and verify cancellation. Do not interpret cancellation as recalling an SMS
   already dispatched to the modem.
4. Activate again and let the five seconds expire; separately check Send Now.
   Each should send once without a messaging app or second send confirmation.
5. Check the receiving physical phone for actual receipt and the map link.
   Repeat with location denied/off; the message must state location unavailable.
6. Deny SMS permission, disable/remove/lock the SIM, and test a missing default
   on dual SIM. Verify controlled feedback and the call fallback. Switch the
   default SIM during countdown: no SMS should dispatch on the new SIM.
7. Verify partial/unknown outcomes with mocked tests; do not intentionally send
   repeated alerts to reproduce them. Never infer receipt from send callbacks.
8. Confirm the separate `lib/sms_poc_main.dart` debug entry point still works.

Emulator and mocked tests do not prove carrier delivery. Real sending,
multipart carrier behavior, SIM selection and permissions need physical-device
verification. Existing Google Play SMS-permission declaration requirements still
apply to distribution; this change does not grant policy approval.
