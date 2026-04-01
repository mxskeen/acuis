import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

/// Tiny Habits Loop Dialog
///
/// After completing a todo, show immediate prompt: "Add one more?"
/// Implements BJ Fogg's Tiny Habits: Celebration → Action → Celebration loop
void showTinyHabitsPrompt(
  BuildContext context, {
  required VoidCallback onAddAnother,
  required VoidCallback onDone,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Great job!',
              style: GoogleFonts.comfortaa(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep the momentum going',
              style: GoogleFonts.comfortaa(
                fontSize: 13,
                color: AppColors.inkLight,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      onDone();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.chip,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Done',
                          style: GoogleFonts.comfortaa(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      onAddAnother();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Add one more',
                          style: GoogleFonts.comfortaa(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
