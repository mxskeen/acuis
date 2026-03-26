import 'dart:io';
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
      }
      return false;
    } catch (e) {
      print('Error setting wallpaper: $e');
      return false;
    }
  }

  Future<bool> _setAndroidWallpaper(String imagePath) async {
    try {
      final result = await platform.invokeMethod('setWallpaper', {'path': imagePath});
      return result == true;
    } catch (e) {
      print('Android wallpaper error: $e');
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
      print('Windows wallpaper error: $e');
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
      print('Linux wallpaper error: $e');
      return false;
    }
  }
}
