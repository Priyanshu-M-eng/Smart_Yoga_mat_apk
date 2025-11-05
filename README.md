# Smart Yoga Mat POC (Flutter)

Prototype mobile app that connects to an ESP32-based smart yoga mat over Classic Bluetooth (SPP) and Bluetooth Low Energy (BLE), streams basic data, sends commands, and keeps the connection stable (auto-reconnect, retries, timeouts, background resume).

## What it demonstrates
- Device discovery and pairing
  - BLE scan with live advertisement names
  - Classic scan + one-tap Pair for SPP devices
- Data exchange
  - BLE GATT: notify stream (RX), write (TX), optional read-once
  - Classic SPP: simple text/byte stream
- Connection wrapper (state machine)
  - Disconnected → Connecting → Connected → Retrying → Error
  - Auto-reconnect with backoff (x3), retry on drops, resume on app foreground
- Simple, clean UI
  - Devices list, status chip, reconnect/pair buttons
  - Console to view RX/TX lines, Send command box, quick Read (BLE)

## ESP32 expectations
- BLE service/characteristics: update these to match your firmware in `lib/main.dart`:
  - `BleClient.serviceUuid` (default: 0000ffff-0000-1000-8000-00805f9b34fb)
  - `BleClient.rxCharUuid` (notify/read)
  - `BleClient.txCharUuid` (write without response)
- Classic SPP: expose a serial stream at 9600/115200 etc.; newline-delimited messages recommended.

## Build & Run
1) Install Flutter SDK and platform toolchains.
2) Fetch deps:
```
flutter pub get
```
3) Android (recommended for testing Classic + BLE):
```
flutter run
# or release APK
flutter build apk --release
```
4) iOS:
- Open `ios/Runner.xcworkspace` in Xcode
- Ensure a signing team is set, build to a real device (Bluetooth not available on Simulator)
- Usage strings are included in Info.plist (Bluetooth)

Permissions (Android):
- Android 12+: BLUETOOTH_SCAN / BLUETOOTH_CONNECT requested at runtime
- <= Android 11: Bluetooth + Location permissions requested

## How to use
1) Choose Mode: BLE (GATT) or Classic (SPP)
2) Scan → select your yoga mat device
3) For Classic, tap Pair if needed, then Connect (tap device)
4) Use the Console:
   - Enter a command (e.g. `LED:ON`) and Send
   - For BLE, you can also Read (single GATT read on RX)
5) Observe RX/TX lines; app auto-reconnects on drops and resumes after returning to foreground.

## Notes
- Device names in BLE come from advertisement data; if you see "Unknown", ensure the ESP32 advertises a name.
- Classic names improve after pairing; you can pair inside the app or from system settings.
- Tweak retry/backoff in `ConnectionManager` if you need more aggressive recovery.

## Deliverables (for submission)
- GitHub repo: push this project
- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Short demo video (≤3 min) showing:
  - Scanning (BLE + Classic), selecting device, pairing (Classic)
  - Connecting, streaming RX data
  - Sending a command
  - Connection drop + auto-reconnect, app resume behavior
