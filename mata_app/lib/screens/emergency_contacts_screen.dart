import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';
import '../services/contact_exception.dart';
import '../services/emergency_contact_service.dart';
import '../theme/mata_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/stroke_background.dart';
import 'emergency_contact_form_screen.dart';

/// Shows a saved number as +966 5X XXX XXXX.
String formatContactPhone(String phone) {
  final match = RegExp(r'^\+966(5\d)(\d{3})(\d{4})$').firstMatch(phone);
  if (match == null) return phone;
  return '+966 ${match[1]} ${match[2]} ${match[3]}';
}

/// How long a contacts request may take before the screen reports a
/// connection problem instead of waiting.
const Duration contactRequestLimit = Duration(seconds: 15);

Future<T> withContactTimeout<T>(Future<T> request) {
  return request.timeout(
    contactRequestLimit,
    onTimeout: () => throw const ContactException(ContactErrorType.network),
  );
}

/// The list of emergency contacts (PBI-17, PBI-18).
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({this.service, super.key});

  /// Left out in the app; passed in for previews.
  final EmergencyContactService? service;

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  static const String _introSeenKey = 'contacts.introSeen';

  late final EmergencyContactService _service =
      widget.service ?? EmergencyContactService();

  List<EmergencyContact>? _contacts;
  String? _loadError;
  bool _showIntro = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadIntroFlag();
    _load();
  }

  Future<void> _loadIntroFlag() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final seen = preferences.getBool(_introSeenKey) ?? false;
      if (mounted && !seen) setState(() => _showIntro = true);
    } catch (_) {
      // Without storage the explanation simply is not shown.
    }
  }

  Future<void> _dismissIntro() async {
    setState(() => _showIntro = false);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_introSeenKey, true);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final contacts = await withContactTimeout(_service.getContacts());
      if (!mounted) return;
      setState(() => _contacts = contacts);
    } on ContactException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _loadError =
            const ContactException(ContactErrorType.unknown).message,
      );
    }
  }

  EmergencyContact? get _defaultContact {
    for (final contact in _contacts ?? const <EmergencyContact>[]) {
      if (contact.isDefault) return contact;
    }
    return null;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: MataText.body(color: MataColors.softWhite),
          ),
          backgroundColor: MataColors.cocoa,
        ),
      );
  }

  Future<void> _openForm({EmergencyContact? contact}) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EmergencyContactFormScreen(
          service: _service,
          contact: contact,
          hasDefault: _defaultContact != null,
        ),
      ),
    );
    if (message == null || !mounted) return;
    _showMessage(message);
    await _load();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await withContactTimeout(action());
      if (!mounted) return;
      _showMessage(done);
      await _load();
    } on ContactException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(const ContactException(ContactErrorType.unknown).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setDefault(EmergencyContact contact) {
    return _run(
      () => _service.setDefault(contact.id),
      '${contact.name} is now your default SOS contact.',
    );
  }

  Future<void> _confirmRemove(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RemoveContactDialog(contact: contact),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _service.deleteContact(contact.id),
      contact.isDefault
          ? '${contact.name} was removed. Choose a new default SOS contact.'
          : '${contact.name} was removed.',
    );
  }

  Future<void> _openActions(EmergencyContact contact) async {
    final action = await showModalBottomSheet<_ContactAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactActionsSheet(contact: contact),
    );
    if (!mounted) return;
    switch (action) {
      case _ContactAction.makeDefault:
        await _setDefault(contact);
      case _ContactAction.edit:
        await _openForm(contact: contact);
      case _ContactAction.remove:
        await _confirmRemove(contact);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts;

    return Scaffold(
      backgroundColor: MataColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const StrokeBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MataCornerLogo(),
                  const SizedBox(height: 5),
                  MataBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(height: 14),
                  Text(
                    'Emergency Contacts',
                    style: MataText.display(fontSize: 26),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: _loadError != null && contacts == null
                        ? _LoadError(message: _loadError!, onRetry: _load)
                        : contacts == null
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: MataColors.cocoa,
                                ),
                              )
                            : _buildContent(contacts),
                  ),
                  if (contacts != null && contacts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    MataButton(
                      label: 'Add Contact',
                      icon: Icons.add_rounded,
                      onPressed: _busy ? null : () => _openForm(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x14000000),
                child: Center(
                  child: CircularProgressIndicator(color: MataColors.cocoa),
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

  Widget _buildContent(List<EmergencyContact> contacts) {
    final defaultContact = _defaultContact;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (_showIntro) ...[
          _IntroCard(onDismiss: _dismissIntro),
          const SizedBox(height: 16),
        ],
        if (contacts.isEmpty)
          _EmptyState(onAdd: () => _openForm())
        else ...[
          _DefaultStatus(contact: defaultContact),
          const SizedBox(height: 22),
          const _SectionTitle(text: 'SAVED CONTACTS'),
          const SizedBox(height: 10),
          MataGlass(
            padding: EdgeInsets.zero,
            radius: 18,
            child: Column(
              children: [
                for (var i = 0; i < contacts.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: MataColors.brown.withValues(alpha: 0.12),
                    ),
                  _ContactRow(
                    contact: contacts[i],
                    onTap: _busy ? null : () => _openActions(contacts[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Tap a contact to edit it, remove it or make it your default.',
              style: MataText.body(
                color: MataColors.faint,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MataGlass(
      glow: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: MataColors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'How SOS uses your contacts',
                style: MataText.body(
                  color: MataColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You can save several people here. When you press SOS, '
            'Ma’ta alerts only one of them: the contact you choose in '
            'advance as your default.',
            style: MataText.body(color: MataColors.muted, fontSize: 13.5),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              child: Text(
                'Got it',
                style: MataText.body(
                  color: MataColors.brown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Says who SOS will alert, or that it will alert nobody.
class _DefaultStatus extends StatelessWidget {
  const _DefaultStatus({required this.contact});

  final EmergencyContact? contact;

  @override
  Widget build(BuildContext context) {
    final contact = this.contact;

    if (contact == null) {
      return MataGlass(
        radius: 18,
        borderColor: MataColors.sos.withValues(alpha: 0.35),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.error_outline_rounded,
                color: MataColors.sos,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No default SOS contact',
                    style: MataText.body(
                      color: MataColors.sos,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SOS cannot notify anyone until you choose one. '
                    'Tap a contact below to make it your default.',
                    style: MataText.body(
                      color: MataColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return MataGlass(
      radius: 18,
      glow: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          const _Initial(letterSource: null, lit: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOS WILL ALERT',
                  style: MataText.body(
                    color: MataColors.faint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    height: 1.3,
                  ),
                ),
                Text(
                  contact.name,
                  overflow: TextOverflow.ellipsis,
                  style: MataText.body(
                    color: MataColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                Text(
                  formatContactPhone(contact.phoneNumber),
                  style: MataText.body(
                    color: MataColors.muted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onTap});

  final EmergencyContact contact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            _Initial(letterSource: contact.name, lit: contact.isDefault),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.name,
                          overflow: TextOverflow.ellipsis,
                          style: MataText.body(
                            color: MataColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (contact.isDefault) ...[
                        const SizedBox(width: 8),
                        const _DefaultBadge(),
                      ],
                    ],
                  ),
                  Text(
                    formatContactPhone(contact.phoneNumber),
                    style: MataText.body(
                      color: MataColors.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.more_horiz_rounded,
              color: MataColors.faint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: MataColors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MataColors.amber.withValues(alpha: 0.45)),
      ),
      child: Text(
        'Default',
        style: MataText.body(
          color: const Color(0xFF9A6524),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.3,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// A round mark with the contact's first letter. The default contact's mark
/// is lit, like a lamp on the path.
class _Initial extends StatelessWidget {
  const _Initial({required this.letterSource, required this.lit});

  final String? letterSource;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final source = letterSource?.trim() ?? '';
    final letter = source.isEmpty ? null : source.characters.first;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: lit
            ? const RadialGradient(
                colors: [Color(0xFFFFF1D6), Color(0xFFE7B871)],
              )
            : null,
        color: lit ? null : MataColors.brown.withValues(alpha: 0.1),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: MataColors.amber.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: letter == null
          ? Icon(
              Icons.shield_outlined,
              size: 19,
              color: lit ? const Color(0xFF7A4E1E) : MataColors.brown,
            )
          : Text(
              letter.toUpperCase(),
              style: MataText.display(
                fontSize: 17,
                color: lit ? const Color(0xFF7A4E1E) : MataColors.brown,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return MataGlass(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MataColors.brown.withValues(alpha: 0.08),
            ),
            child: const Icon(
              Icons.person_add_alt_outlined,
              color: MataColors.brown,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No emergency contacts yet',
            textAlign: TextAlign.center,
            style: MataText.display(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'SOS cannot notify anyone until you add a contact and choose '
            'them as your default.',
            textAlign: TextAlign.center,
            style: MataText.body(color: MataColors.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 18),
          MataButton(
            label: 'Add Contact',
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MataGlass(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your contacts could not be loaded',
              textAlign: TextAlign.center,
              style: MataText.body(
                color: MataColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MataText.body(color: MataColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            MataButton(
              label: 'Try Again',
              style: MataButtonStyle.line,
              height: 46,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: MataText.body(
          color: MataColors.faint,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

enum _ContactAction { makeDefault, edit, remove }

class _ContactActionsSheet extends StatelessWidget {
  const _ContactActionsSheet({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    Widget option(
      IconData icon,
      String label,
      _ContactAction action, {
      Color color = MataColors.ink,
    }) {
      return InkWell(
        onTap: () => Navigator.pop(context, action),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(width: 14),
              Text(
                label,
                style: MataText.body(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: MataColors.softWhite,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: MataText.display(fontSize: 20),
                  ),
                  Text(
                    formatContactPhone(contact.phoneNumber),
                    style: MataText.body(color: MataColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (!contact.isDefault)
              option(
                Icons.star_outline_rounded,
                'Make default SOS contact',
                _ContactAction.makeDefault,
                color: const Color(0xFF9A6524),
              ),
            option(Icons.edit_outlined, 'Edit', _ContactAction.edit),
            option(
              Icons.delete_outline_rounded,
              'Remove',
              _ContactAction.remove,
              color: MataColors.sos,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RemoveContactDialog extends StatelessWidget {
  const _RemoveContactDialog({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MataColors.softWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Remove ${contact.name}?',
        style: MataText.display(fontSize: 21, color: MataColors.cocoa),
      ),
      content: Text(
        contact.isDefault
            ? '${contact.name} is your default SOS contact. After removing '
                'them, SOS cannot notify anyone until you choose another '
                'default yourself. Ma’ta will not choose one for you.'
            : '${contact.name} will be removed from your emergency contacts. '
                'Your default SOS contact stays the same.',
        style: MataText.body(color: MataColors.brown, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: MataText.body(color: MataColors.brown)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Remove',
            style: MataText.body(
              color: MataColors.sos,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
