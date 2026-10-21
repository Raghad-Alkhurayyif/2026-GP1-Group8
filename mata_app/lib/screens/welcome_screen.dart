import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color brown = Color(0xFF79543B);
  static const Color softWhite = Color(0xFFFFFBF7);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/welcome_background.png',
            fit: BoxFit.cover,
          ),

          Positioned(
            top: screenSize.height * 0.09,
            right: -screenSize.width * 0.003,
            child: SizedBox(
              width: screenSize.width * 1,
              child: Image.asset(
                'assets/images/mata_logo.png',
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Positioned(
            top: screenSize.height * 0.405,
            left: 0,
            right: 0,
            child: Text(
              'Welcome',
              textAlign: TextAlign.center,
              style: GoogleFonts.reemKufi(
                color: softWhite,
                fontSize: 36,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Positioned(
            top: screenSize.height * 0.505,
            left: 52,
            right: 52,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 66,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignInScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: softWhite,
                      side: const BorderSide(color: softWhite, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(33),
                      ),
                    ),
                    child: Text(
                      'SIGN IN',
                      style: GoogleFonts.reemKufi(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 66,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: softWhite,
                      foregroundColor: brown,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(33),
                      ),
                    ),
                    child: Text(
                      'SIGN UP',
                      style: GoogleFonts.reemKufi(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
