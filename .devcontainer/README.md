## Dev Container Commands Run

This file tracks the commands run during setup in this workspace.

### 1) Open folder in DevContainer 
```
Ctrl+Shift+P

### 2) Enable Flutter desktop targets

```bash
flutter config --enable-linux-desktop --enable-macos-desktop --enable-windows-desktop
```

### 3) Create Flutter app (all smartphone + desktop platforms)

```bash
flutter create --platforms=android,ios,linux,macos,windows my_flutter_app
```

### 4) Run the project

```bash
cd /workspaces/SIP-app/my_flutter_app
flutter pub get
flutter devices
flutter run -d <deviceId>
```

