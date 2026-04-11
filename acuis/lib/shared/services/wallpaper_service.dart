import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WallpaperService {
  static const platform = MethodChannel('com.truenorth.acuis/wallpaper');

  Future<bool> setWallpaper(String imagePath) async {
    try {
      if (Platform.isAndroid) {
        return await _setAndroidWallpaper(imagePath);
      } else if (Platform.isWindows) {
        return await _setWindowsWallpaper(imagePath);
      } else if (Platform.isLinux) {
        return await _setLinuxWallpaper(imagePath);
      } else if (Platform.isMacOS) {
        return await _setMacOSWallpaper(imagePath);
      } else if (Platform.isIOS) {
        // iOS doesn't allow programmatic wallpaper changes
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('Error setting wallpaper: $e');
      return false;
    }
  }

  Future<bool> _setAndroidWallpaper(String imagePath) async {
    try {
      final result = await platform.invokeMethod('setWallpaper', {'path': imagePath});
      return result == true;
    } catch (e) {
      debugPrint('Android wallpaper error: $e');
      return false;
    }
  }

  Future<bool> _setWindowsWallpaper(String imagePath) async {
    try {
      final result = await Process.run('reg', [
        'add',
        'HKEY_CURRENT_USER\\Control Panel\\Desktop',
        '/v',
        'Wallpaper',
        '/t',
        'REG_SZ',
        '/d',
        imagePath,
        '/f'
      ]);

      if (result.exitCode == 0) {
        await Process.run('RUNDLL32.EXE', [
          'user32.dll,UpdatePerUserSystemParameters',
          '1',
          'True'
        ]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Windows wallpaper error: $e');
      return false;
    }
  }

  Future<bool> _setLinuxWallpaper(String imagePath) async {
    try {
      // Try GNOME first
      final gnomeResult = await Process.run('gsettings', [
        'set',
        'org.gnome.desktop.background',
        'picture-uri',
        'file://$imagePath'
      ]);

      if (gnomeResult.exitCode == 0) return true;

      // Try KDE Plasma
      final kdeResult = await Process.run('qdbus', [
        'org.kde.plasmashell',
        '/PlasmaShell',
        'org.kde.PlasmaShell.evaluateScript',
        '''
        var allDesktops = desktops();
        for (i=0;i<allDesktops.length;i++) {
          d = allDesktops[i];
          d.wallpaperPlugin = "org.kde.image";
          d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
          d.writeConfig("Image", "file://$imagePath");
        }
        '''
      ]);

      return kdeResult.exitCode == 0;
    } catch (e) {
      debugPrint('Linux wallpaper error: $e');
      return false;
    }
  }

  Future<bool> _setMacOSWallpaper(String imagePath) async {
    try {
      // Use osascript to set wallpaper on macOS
      final result = await Process.run('osascript', [
        '-e',
        'tell application "System Events" to set picture of every desktop to POSIX file "$imagePath"'
      ]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('macOS wallpaper error: $e');
      return false;
    }
  }
}
