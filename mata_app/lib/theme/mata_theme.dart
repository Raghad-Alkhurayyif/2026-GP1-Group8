import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared colours, type and surfaces for the Ma'ta look.
class MataColors {
  static const Color brown = Color(0xFF79543B);
  static const Color cocoa = Color(0xFF5C3F38);
  static const Color ink = Color(0xFF3A2823);
  static const Color sand = Color(0xFFDCCDB5);
  static const Color cream = Color(0xFFF7F3EB);
  static const Color softWhite = Color(0xFFFFFBF7);
  static const Color sos = Color(0xFFB71616);
  static const Color hint = Color(0xFF8C7F77);
  static const Color muted = Color(0xFF6E564A);
  static const Color faint = Color(0xFF8A7468);
  static const Color amber = Color(0xFFC98A3C);
}

class MataText {
  /// Headings: Reem Kufi, as in the original app.
  static TextStyle display({
    double fontSize = 27,
    Color color = MataColors.ink,
    FontWeight fontWeight = FontWeight.w700,
    double height = 1.2,
  }) {
    return GoogleFonts.reemKufi(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  /// Body text: IBM Plex Sans Arabic, which reads well in English and Arabic.
  static TextStyle body({
    double fontSize = 14,
    Color color = MataColors.ink,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.5,
    TextDecoration? decoration,
    double? letterSpacing,
  }) {
    return GoogleFonts.ibmPlexSansArabic(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      decoration: decoration,
      decorationColor: color,
      letterSpacing: letterSpacing,
    );
  }
}

/// A frosted panel used on the light screens inside the app.
class MataGlass extends StatelessWidget {
  const MataGlass({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.opacity = 0.78,
    this.glow = false,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final bool glow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: MataColors.cocoa.withValues(alpha: glow ? 0.32 : 0.22),
            blurRadius: glow ? 50 : 34,
            spreadRadius: -20,
            offset: Offset(0, glow ? 24 : 14),
          ),
          if (glow)
            const BoxShadow(
              color: Color(0x66FFF4E4),
              blurRadius: 80,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: MataColors.softWhite.withValues(alpha: opacity),
              borderRadius: shape,
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.8),
                width: borderColor == null ? 1 : 2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A dark frosted sheet used on the twilight screens (sign in, sign up).
class MataNightSheet extends StatelessWidget {
  const MataNightSheet({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 26, 22, 22),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(30);

    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF120D0C).withValues(alpha: 0.5),
            borderRadius: shape,
            border: Border.all(
              color: MataColors.softWhite.withValues(alpha: 0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Primary and secondary buttons in the shared style.
class MataButton extends StatelessWidget {
  const MataButton({
    required this.label,
    required this.onPressed,
    this.style = MataButtonStyle.brown,
    this.loading = false,
    this.height = 52,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final MataButtonStyle style;
  final bool loading;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, BorderSide side, List<BoxShadow> shadow) =
        switch (style) {
          MataButtonStyle.brown => (
            MataColors.brown,
            MataColors.softWhite,
            BorderSide.none,
            [
              BoxShadow(
                color: MataColors.cocoa.withValues(alpha: 0.8),
                blurRadius: 24,
                spreadRadius: -12,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          MataButtonStyle.cream => (
            MataColors.softWhite,
            MataColors.cocoa,
            BorderSide.none,
            const <BoxShadow>[],
          ),
          MataButtonStyle.ghost => (
            MataColors.softWhite.withValues(alpha: 0.03),
            MataColors.softWhite,
            BorderSide(color: MataColors.softWhite.withValues(alpha: 0.26)),
            const <BoxShadow>[],
          ),
          MataButtonStyle.line => (
            Colors.transparent,
            MataColors.brown,
            BorderSide(
              color: MataColors.brown.withValues(alpha: 0.4),
              width: 1.5,
            ),
            const <BoxShadow>[],
          ),
          MataButtonStyle.danger => (
            MataColors.sos,
            MataColors.softWhite,
            BorderSide.none,
            [
              BoxShadow(
                color: MataColors.sos.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: -10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        };

    return Opacity(
      opacity: onPressed == null && !loading ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: shadow,
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: TextButton(
            onPressed: loading ? null : onPressed,
            style: TextButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledForegroundColor: fg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: side,
              ),
            ),
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: fg,
                      strokeWidth: 2.4,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 19, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: MataText.body(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

enum MataButtonStyle { brown, cream, ghost, line, danger }

/// Field styles: [light] for the screens inside the app, [night] for twilight.
class MataFields {
  static InputDecoration light({
    String? hintText,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    return _decoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      fill: Colors.white.withValues(alpha: 0.6),
      border: MataColors.brown.withValues(alpha: 0.18),
      focus: MataColors.brown,
      hint: const Color(0xFF9C8B80),
    );
  }

  static InputDecoration night({String? hintText, Widget? suffixIcon}) {
    return _decoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      fill: MataColors.softWhite.withValues(alpha: 0.09),
      border: MataColors.softWhite.withValues(alpha: 0.18),
      focus: const Color(0xFFE9C7A0),
      hint: MataColors.softWhite.withValues(alpha: 0.42),
      error: const Color(0xFFFF9C8C),
    );
  }

  static InputDecoration _decoration({
    required Color fill,
    required Color border,
    required Color focus,
    required Color hint,
    Color error = MataColors.sos,
    String? hintText,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hintText,
      hintStyle: MataText.body(color: hint, fontSize: 15),
      errorStyle: MataText.body(color: error, fontSize: 12, height: 1.3),
      errorMaxLines: 3,
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      enabledBorder: outline(border),
      focusedBorder: outline(focus, 1.5),
      errorBorder: outline(error),
      focusedErrorBorder: outline(error, 1.5),
      disabledBorder: outline(border.withValues(alpha: 0.1)),
    );
  }
}

/// A small field label.
class MataLabel extends StatelessWidget {
  const MataLabel(this.text, {this.night = false, super.key});

  final String text;
  final bool night;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: MataText.body(
          fontSize: 12.5,
          letterSpacing: 0.4,
          color: night
              ? MataColors.softWhite.withValues(alpha: 0.72)
              : MataColors.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// The round back button used on screens without a logo bar.
class MataBackButton extends StatelessWidget {
  const MataBackButton({required this.onTap, this.night = false, super.key});

  final VoidCallback onTap;
  final bool night;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: night
          ? MataColors.softWhite.withValues(alpha: 0.1)
          : MataColors.brown.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 17,
            color: night ? MataColors.softWhite : MataColors.ink,
          ),
        ),
      ),
    );
  }
}

/// The original logo, drawn exactly where the original home screen draws it:
/// flush with the left edge, its glowing tail running out of the screen.
class MataCornerLogo extends StatelessWidget {
  const MataCornerLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-28, -17),
      // A copy pre-scaled to 4x the size it is shown at, so every screen
      // does not decode and shrink the 6432 px original. The offset reaches
      // into the screen margin: a parent that clips (a Stack does by
      // default) cuts the logo off, so such parents need Clip.none.
      child: Image.asset(
        'assets/images/mata_logo_corner.png',
        width: 90,
        height: 55,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
