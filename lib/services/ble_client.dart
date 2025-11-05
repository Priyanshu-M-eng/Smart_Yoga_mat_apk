import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../models/device_info.dart';

class BleClient {
  // TODO: replace with your Yoga Mat service/characteristic UUIDs
  static final serviceUuid = fbp.Guid('0000ffff-0000-1000-8000-00805f9b34fb');
  static final rxCharUuid = fbp.Guid('0000ff01-0000-1000-8000-00805f9b34fb'); // notify
  static final txCharUuid = fbp.Guid('0000ff02-0000-1000-8000-00805f9b34fb'); // write
  static const int desiredMtu = 247;

  fbp.BluetoothDevice? _device;
  fbp.BluetoothCharacteristic? _rx;
  fbp.BluetoothCharacteristic? _tx;
  final StreamController<Uint8List> _data = StreamController.broadcast();
  StreamSubscription? _connectionSubscription;

  Stream<Uint8List> get data => _data.stream;
  bool get isConnected => _device != null;

  Future<Uint8List?> readOnce() async {
    final rx = _rx;
    if (rx == null) return null;
    try {
      final v = await rx.read();
      final b = Uint8List.fromList(v);
      _data.add(b);
      return b;
    } catch (_) {
      return null;
    }
  }

  Future<void> startScan(
    void Function(List<DeviceInfo>) onResults, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final results = <String, DeviceInfo>{};

    if (kIsWeb) {
      debugPrint('Web platform: Bluetooth scanning not supported');
      onResults([]);
      return;
    }

    try {
      await fbp.FlutterBluePlus.startScan(timeout: timeout);
      final sub = fbp.FlutterBluePlus.scanResults.listen((list) {
        for (final r in list) {
          final d = r.device;
          final advName = r.advertisementData.advName.trim();
          final platName = d.platformName;
          final name = advName.isNotEmpty
              ? advName
              : (platName.isNotEmpty ? platName : 'Unknown BLE');
          results[d.remoteId.str] = DeviceInfo(
            id: d.remoteId.str,
            name: name,
            type: LinkType.ble,
            rssi: r.rssi,
          );
        }
        onResults(results.values.toList());
      });

      await Future<void>.delayed(timeout);
      await fbp.FlutterBluePlus.stopScan();
      await sub.cancel();
    } catch (e) {
      debugPrint('BLE scan error: $e');
      await fbp.FlutterBluePlus.stopScan();
      rethrow;
    }
  }

  Future<void> connect(
    String id, {
    bool autoConnect = true,
    void Function(String)? onDisconnect,
  }) async {
    if (kIsWeb) {
      throw Exception('Bluetooth connections not supported on web');
    }

    fbp.BluetoothDevice? dev;
    try {
      dev = fbp.BluetoothDevice.fromId(id);
      _device = dev;

      // Monitor connection state
      _connectionSubscription = dev.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          onDisconnect?.call('Device disconnected');
        }
      });

      await dev.connect(
        license: fbp.License.free,
        autoConnect: autoConnect,
        mtu: autoConnect ? null : desiredMtu,
        timeout: const Duration(seconds: 15),
      );

      final services = await dev.discoverServices();
      for (final s in services) {
        if (s.uuid == serviceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == rxCharUuid) _rx = c;
            if (c.uuid == txCharUuid) _tx = c;
          }
        }
      }

      if (_rx == null || _tx == null) {
        throw Exception('Required BLE characteristics not found. Please check service UUIDs.');
      }

      if (autoConnect) {
        try {
          await dev.requestMtu(desiredMtu);
        } catch (e) {
          debugPrint('MTU negotiation failed: $e');
        }
      }

      await _rx!.setNotifyValue(true);
      _rx!.onValueReceived.listen((value) => _data.add(Uint8List.fromList(value)));
    } catch (e) {
      await dev?.disconnect();
      _device = null;
      _rx = null;
      _tx = null;
      await _connectionSubscription?.cancel();
      rethrow;
    }
  }

  Future<void> write(Uint8List bytes) async {
    final t = _tx;
    if (t == null) throw Exception('BLE not connected');
    await t.write(bytes, withoutResponse: true);
  }

  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    final d = _device;
    _device = null;
    _rx = null;
    _tx = null;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (e) {
        debugPrint('Disconnect error: $e');
      }
    }
  }

  void dispose() {
    _data.close();
    disconnect();
  }
}
