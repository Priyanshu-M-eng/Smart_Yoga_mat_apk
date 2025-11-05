# Smart Yoga Mat App 🧘‍♀️

A production-ready Flutter mobile application for connecting to ESP32-based smart yoga mats via **Bluetooth Low Energy (BLE GATT)** and **Classic Bluetooth (SPP)**. Features robust connection management, auto-reconnect, real-time data streaming, and a modern Material 3 UI.

---

## 📱 Features

### Core Functionality
- ✅ **Dual Bluetooth Support**: BLE (GATT) and Classic Bluetooth (SPP)
- ✅ **Device Discovery & Pairing**: Scan for nearby devices with signal strength indicators
- ✅ **Robust Connection Management**: Auto-reconnect with exponential backoff
- ✅ **Real-time Data Streaming**: Bidirectional communication with the yoga mat
- ✅ **Background Continuity**: Reconnects automatically when app resumes
- ✅ **Connection Statistics**: Track data rate, bytes transferred, uptime, and reconnection attempts

### User Interface
- 🎨 **Modern Material 3 Design**: Beautiful gradient app bar and card-based layout
- 🌗 **Light & Dark Mode Support**: System-aware theming
- 📱 **Responsive Layout**: Adapts to phones and tablets
- 📊 **Connection Stats Dashboard**: Real-time monitoring of connection quality
- 💬 **Interactive Console**: Send commands and view responses in real-time
- ⚙️ **Settings Panel**: Configure auto-reconnect and view device UUIDs

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK ≥ 3.9.0
- Android Studio / VS Code
- Android device or emulator (API level 21+)
- ESP32 device with Bluetooth configured

### Installation

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run the app**:
   ```bash
   flutter run
   ```

3. **Build APK**:
   ```bash
   flutter build apk --release
   ```

---

## 🔧 Configuration

### ESP32 Bluetooth UUIDs

Update the BLE service/characteristic UUIDs in `lib/services/ble_client.dart` to match your ESP32:

```dart
static final serviceUuid = fbp.Guid('0000ffff-0000-1000-8000-00805f9b34fb');
static final rxCharUuid = fbp.Guid('0000ff01-0000-1000-8000-00805f9b34fb');
static final txCharUuid = fbp.Guid('0000ff02-0000-1000-8000-00805f9b34fb');
```

---

## 📖 Usage

### Connecting to Your Yoga Mat

1. Launch the app and grant Bluetooth/Location permissions
2. Select connection mode: BLE (GATT) or Classic (SPP)
3. Tap "Scan Devices" to discover nearby devices
4. Tap on your yoga mat in the device list to connect
5. Monitor connection via the status indicator

### Sending Commands

Navigate to the **Console** tab:
- Enter commands (e.g., `LED:ON`, `STATUS`)
- Tap **Send** to transmit to the device
- View incoming data in real-time
- Use preset buttons for common commands

---

## 🐛 Troubleshooting

### Device Not Found
- Ensure Bluetooth is enabled
- Grant Location permissions (required for BLE scanning)
- Check ESP32 is advertising

### Connection Fails
- Verify ESP32 is powered on
- Check UUIDs match your ESP32 configuration
- For Classic Bluetooth, pair in phone settings first

---

**Built with ❤️ using Flutter**
