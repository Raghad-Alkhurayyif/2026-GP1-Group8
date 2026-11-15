import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../models/emergency_contact.dart';
import 'location_service.dart';
import 'sos_sender.dart';

/// One instance belongs to one SOS screen. Preparation never sends an SMS.
class AndroidSmsSender implements SosSender {
  AndroidSmsSender({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('mata/sms');

  final MethodChannel _channel;
  EmergencyContact? _contact;
  int? _subscription;
  Future<SosResult>? _dispatch;
  int _generation = 0;

  @override
  Future<SosResult?> prepare(EmergencyContact contact) async {
    final generation = ++_generation;
    _contact = null;
    _subscription = null;
    _dispatch = null;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _failure('unsupported_device');
    }
    try {
      final phone = PhoneNumber.parse(contact.phoneNumber);
      if (!contact.phoneNumber.startsWith('+') ||
          !phone.isValid(type: PhoneNumberType.mobile)) {
        return _failure('invalid_contact');
      }
      _contact = contact.copyWith(phoneNumber: phone.international);
    } catch (_) {
      return _failure('invalid_contact');
    }
    try {
      final permission = await _channel.invokeMethod<String>(
        'requestPermission',
      );
      if (generation != _generation) return _failure('preparation_failed');
      if (permission != 'granted') {
        return _failure(
          permission == 'unsupported_device'
              ? permission!
              : 'permission_denied',
        );
      }
      final preparation = await _channel.invokeMapMethod<String, dynamic>(
        'prepare',
      );
      if (generation != _generation) return _failure('preparation_failed');
      if (preparation?['status'] != 'ready') {
        return _failure(
          preparation?['status'] as String? ?? 'preparation_failed',
        );
      }
      _subscription = preparation!['subscriptionId'] as int;
      return null;
    } catch (_) {
      return _failure('preparation_failed');
    }
  }

  SosResult _failure(String reason) => SosResult(
    outcome: SosOutcome.failed,
    contactName: _contact?.name,
    reason: reason,
    retryAllowed: true,
  );

  static String composeMessage(LocationResult location) =>
      'Ma’ta SOS: I need help. Please contact me immediately.\n'
      '${location.isAvailable ? 'My location: ${location.mapLink}' : 'My location is unavailable.'}';

  @override
  Future<SosResult> send({required LocationResult location}) =>
      _dispatch ??= _sendOnce(location);

  Future<SosResult> _sendOnce(LocationResult location) async {
    final contact = _contact;
    final subscription = _subscription;
    if (contact == null || subscription == null) {
      return _failure('not_prepared');
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    String? status;
    try {
      status = await _channel
          .invokeMethod<String>('send', {
            'attemptId': id,
            'recipient': contact.phoneNumber,
            'subscriptionId': subscription,
            'message': composeMessage(location),
          })
          .timeout(const Duration(seconds: 65), onTimeout: () => 'unknown');
    } catch (_) {
      status = 'unknown';
    }
    final outcome = switch (status) {
      'sent' => SosOutcome.sent,
      'partial' => SosOutcome.partial,
      'unknown' || null => SosOutcome.unknown,
      'no_service' => SosOutcome.noNetwork,
      'failed' ||
      'permission_denied' ||
      'unsupported_device' ||
      'no_default_sim' ||
      'sim_changed' ||
      'sim_not_ready' ||
      'no_sim' ||
      'invalid_arguments' ||
      'storage_error' ||
      'busy' => SosOutcome.failed,
      _ => SosOutcome.unknown,
    };
    return SosResult(
      outcome: outcome,
      contactName: contact.name,
      locationIncluded: location.isAvailable,
      reason: status,
      retryAllowed: const {
        'permission_denied',
        'unsupported_device',
        'no_default_sim',
        'sim_changed',
        'sim_not_ready',
        'invalid_arguments',
        'storage_error',
        'busy',
      }.contains(status),
    );
  }
}
