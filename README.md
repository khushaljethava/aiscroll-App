# aiscroll

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



### Running the Flutter app against this admin

```bash
# iOS simulator — localhost reaches the host
flutter run --dart-define=ADMIN_API_URL=https://aiscroll-admin-admin.vercel.app

# Android emulator — 10.0.2.2 is the special host loopback
flutter run --dart-define=ADMIN_API_URL=https://aiscroll-admin-admin.vercel.app

# Physical device — use your machine's LAN IP (make sure your firewall lets :3000 through)
flutter run --dart-de