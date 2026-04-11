cd flutter_app

flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

adb logcat | grep -E "ScreencastPlugin|SCREENCAST"