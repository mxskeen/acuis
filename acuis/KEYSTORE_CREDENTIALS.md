# Release Keystore Credentials

**IMPORTANT: Keep this file secure and never commit it to version control!**

## Keystore Details
- **File Location**: `android/app/release.keystore`
- **Key Alias**: `acuis-release`
- **Store Password**: `acuis2024secure`
- **Key Password**: `acuis2024secure`

## Building Release APK

To build a signed release APK:

```bash
flutter clean
flutter build apk --release
```

The signed APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Building Release App Bundle (for Play Store)

To build a signed app bundle for Play Store:

```bash
flutter clean
flutter build appbundle --release
```

The signed bundle will be at: `build/app/outputs/bundle/release/app-release.aab`

## Security Notes

1. **Backup your keystore!** Keep a secure copy of `release.keystore` - if you lose it, you won't be able to update your app on Play Store
2. **Never commit** the keystore or credentials to version control
3. Both `.keystore` and `key.properties` are in `.gitignore`

## Updating the App

1. Build a new signed release APK/bundle using the same keystore
2. Install/update on device - users won't get "package conflict" errors
3. Upload to Play Store - must use the same keystore for all updates
