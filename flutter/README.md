# SearchTeach Flutter

## Run web and Windows together

From the project root, double-click `start-searchteach.bat` in File Explorer.
Alternatively, open the project in VS Code, select **SearchTeach (Web + Windows)**
in **Run and Debug**, and press F5.

You can also run the script from PowerShell:

```powershell
.\start-searchteach.ps1
```

This starts the backend with Docker Compose, opens Flutter Web in Chrome at
`http://localhost:5001`, and launches the Windows desktop app. Flutter
dependencies must be installed first with `flutter pub get` from this directory.
For the Windows target, enable Windows Developer Mode so Flutter can create the
required symlinks. The backend image is rebuilt on each launch while reusing
Docker's build cache, so source changes do not require manually clearing caches.
The Android Gradle configuration also limits build memory and reuses its build
cache.

To start only one frontend, use `.\start-searchteach.ps1 -Frontend web` or
`.\start-searchteach.ps1 -Frontend windows`. The backend API is at
`http://localhost:8080`.

## Run on a phone

First start the backend from the project root with `docker compose up -d app`.
Connect an Android phone over USB with USB debugging enabled, or start an Android
emulator from Android Studio. Run `flutter devices` to find its device ID.

From this directory, start the app on an emulator:

```powershell
flutter run -d <device-id>
```

The default API address `http://10.0.2.2:8080` points from the Android emulator
to the backend on the development PC. The Android debug manifest permits local
HTTP traffic for development only.

For a physical phone, connect the phone and PC to the same Wi-Fi, allow inbound
connections to port 8080 through the PC firewall, then pass the PC's LAN address:

```powershell
$flutterPath = (Get-Command flutter).Source
$fileSystem = New-Object -ComObject Scripting.FileSystemObject
$flutterPath = $fileSystem.GetFile($flutterPath).ShortPath
& $flutterPath run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.20:8080
```

Replace the example address with the PC's actual LAN IP. Keep the backend running
on the PC; the phone talks to its API, while the backend connects to Atlas and
cloud Redis. For iOS, use the Mac's LAN IP and run Flutter from macOS.
