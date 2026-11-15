# Android SIM SMS proof of concept

This debug-only experiment is separate from the Ma’ta SOS flow. It shares the
native dispatcher with production SOS but retains its manual recipient and
confirmation screen. There is no startup send or automatic retry.

## Physical phone procedure

1. Use an Android phone with an active SIM, SMS allowance/credit and cellular
   coverage. Enable USB debugging and authorize the development computer.
2. In Android SIM settings select the default **SMS** SIM. On dual-SIM devices,
   select the intended SIM explicitly instead of “ask every time”. The proof of
   concept refuses to send if Android reports no valid default subscription.
3. Run `flutter devices`, then
   `flutter run --debug -d <device-id> -t lib/sms_poc_main.dart`.
4. Manually enter an authorized recipient's international number, beginning
   with `+` and country code. No recipient number is prefilled or saved.
5. Enter the test message and check the recipient authorization checkbox.
6. Tap **Send real test SMS**, review the destination, and confirm **Send real SMS**.
7. Grant Android SMS permission. If permanently denied, grant it in Android app
   settings and return to the form. No dispatch occurs when permission is denied.
8. Wait for the result (up to 60 seconds). “Android reported successful sending”
   means all send callbacks succeeded; it does **not** confirm delivery/receipt.
   Independently check the recipient's physical phone for actual receipt.
9. The form locks after a send request. Before intentionally restarting the test
   app for another send, check the recipient phone, especially after partial or
   unknown outcomes. Restarting creates a new attempt and can send another SMS.

To return to Ma’ta, stop this run and use `flutter run -t lib/main.dart`.
Do not distribute this proof of concept as a production SMS implementation.

## Manual checks

- Deny SMS permission: no dispatch; explanatory result.
- Cancel confirmation: no permission request or dispatch.
- No SIM/default SMS subscription: controlled failure; select/enable a SIM.
- Airplane mode/no cellular service: native no-service/radio-off result, or
  unknown if the device does not provide callbacks before timeout.
- Long ASCII and Unicode messages: multipart send and one aggregated result.
- Dual SIM: independently confirm the selected default SIM is used.
- Repeated taps: one dispatch; the form remains locked afterward.
- Interruption/recreation: no automatic resend; missing callbacks mean unknown.
- Emulator: useful for UI/failure checks only, never proof of carrier delivery.

## Implementation limits

`mata/sms_poc` is gated natively to debuggable builds. The original
`mata/telephony` channel is retained. Production SOS uses `mata/sms` and requests
SMS permission before its countdown. In this experiment, permission is requested
only by the explicit test action. No read-SMS, receive-SMS,
contacts, phone-state or delivery-report permission is requested.

The bridge calls SmsManager directly, splits messages using divideMessage and
aggregates per-part sent callbacks. No delivery callback is supplied. Carrier
charges and Android/carrier confirmation rules still apply.

Attempt IDs and statuses alone are stored in private preferences before dispatch;
phone numbers and message bodies are not stored there. Android may record sent
messages in the system messaging provider. Duplicate attempt IDs never dispatch
again, including after process death. A concurrent distinct attempt is rejected.
There is no general exactly-once guarantee for an intentionally new attempt.
Timeout/process interruption is conservatively unknown; no automatic retries.
Native deduplication/real carrier behavior require physical-device verification.
