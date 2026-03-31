import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

class AlignmentScreen extends StatelessWidget {
  const AlignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alignment',
                      style: GoogleFonts.comfortaa(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.1,
                      )),
                  const SizedBox(height: 3),
                  Text('How your work connects to your goals',
                      style: GoogleFonts.comfortaa(
                          fontSize: 12, color: AppColors.inkLight)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/illustrations/ballet-dancer.svg',
                      width: 200,
                    ),
                    const SizedBox(height: 20),
                    Text('Insights coming soon',
                        style: GoogleFonts.comfortaa(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkLight,
                        )),
                    const SizedBox(height: 4),
                    Text('Add goals and todos to see your alignment',
                        style: GoogleFonts.comfortaa(
                            fontSize: 12, color: AppColors.inkFaint)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
