import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

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

  /// Whether selecting this contact as the default would replace another.
  final bool hasDefault;

  @override
  State<EmergencyContactFormScreen> createState() =>
      _EmergencyContactFormScreenState();
}

class _EmergencyContactFormScreenState
    extends State<EmergencyContactFormScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.contact?.name ?? '');
  static final _countryCodes = {
    for (final code in IsoCode.values) code.name: code,
  };

  late final _savedNumber = _readSavedNumber();
  late Country? _country = Country.tryParse(_savedNumber?.isoCode.name ?? '');
  late final TextEditingController _phone = TextEditingController(
    text: _country == null
        ? widget.contact?.phoneNumber ?? ''
        : _savedNumber?.formatNsn(),
  );

  bool _makeDefault = false;
  bool _saving = false;
  String? _nameError;
  String? _phoneError;
  String? _formError;

  bool get _editing => widget.contact != null;

  PhoneNumber? _readSavedNumber() {
    final phone = widget.contact?.phoneNumber;
    if (phone == null || phone.isEmpty) return null;

    try {
      return PhoneNumber.parse(phone);
    } on PhoneNumberException {
      return null;
    }
  }

  String _dialCode(Country country) {
    final isoCode = _countryCodes[country.countryCode]!;
    return PhoneNumber(isoCode: isoCode, nsn: '').countryCode;
  }

  void _pickCountry() {
    FocusScope.of(context).unfocus();
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      useSafeArea: true,
      countryFilter: _countryCodes.keys.toList(),
      countryListTheme: CountryListThemeData(
        backgroundColor: MataColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        bottomSheetHeight: MediaQuery.sizeOf(context).height * 0.8,
        textStyle: MataText.body(fontSize: 14),
        searchTextStyle: MataText.body(fontSize: 15),
        inputDecoration: MataFields.light(hintText: 'Search countries'),
      ),
      onSelect: (country) {
        setState(() {
          _country = country;
          _phoneError = null;
        });
      },
    );
  }

  Widget _buildCountryPrefix() {
    final country = _country;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _saving ? null : _pickCountry,
            style: TextButton.styleFrom(
              foregroundColor: MataColors.cocoa,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Semantics(
              label: country == null
                  ? 'Select country calling code'
                  : 'Change country calling code, ${country.name}, '
                      'plus ${_dialCode(country)}',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (country != null) ...[
                    Text(country.flagEmoji),
                    const SizedBox(width: 6),
                  ],
                  Text(country == null ? 'Code' : '+${_dialCode(country)}'),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: MataColors.brown.withValues(alpha: 0.18),
          ),
        ],
      ),
    );
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
    if (_saving) return;
    final country = _countryCodes[_country?.countryCode];
    if (country == null) {
      setState(() => _phoneError = 'Select a country first.');
      return;
    }

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
          widget.service.addContact(
            _name.text,
            _phone.text,
            country: country,
          ),
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
            country: country,
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
            final example = metadataExamplesByIsoCode[country]?.mobile;
            _phoneError = example == null || example.isEmpty
                ? '${error.message} Enter the local number without the country code.'
                : '${error.message} Example: '
                    '${PhoneNumber(isoCode: country, nsn: example).formatNsn()}.';
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
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MataCornerLogo(),
                  const SizedBox(height: 1),
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
                                hintText: 'Mobile number',
                                prefixIcon: _buildCountryPrefix(),
                              ).copyWith(
                                errorText: _phoneError,
                                errorMaxLines: 3,
                              ),
                            ),
                            if (_phoneError == null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'SOS sends a text message to this number.',
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
                      : 'Turn on to use this person as your default.',
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
