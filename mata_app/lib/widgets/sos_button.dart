import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SosButton extends StatelessWidget {
  const SosButton({
    required this.onTap,
    super.key,
  });

  final VoidCallback onTap;

  static const Color red = Color(0xFFB71616);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: red,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 66,
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.phone_in_talk_outlined,
                color: Colors.white,
                size: 25,
              ),
              Text(
                'SOS',
                style: GoogleFonts.reemKufi(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}