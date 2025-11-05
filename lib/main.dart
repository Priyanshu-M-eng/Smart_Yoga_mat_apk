import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartYogaMatApp());
}

class SmartYogaMatApp extends StatelessWidget {
  const SmartYogaMatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Yoga Mat',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum LinkType { ble, classic }

enum ConnState { disconnected, scanning, connecting, connected, retrying, error }

class DeviceInfo {
  final String id; // MAC for Classic, ID for BLE
  final String name;
  final LinkType type;
  DeviceInfo({required this.id, required this.name, required this.type});
}

class BleClient {
  // TODO: replace with your Yoga Mat service/characteristic UUIDs
  static final serviceUuid = fbp.Guid('0000ffff-0000-1000-8000-00805f9b34fb');
  static final rxCharUuid = fbp.Guid('0000ff01-0000-1000-8000-00805f9b34fb'); // notify
  static final txCharUuid = fbp.Guid('0000ff02-0000-1000-8000-00805f9b34fb'); // write

  fbp.BluetoothDevice? _device;
  fbp.BluetoothCharacteristic? _rx;
  fbp.BluetoothCharacteristic? _tx;
  final StreamController<Uint8List> _data = StreamController.broadcast();

  Stream<Uint8List> get data => _data.stream;

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

  Future<void> startScan(void Function(List<DeviceInfo>) onResults, {Duration timeout = const Duration(seconds: 5)}) async {
    final results = <String, DeviceInfo>{};
    await fbp.FlutterBluePlus.startScan(timeout: timeout);
    final sub = fbp.FlutterBluePlus.scanResults.listen((list) {
      for (final r in list) {
        final d = r.device;
        final advName = r.advertisementData.advName.trim();
        final platName = d.platformName;
        final name = advName.isNotEmpty
            ? advName
            : (platName.isNotEmpty ? platName : 'Unknown BLE (${d.remoteId.str})');
        results[d.remoteId.str] = DeviceInfo(id: d.remoteId.str, name: name, type: LinkType.ble);
      }
      onResults(results.values.toList());
    });
    await Future<void>.delayed(timeout);
    await fbp.FlutterBluePlus.stopScan();
    await sub.cancel();
  }

  Future<void> connect(String id, {bool autoConnect = true}) async {
    final dev = fbp.BluetoothDevice.fromId(id);
    _device = dev;
    await dev.connect(license: fbp.License.free, autoConnect: autoConnect, timeout: const Duration(seconds: 10));
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
      throw Exception('Required BLE characteristics not found');
    }
    await _rx!.setNotifyValue(true);
    _rx!.onValueReceived.listen((value) => _data.add(Uint8List.fromList(value)));
  }

  Future<void> write(Uint8List bytes) async {
    final t = _tx;
    if (t == null) throw Exception('BLE not ready');
    await t.write(bytes, withoutResponse: true);
  }

  Future<void> disconnect() async {
    final d = _device;
    _device = null;
    _rx = null;
    _tx = null;
    if (d != null) await d.disconnect();
  }
}

class ClassicClient {
  fbs.BluetoothConnection? _conn;
  final StreamController<Uint8List> _data = StreamController.broadcast();
  Stream<Uint8List> get data => _data.stream;

  Future<void> ensureEnabled() async {
    final fbs.FlutterBluetoothSerial bt = fbs.FlutterBluetoothSerial.instance;
    if ((await bt.isEnabled) != true) {
      await bt.requestEnable();
    }
  }

  StreamSubscription? _discSub;
  Future<void> startDiscovery(void Function(List<DeviceInfo>) onResults, {Duration timeout = const Duration(seconds: 6)}) async {
    final map = <String, DeviceInfo>{};
    await ensureEnabled();

    // Preload bonded devices with names (helps when discovery doesn't broadcast names)
    try {
      final bonded = await fbs.FlutterBluetoothSerial.instance.getBondedDevices();
      for (final b in bonded) {
        if (b.address.isNotEmpty) {
          final nm = (b.name != null && b.name!.isNotEmpty) ? b.name! : 'Paired ${b.address}';
          map[b.address] = DeviceInfo(id: b.address, name: nm, type: LinkType.classic);
        }
      }
      if (map.isNotEmpty) onResults(map.values.toList());
    } catch (_) {}

    _discSub = fbs.FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      final d = r.device;
      if (d.address.isNotEmpty) {
        final prev = map[d.address];
        final nm = (d.name != null && d.name!.isNotEmpty)
            ? d.name!
            : (prev?.name ?? 'Unknown BT (${d.address})');
        map[d.address] = DeviceInfo(id: d.address, name: nm, type: LinkType.classic);
        onResults(map.values.toList());
      }
    });
    await Future<void>.delayed(timeout);
    await _discSub?.cancel();
  }

  Future<void> connect(String address) async {
    await ensureEnabled();
    _conn = await fbs.BluetoothConnection.toAddress(address).timeout(const Duration(seconds: 10));
    _conn!.input?.listen((data) {
      _data.add(Uint8List.fromList(data));
    }).onDone(() {
      // connection closed
    });
  }

  Future<bool?> pair(String address, {String? pin}) async {
    await ensureEnabled();
    try {
      return await fbs.FlutterBluetoothSerial.instance.bondDeviceAtAddress(address, pin: pin);
    } catch (_) {
      return false;
    }
  }

  Future<bool?> unpair(String address) async {
    try {
      return await fbs.FlutterBluetoothSerial.instance.removeDeviceBondWithAddress(address);
    } catch (_) {
      return false;
    }
  }

  Future<void> write(Uint8List bytes) async {
    final c = _conn;
    if (c == null) throw Exception('Classic not connected');
    c.output.add(bytes);
    await c.output.allSent;
  }

  Future<void> disconnect() async {
    await _conn?.close();
    _conn = null;
  }
}

