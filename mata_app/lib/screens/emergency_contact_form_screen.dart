import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';
import '../services/contact_exception.dart';
import '../services/emergency_contact_service.dart';
import '../theme/mata_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/stroke_background.dart';
import 'emergency_contacts_screen.dart';

/// Adds a contact, or edits one when [contact] is given (PBI-17, PBI-18).
/// Pops with a short confirmation message once the change is saved.
class EmergencyContactFormScreen extends StatefulWidget {
  const EmergencyContactFormScreen({
    required this.service,
    required this.hasDefault,
    this.contact,
    super.key,
  });

  final EmergencyContactService service;
  final EmergencyContact? contact;

  /// Whether a default SOS contact is already chosen. If not, the new
  /// contact is offered as the default, with the switch already on.
  final bool hasDefault;

  @override
  State<EmergencyContactFormScreen> createState() =>
      _EmergencyContactFormScreenState();
}

class _EmergencyContactFormScreenState
    extends State<EmergencyContactFormScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.contact?.name ?? '');
  late final TextEditingController _phone = TextEditingController(
    text: _localPhone(widget.contact?.phoneNumber ?? ''),
  );

  late bool _makeDefault = !widget.hasDefault;
  bool _saving = false;
  String? _nameError;
  String? _phoneError;
  String? _formError;

  bool get _editing => widget.contact != null;

  /// Saved numbers are +9665XXXXXXXX; the field shows the familiar 05...
  static String _localPhone(String phone) {
    if (RegExp(r'^\+9665\d{8}$').hasMatch(phone)) {
      return '0${phone.substring(4)}';
    }
    return phone;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_nameError == null && _phoneError == null && _formError == null) {
      return;
    }
    setState(() {
      _nameError = null;
      _phoneError = null;
      _formError = null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _nameError = null;
      _phoneError = null;
      _formError = null;
    });

    try {
      final String message;
      final contact = widget.contact;

      if (contact == null) {
        final id = await withContactTimeout(
          widget.service.addContact(_name.text, _phone.text),
        );
        if (_makeDefault) {
          final name = _name.text.trim();
          try {
            await withContactTimeout(widget.service.setDefault(id));
            message = '$name was added as your default SOS contact.';
          } catch (_) {
            // The contact is saved; only the default failed. Leave the form
            // so a retry does not report the number as a duplicate.
            if (mounted) {
              Navigator.pop(
                context,
                '$name was added, but could not be made your default. '
                'Tap them to try again.',
              );
            }
            return;
          }
        } else {
          message = '${_name.text.trim()} was added.';
        }
      } else {
        await withContactTimeout(
          widget.service.updateContact(
            contact.copyWith(name: _name.text, phoneNumber: _phone.text),
          ),
        );
        message = 'Your changes were saved.';
      }

      if (mounted) Navigator.pop(context, message);
    } on ContactException catch (error) {
      if (!mounted) return;
      // The entered details stay in the fields so the user can retry.
      setState(() {
        _saving = false;
        switch (error.type) {
          case ContactErrorType.emptyName:
            _nameError = error.message;
          case ContactErrorType.emptyPhone:
            _phoneError = error.message;
          case ContactErrorType.invalidPhone:
            _phoneError = 'Please enter a Saudi mobile number, for example '
                '05X XXX XXXX or +966 5X XXX XXXX.';
          case ContactErrorType.duplicatePhone:
            _phoneError = 'A contact with this number already exists.';
          case ContactErrorType.notFound:
          case ContactErrorType.notSignedIn:
          case ContactErrorType.network:
          case ContactErrorType.unknown:
            _formError = error.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = const ContactException(ContactErrorType.unknown).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MataColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const StrokeBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MataCornerLogo(),
                  const SizedBox(height: 5),
                  MataBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(height: 14),
                  Text(
                    _editing ? 'Edit Contact' : 'Add Contact',
                    style: MataText.display(fontSize: 26),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: MataGlass(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MataLabel('Name'),
                            TextField(
                              controller: _name,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => _clearErrors(),
                              style: MataText.body(
                                color: MataColors.cocoa,
                                fontSize: 15,
                              ),
                              decoration: MataFields.light(
                                hintText: 'Contact name',
                              ).copyWith(errorText: _nameError),
                            ),
                            const SizedBox(height: 14),
                            const MataLabel('Mobile Number'),
                            TextField(
                              controller: _phone,
                              enabled: !_saving,
                              keyboardType: TextInputType.phone,
                              onChanged: (_) => _clearErrors(),
                              onSubmitted: (_) => _save(),
                              style: MataText.body(
                                color: MataColors.cocoa,
                                fontSize: 15,
                              ),
                              decoration: MataFields.light(
                                hintText: '05X XXX XXXX',
                              ).copyWith(errorText: _phoneError),
                            ),
                            if (_phoneError == null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'A Saudi mobile number. SOS sends a text '
                                'message to it.',
                                style: MataText.body(
                                  color: MataColors.faint,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (!_editing) ...[
                              const SizedBox(height: 16),
                              _DefaultSwitch(
                                value: _makeDefault,
                                replacesDefault: widget.hasDefault,
                                onChanged: _saving
                                    ? null
                                    : (value) =>
                                        setState(() => _makeDefault = value),
                              ),
                            ],
                            if (_formError != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _formError!,
                                style: MataText.body(
                                  color: MataColors.sos,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            MataButton(
                              label: _editing ? 'Save Changes' : 'Save Contact',
                              loading: _saving,
                              onPressed: _saving ? null : _save,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: 12, right: 22),
                child: SosButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultSwitch extends StatelessWidget {
  const _DefaultSwitch({
    required this.value,
    required this.replacesDefault,
    required this.onChanged,
  });

  final bool value;
  final bool replacesDefault;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MataColors.brown.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default SOS contact',
                  style: MataText.body(
                    color: MataColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                Text(
                  replacesDefault
                      ? 'Turn on to alert this person instead of your '
                          'current default.'
                      : 'SOS will alert this person.',
                  style: MataText.body(
                    color: MataColors.faint,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: MataColors.softWhite,
            activeTrackColor: MataColors.brown,
            inactiveThumbColor: MataColors.softWhite,
            inactiveTrackColor: MataColors.brown.withValues(alpha: 0.2),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
