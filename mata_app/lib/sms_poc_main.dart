import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Launch explicitly with flutter run --debug -t lib/sms_poc_main.dart.
void main() => runApp(const MaterialApp(home: SmsPocScreen()));

class SmsPocScreen extends StatefulWidget {
  const SmsPocScreen({super.key});

  @override
  State<SmsPocScreen> createState() => _SmsPocScreenState();
}

class _SmsPocScreenState extends State<SmsPocScreen> {
  static const _channel = MethodChannel('mata/sms_poc');
  final _recipient = TextEditingController();
  final _message = TextEditingController(text: 'Ma’ta authorized SMS test.');
  bool _authorized = false;
  bool _busy = false;
  bool _attempted = false;
  String _status = 'No SMS has been sent.';

  Future<void> _send() async {
    if (_busy || _attempted || !_authorized) return;
    final recipient = _recipient.text.trim();
    final message = _message.text.trim();
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(recipient) ||
        message.isEmpty ||
        message.length > 2000) {
      setState(
        () => _status =
            'Enter an international number starting with + '
            'and a message of 1–2000 characters.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send a real SMS?'),
        content: Text(
          'Send this test to $recipient using your default SMS SIM? '
          'Carrier charges may apply. Long messages use multiple SMS parts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send real SMS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy || _attempted) return;
    setState(() {
      _busy = true;
      _status = 'Checking SMS permission…';
    });
    try {
      final permission = await _channel.invokeMethod<String>(
        'requestPermission',
      );
      if (permission != 'granted') {
        if (mounted) {
          setState(
            () => _status =
                'SMS permission denied or unavailable. '
                'No send requested. Grant SMS permission in Android app settings if needed.',
          );
        }
        return;
      }
      // Lock the form before crossing the channel. No automatic retries.
      if (mounted) {
        setState(() {
          _attempted = true;
          _status = 'Waiting for Android send results…';
        });
      }
      final random = Random.secure();
      final attemptId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final result = await _channel.invokeMethod<String>('send', {
        'attemptId': attemptId,
        'recipient': recipient,
        'message': message,
      });
      if (mounted) setState(() => _status = smsPocStatus(result));
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _status =
              'Platform error (${error.code}). '
              'If sending began, the outcome is unknown. Do not assume nothing was sent.',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        setState(
          () => _status =
              'Android SMS bridge unavailable. Use a debug Android build.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _recipient.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        kDebugMode &&
        defaultTargetPlatform == TargetPlatform.android &&
        !kIsWeb;
    return Scaffold(
      appBar: AppBar(title: const Text('SIM SMS proof of concept')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Real SMS test — separate from SOS. Requires an active SIM and '
            'an authorized recipient. Nothing sends on startup. Delivery is not tracked.',
          ),
          if (!supported)
            const Text('Available only in a debug Android build.'),
          TextField(
            controller: _recipient,
            enabled: !_busy && !_attempted,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Authorized recipient (+country code and number)',
            ),
          ),
          TextField(
            controller: _message,
            enabled: !_busy && !_attempted,
            maxLength: 2000,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Test message'),
          ),
          CheckboxListTile(
            value: _authorized,
            title: const Text(
              'I have permission to send this recipient a real test SMS.',
            ),
            onChanged: _busy || _attempted
                ? null
                : (value) => setState(() => _authorized = value ?? false),
          ),
          FilledButton(
            onPressed: supported && _authorized && !_busy && !_attempted
                ? _send
                : null,
            child: const Text('Send real test SMS'),
          ),
          const SizedBox(height: 16),
          Text(_status, key: const Key('sms-status')),
          if (_attempted)
            const Text(
              'This test form is locked to prevent repeat sends. '
              'Check the recipient phone before intentionally restarting the test app for another attempt.',
            ),
        ],
      ),
    );
  }
}

String smsPocStatus(String? status) => switch (status) {
  'no_sim' =>
    'Android reported no available SIM. Enable or insert an active SMS SIM.',
  'sent' =>
    'Android reported successful sending for every SMS part. '
        'Submission/send success only: delivery and recipient receipt are NOT confirmed.',
  'partial' => 'Some SMS parts were sent; others failed. Delivery is not confirmed. Do not automatically retry.',
  'no_service' => 'Android reported unavailable cellular service or radio off. Delivery is not confirmed.',
  'permission_denied' =>
    'SMS permission is missing. No successful send confirmed.',
  'no_default_sim' => 'No valid default SMS SIM. Insert/enable a SIM and select the default SMS SIM in Android settings. On dual-SIM phones, choose explicitly.',
  'unsupported_device' => 'This device does not support SIM SMS sending.',
  'invalid_arguments' => 'Invalid recipient or message. No send requested.',
  'busy' => 'Another SMS attempt is in progress. No additional send requested.',
  'storage_error' => 'Could not save duplicate protection. No send requested.',
  'failed' => 'Android reported a send failure. Delivery is not confirmed.',
  _ => 'Send outcome unknown (timeout or interruption). Some or all parts may have been sent. Do not automatically retry.',
};
