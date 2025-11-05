import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../models/device_info.dart';
import '../widgets/device_list.dart';
import '../widgets/connection_panel.dart';
import '../widgets/data_console.dart';
import '../widgets/status_indicator.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  LinkType _scanType = LinkType.ble;
  List<DeviceInfo> _devices = [];
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mgr = context.read<ConnectionManager>();
      mgr.initPermissions();
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
      final mgr = context.read<ConnectionManager>();
      if (mgr.device != null &&
          mgr.state != ConnState.connected &&
          mgr.state != ConnState.connecting &&
          mgr.autoReconnect) {
        mgr.connect(mgr.device!);
      }
    }
  }

  Future<void> _scan() async {
    final mgr = context.read<ConnectionManager>();
    setState(() => _devices.clear());
    await mgr.scan(_scanType, (results) {
      setState(() => _devices = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionManager>(
      builder: (context, mgr, _) {
        final isWide = MediaQuery.of(context).size.width >= 700;

        return Scaffold(
          appBar: _buildAppBar(context, mgr),
          body: isWide ? _buildWideLayout(mgr) : _buildNarrowLayout(mgr),
          bottomNavigationBar: isWide ? null : _buildBottomNav(),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, ConnectionManager mgr) {
    return AppBar(
      title: const Text('Smart Yoga Mat'),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
      ),
      actions: [
        StatusIndicator(state: mgr.state),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(ConnectionManager mgr) {
    return Column(
      children: [
        _buildControlPanel(mgr),
        if (mgr.error != null) _buildErrorBanner(mgr.error!),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: DeviceList(
                  devices: _devices,
                  selectedDevice: mgr.device,
                  onDeviceTap: (device) => mgr.connect(device),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    ConnectionPanel(manager: mgr),
                    const Divider(height: 1),
                    Expanded(child: DataConsole(manager: mgr)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(ConnectionManager mgr) {
    return Column(
      children: [
        _buildControlPanel(mgr),
        if (mgr.error != null) _buildErrorBanner(mgr.error!),
        Expanded(
          child: _tabIndex == 0
              ? DeviceList(
                  devices: _devices,
                  selectedDevice: mgr.device,
                  onDeviceTap: (device) => mgr.connect(device),
                )
              : _tabIndex == 1
                  ? DataConsole(manager: mgr)
                  : ConnectionPanel(manager: mgr),
        ),
      ],
    );
  }

  Widget _buildControlPanel(ConnectionManager mgr) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<LinkType>(
              value: _scanType,
              icon: const Icon(Icons.bluetooth),
              items: const [
                DropdownMenuItem(
                  value: LinkType.ble,
                  child: Text('BLE (GATT)'),
                ),
                DropdownMenuItem(
                  value: LinkType.classic,
                  child: Text('Classic (SPP)'),
                ),
              ],
              onChanged: (v) => setState(() => _scanType = v ?? LinkType.ble),
            ),
            FilledButton.icon(
              onPressed: mgr.state == ConnState.scanning ? null : _scan,
              icon: const Icon(Icons.search),
              label: const Text('Scan Devices'),
            ),
            if (mgr.device != null) ...[
              OutlinedButton.icon(
                onPressed: () => mgr.connect(mgr.device!),
                icon: const Icon(Icons.refresh),
                label: const Text('Reconnect'),
              ),
              OutlinedButton.icon(
                onPressed: () => mgr.disconnect(),
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _tabIndex,
      onDestinationSelected: (i) => setState(() => _tabIndex = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.devices),
          label: 'Devices',
        ),
        NavigationDestination(
          icon: Icon(Icons.code),
          label: 'Console',
        ),
        NavigationDestination(
          icon: Icon(Icons.info_outline),
          label: 'Info',
        ),
      ],
    );
  }
}
