cd flutter_app

flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

adb logcat | grep -E "ScreencastPlugin|SCREENCAST"

export PATH="/home/eren/.flutter-sdk/bin:$PATH" && cd /home/eren/GitHub/dungeon-master-tool/flutter_app && flutter run -d linux