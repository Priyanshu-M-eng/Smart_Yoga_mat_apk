import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_info.dart';
import 'ble_client.dart';
import 'classic_client.dart';

class ConnectionManager extends ChangeNotifier {
  final ble = BleClient();
  final classic = ClassicClient();

  ConnState _state = ConnState.disconnected;
  String? _error;
  DeviceInfo? _device;
  LinkType? _mode;
  ConnectionStats _stats = ConnectionStats();

  final StreamController<Uint8List> _data = StreamController.broadcast();
  StreamSubscription? _bleSub;
  StreamSubscription? _classicSub;
  Timer? _retryTimer;
  Timer? _statsTimer;

  int _retries = 0;
  final int _maxRetries = 3;
  bool _autoReconnect = true;

  // Getters
  ConnState get state => _state;
  String? get error => _error;
  DeviceInfo? get device => _device;
  LinkType? get mode => _mode;
  ConnectionStats get stats => _stats;
  Stream<Uint8List> get data => _data.stream;
  bool get autoReconnect => _autoReconnect;

  set autoReconnect(bool value) {
    _autoReconnect = value;
    notifyListeners();
  }

  Future<void> initPermissions() async {
    if (kIsWeb) {
      debugPrint('Web platform: Bluetooth permissions not applicable');
      return;
    }

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> scan(LinkType type, void Function(List<DeviceInfo>) onResults) async {
    _state = ConnState.scanning;
    _error = null;
    notifyListeners();

    try {
      if (type == LinkType.ble) {
        await ble.startScan(onResults);
      } else {
        if (kIsWeb) {
          debugPrint('Web: Classic Bluetooth not supported');
          onResults([]);
        } else {
          await classic.startDiscovery(onResults);
        }
      }
      _state = ConnState.disconnected;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _state = ConnState.error;
      notifyListeners();
    }
  }

  Future<void> connect(DeviceInfo target) async {
    _mode = target.type;
    _device = target;
    _state = ConnState.connecting;
    _error = null;
    notifyListeners();

    try {
      await _bleSub?.cancel();
      await _classicSub?.cancel();

      if (_mode == LinkType.ble) {
        await ble.connect(
          target.id,
          onDisconnect: (_) => _handleDisconnect(),
        );
        _bleSub = ble.data.listen(
          _onDataReceived,
          onDone: _handleDisconnect,
          onError: (Object e) {
            _error = e.toString();
            _handleDisconnect();
          },
        );
      } else {
        await classic.connect(target.id);
        _classicSub = classic.data.listen(
          _onDataReceived,
          onDone: _handleDisconnect,
          onError: (Object e) {
            _error = e.toString();
            _handleDisconnect();
          },
        );
      }

      _state = ConnState.connected;
      _retries = 0;
      _stats = ConnectionStats();
      _startStatsMonitoring();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _state = ConnState.error;
      notifyListeners();
      if (_autoReconnect) {
        _scheduleRetry();
      }
    }
  }

  void _onDataReceived(Uint8List data) {
    _data.add(data);
    _stats = _stats.copyWith(
      bytesReceived: _stats.bytesReceived + data.length,
    );
  }

  void _handleDisconnect() {
    if (_state == ConnState.connected) {
      _state = ConnState.retrying;
      _stopStatsMonitoring();
      notifyListeners();
      if (_autoReconnect) {
        _scheduleRetry();
      }
    }
  }

  void _scheduleRetry() {
    if (_device == null || !_autoReconnect) return;
    if (_retries >= _maxRetries) {
      _state = ConnState.error;
      _error = 'Max reconnection attempts reached';
      notifyListeners();
      return;
    }

    _retries += 1;
    final delay = Duration(seconds: 2 * _retries);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (_device != null && _autoReconnect) {
        connect(_device!);
      }
    });

    _stats = _stats.copyWith(reconnectAttempts: _stats.reconnectAttempts + 1);
  }

  void _startStatsMonitoring() {
    _statsTimer?.cancel();
    int lastBytes = 0;
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final currentBytes = _stats.bytesReceived;
      final rate = (currentBytes - lastBytes).toDouble();
      lastBytes = currentBytes;
      _stats = _stats.copyWith(dataRateBytesPerSecond: rate);
      notifyListeners();
    });
  }

  void _stopStatsMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> sendText(String text) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    if (_mode == LinkType.ble) {
      await ble.write(bytes);
    } else {
      await classic.write(bytes);
    }
    _stats = _stats.copyWith(bytesSent: _stats.bytesSent + bytes.length);
  }

  Future<Uint8List?> readOnce() async {
    if (_mode == LinkType.ble) {
      return await ble.readOnce();
    }
    return null;
  }

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    _stopStatsMonitoring();
    _state = ConnState.disconnected;
    _error = null;

    await _bleSub?.cancel();
    await _classicSub?.cancel();
    _bleSub = null;
    _classicSub = null;

    if (_mode == LinkType.ble) {
      await ble.disconnect();
    } else {
      await classic.disconnect();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _stopStatsMonitoring();
    _bleSub?.cancel();
    _classicSub?.cancel();
    _data.close();
    ble.dispose();
    classic.dispose();
    super.dispose();
  }
}