class ConnectionManager extends ChangeNotifier {
  ConnectionManager();

  final ble = BleClient();
  final classic = ClassicClient();

  ConnState state = ConnState.disconnected;
  String? error;
  DeviceInfo? device;
  LinkType? mode;

  // public combined data stream
  final StreamController<Uint8List> _data = StreamController.broadcast();
  Stream<Uint8List> get data => _data.stream;

  StreamSubscription? _bleSub;
  StreamSubscription? _classicSub;

  Future<void> initPermissions() async {
    // Android 12+
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> scan(LinkType type, void Function(List<DeviceInfo>) onResults) async {
    state = ConnState.scanning;
    notifyListeners();
    if (type == LinkType.ble) {
      await ble.startScan(onResults);
    } else {
      await classic.startDiscovery(onResults);
    }
    state = ConnState.disconnected;
    notifyListeners();
  }

  int _retries = 0;
  final int _maxRetries = 3;

  Future<void> connect(DeviceInfo target) async {
    mode = target.type;
    device = target;
    state = ConnState.connecting;
    error = null;
    notifyListeners();
    try {
      if (mode == LinkType.ble) {
        await ble.connect(target.id);
        await _bleSub?.cancel();
        _bleSub = ble.data.listen(_data.add, onDone: _handleDisconnect, onError: (_) => _handleDisconnect());
      } else {
        await classic.connect(target.id);
        await _classicSub?.cancel();
        _classicSub = classic.data.listen(_data.add, onDone: _handleDisconnect, onError: (_) => _handleDisconnect());
      }
      state = ConnState.connected;
      _retries = 0;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      state = ConnState.error;
      notifyListeners();
      _scheduleRetry();
    }
  }

  void _handleDisconnect() {
    if (state == ConnState.connected) {
      state = ConnState.retrying;
      notifyListeners();
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (device == null) return;
    if (_retries >= _maxRetries) {
      state = ConnState.error;
      notifyListeners();
      return;
    }
    _retries += 1;
    final delay = Duration(seconds: 2 * _retries); // backoff
    Timer(delay, () => connect(device!));
  }

  Future<void> sendText(String text) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    if (mode == LinkType.ble) {
      await ble.write(bytes);
    } else {
      await classic.write(bytes);
    }
  }

  Future<Uint8List?> readOnce() async {
    if (mode == LinkType.ble) {
      return await ble.readOnce();
    }
    return null;
  }

  Future<void> disconnect() async {
    state = ConnState.disconnected;
    await _bleSub?.cancel();
    await _classicSub?.cancel();
    if (mode == LinkType.ble) {
      await ble.disconnect();
    } else {
      await classic.disconnect();
    }
    notifyListeners();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final mgr = ConnectionManager();
  LinkType scanType = LinkType.ble;
  List<DeviceInfo> devices = [];
  final ScrollController _logCtrl = ScrollController();
  final List<String> logs = [];
  final TextEditingController _cmdCtrl = TextEditingController(text: 'LED:ON');
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mgr.initPermissions();
    mgr.addListener(() => setState(() {}));
    mgr.data.listen((d) {
      logs.add('RX ${utf8.decode(d, allowMalformed: true)}');
      _scrollToEnd();
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // On resume, if we had a target device but are not connected, try to reconnect
      if (mgr.device != null && mgr.state != ConnState.connected && mgr.state != ConnState.connecting) {
        mgr.connect(mgr.device!);
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logCtrl.hasClients) {
        _logCtrl.jumpTo(_logCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _scan() async {
    devices.clear();
    await mgr.scan(scanType, (results) {
      devices = results;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        final header = Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text('Mode:'),
              const SizedBox(width: 8),
              DropdownButton<LinkType>(
                value: scanType,
                items: const [
                  DropdownMenuItem(value: LinkType.ble, child: Text('BLE (GATT)')),
                  DropdownMenuItem(value: LinkType.classic, child: Text('Classic (SPP)')),
                ],
                onChanged: (v) => setState(() => scanType = v ?? LinkType.ble),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: mgr.state == ConnState.scanning ? null : _scan,
                icon: const Icon(Icons.search),
                label: const Text('Scan'),
              ),
              const SizedBox(width: 12),
              _StatusChip(state: mgr.state),
              const Spacer(),
              if (mgr.device != null && mgr.device!.type == LinkType.classic)
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await mgr.classic.pair(mgr.device!.id);
                    if (ok == true) {
                      messenger.showSnackBar(const SnackBar(content: Text('Paired')));
                    } else {
                      messenger.showSnackBar(const SnackBar(content: Text('Pair failed')));
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Pair'),
                ),
              const SizedBox(width: 8),
              if (mgr.device != null)
                OutlinedButton.icon(
                  onPressed: () => mgr.connect(mgr.device!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconnect'),
                ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => mgr.disconnect(),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        );

        final errorBanner = (mgr.error != null)
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(mgr.error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              )
            : const SizedBox.shrink();

        final devicesList = _DeviceList(
          devices: devices,
          onTap: (d) => mgr.connect(d),
          selected: mgr.device,
        );

        final console = _Console(logs: logs, controller: _logCtrl);

        final commandBar = Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _cmdCtrl,
                decoration: const InputDecoration(labelText: 'Command (text)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: mgr.state == ConnState.connected
                  ? () async {
                      await mgr.sendText('${_cmdCtrl.text}\n');
                      logs.add('TX ${_cmdCtrl.text}');
                      _scrollToEnd();
                      setState(() {});
                    }
                  : null,
              child: const Text('Send'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: mgr.state == ConnState.connected && mgr.mode == LinkType.ble
                  ? () async {
                      final b = await mgr.readOnce();
                      if (b != null) {
                        logs.add('READ ${utf8.decode(b, allowMalformed: true)}');
                        _scrollToEnd();
                        setState(() {});
                      }
                    }
                  : null,
              child: const Text('Read (BLE)'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                logs.clear();
                setState(() {});
              },
              child: const Text('Clear'),
            )
          ]),
        );

        if (isWide) {
          return Scaffold(
            appBar: AppBar(title: const Text('Smart Yoga Mat')),
            body: Column(
              children: [
                header,
                errorBanner,
                Expanded(
                  child: Row(children: [
                    Flexible(flex: 2, child: devicesList),
                    const VerticalDivider(width: 1),
                    Flexible(flex: 3, child: console),
                  ]),
                ),
                commandBar,
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: const Text('Smart Yoga Mat')),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.devices), label: 'Devices'),
                NavigationDestination(icon: Icon(Icons.code), label: 'Console'),
              ],
            ),
            body: Column(
              children: [
                header,
                errorBanner,
                Expanded(child: _tabIndex == 0 ? devicesList : console),
                if (_tabIndex == 1) commandBar,
              ],
            ),
          );
        }
      },
    );
  }
}

class _DeviceList extends StatelessWidget {
  final List<DeviceInfo> devices;
  final DeviceInfo? selected;
  final void Function(DeviceInfo) onTap;
  const _DeviceList({required this.devices, required this.onTap, required this.selected});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final d = devices[i];
        return ListTile(
          selected: selected?.id == d.id,
          title: Text(d.name),
          subtitle: Text('${d.type.name.toUpperCase()} • ${d.id}'),
          trailing: const Icon(Icons.link),
          onTap: () => onTap(d),
        );
      },
    );
  }
}

class _Console extends StatelessWidget {
  final List<String> logs;
  final ScrollController controller;
  const _Console({required this.logs, required this.controller});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ListView.builder(
        controller: controller,
        itemCount: logs.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
          child: Text(
            logs[i],
            style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ConnState state;
  const _StatusChip({required this.state});
  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      ConnState.disconnected => 'Disconnected',
      ConnState.scanning => 'Scanning…',
      ConnState.connecting => 'Connecting…',
      ConnState.connected => 'Connected',
      ConnState.retrying => 'Reconnecting…',
      ConnState.error => 'Error',
    };
    final color = switch (state) {
      ConnState.connected => Colors.green,
      ConnState.error => Colors.red,
      ConnState.retrying => Colors.orange,
      ConnState.scanning => Colors.blue,
      ConnState.connecting => Colors.blueGrey,
      _ => Colors.grey,
    };
    return Chip(label: Text(text), backgroundColor: color.withValues(alpha: 0.2));
  }
}
