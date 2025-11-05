import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import '../models/device_info.dart';

class ClassicClient {
  fbs.BluetoothConnection? _conn;
  final StreamController<Uint8List> _data = StreamController.broadcast();
  Stream<Uint8List> get data => _data.stream;
  StreamSubscription? _discSub;

  Future<void> ensureEnabled() async {
    final fbs.FlutterBluetoothSerial bt = fbs.FlutterBluetoothSerial.instance;
    if ((await bt.isEnabled) != true) {
      await bt.requestEnable();
    }
  }

  Future<void> startDiscovery(
    void Function(List<DeviceInfo>) onResults, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final map = <String, DeviceInfo>{};
    await ensureEnabled();

    try {
      final bonded = await fbs.FlutterBluetoothSerial.instance.getBondedDevices();
      for (final b in bonded) {
        if (b.address.isNotEmpty) {
          final nm = (b.name != null && b.name!.isNotEmpty) ? b.name! : 'Paired Device';
          map[b.address] = DeviceInfo(
            id: b.address,
            name: nm,
            type: LinkType.classic,
            isPaired: true,
          );
        }
      }
      if (map.isNotEmpty) onResults(map.values.toList());
    } catch (e) {
      debugPrint('Failed to get bonded devices: $e');
    }

    _discSub = fbs.FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      final d = r.device;
      if (d.address.isNotEmpty) {
        final prev = map[d.address];
        final nm = (d.name != null && d.name!.isNotEmpty)
            ? d.name!
            : (prev?.name ?? 'Unknown Device');
        map[d.address] = DeviceInfo(
          id: d.address,
          name: nm,
          type: LinkType.classic,
          rssi: r.rssi,
          isPaired: prev?.isPaired ?? false,
        );
        onResults(map.values.toList());
      }
    });

    await Future<void>.delayed(timeout);
    await _discSub?.cancel();
    _discSub = null;
  }

  Future<void> connect(String address) async {
    await ensureEnabled();
    try {
      await _conn?.close();
      _conn = null;

      _conn = await fbs.BluetoothConnection.toAddress(address)
          .timeout(const Duration(seconds: 15));

      _conn!.input?.listen(
        (data) => _data.add(Uint8List.fromList(data)),
        onDone: () => _conn = null,
        onError: (Object error) {
          _conn = null;
          _data.addError(error);
        },
      );
    } catch (e) {
      await _conn?.close();
      _conn = null;
      rethrow;
    }
  }

  Future<bool?> pair(String address, {String? pin}) async {
    await ensureEnabled();
    try {
      return await fbs.FlutterBluetoothSerial.instance
          .bondDeviceAtAddress(address, pin: pin);
    } catch (e) {
      debugPrint('Pairing failed: $e');
      return false;
    }
  }

  Future<bool?> unpair(String address) async {
    try {
      return await fbs.FlutterBluetoothSerial.instance
          .removeDeviceBondWithAddress(address);
    } catch (e) {
      debugPrint('Unpairing failed: $e');
      return false;
    }
  }

  Future<void> write(Uint8List bytes) async {
    final c = _conn;
    if (c == null || !c.isConnected) {
      throw Exception('Classic Bluetooth not connected');
    }
    c.output.add(bytes);
    await c.output.allSent;
  }

  Future<void> disconnect() async {
    await _discSub?.cancel();
    _discSub = null;
    await _conn?.close();
    _conn = null;
  }

  void dispose() {
    _data.close();
    disconnect();
  }
}
