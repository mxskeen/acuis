import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

/// In-App Update Service
///
/// Handles checking for Play Store updates and prompting users to update.
/// Only works on Android (Play Store).
class InAppUpdateService {
  static final InAppUpdateService _instance = InAppUpdateService._internal();
  factory InAppUpdateService() => _instance;
  InAppUpdateService._internal();

  /// Check for update availability
  Future<void> checkForUpdate(BuildContext context) async {
    // Only run on Android
    if (!Platform.isAndroid) return;

    try {
      // Check if update is available
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Show update dialog
        if (context.mounted) {
          _showUpdateDialog(context, info);
        }
      }
    } catch (e) {
      // Silently fail - user experience shouldn't be affected
      debugPrint('In-app update check failed: $e');
    }
  }

  /// Perform immediate update (download and install)
  Future<void> performImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('Immediate update failed: $e');
    }
  }

  /// Start flexible update (downloads in background)
  Future<void> startFlexibleUpdate() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();

      if (result == AppUpdateResult.success) {
        // Update downloaded, prompt to restart
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('Flexible update failed: $e');
    }
  }

  /// Show update dialog to user
  void _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.system_update, color: AppColors.accent, size: 28),
            const SizedBox(width: 12),
            Text('Update Available',
                style: GoogleFonts.comfortaa(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of acuis is available with improvements and bug fixes.',
              style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink, height: 1.5),
            ),
            const SizedBox(height: 12),
            if (info.immediateUpdateAllowed)
              Text(
                'We recommend updating to the latest version for the best experience.',
                style: GoogleFonts.comfortaa(fontSize: 12, color: AppColors.inkLight),
              ),
          ],
        ),
        actions: [
          // Later button (only show if not critical)
          if (info.immediateUpdateAllowed)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Later',
                  style: GoogleFonts.comfortaa(
                      fontSize: 14, color: AppColors.inkLight, fontWeight: FontWeight.w600)),
            ),

          // Update button
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Perform immediate update
              if (info.immediateUpdateAllowed) {
                await performImmediateUpdate();
              } else if (info.flexibleUpdateAllowed) {
                await startFlexibleUpdate();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Update Now',
                style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Check for update on app start (non-blocking)
  void checkForUpdateAsync(BuildContext context) {
    // Delay check to avoid blocking startup
    Future.delayed(const Duration(seconds: 3), () {
      if (context.mounted) {
        checkForUpdate(context);
      }
    });
  }
}
