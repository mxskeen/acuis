class UserSettings {
  final String wallpaperPath;
  final double blurLevel;
  final bool autoUpdateWallpaper;

  UserSettings({
    required this.wallpaperPath,
    this.blurLevel = 10.0,
    this.autoUpdateWallpaper = true,
  });

  Map<String, dynamic> toJson() => {
        'wallpaperPath': wallpaperPath,
        'blurLevel': blurLevel,
        'autoUpdateWallpaper': autoUpdateWallpaper,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        wallpaperPath: json['wallpaperPath'],
        blurLevel: json['blurLevel']?.toDouble() ?? 10.0,
        autoUpdateWallpaper: json['autoUpdateWallpaper'] ?? true,
      );

  UserSettings copyWith({
    String? wallpaperPath,
    double? blurLevel,
    bool? autoUpdateWallpaper,
  }) =>
      UserSettings(
        wallpaperPath: wallpaperPath ?? this.wallpaperPath,
        blurLevel: blurLevel ?? this.blurLevel,
        autoUpdateWallpaper: autoUpdateWallpaper ?? this.autoUpdateWallpaper,
      );
}
