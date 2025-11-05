import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<ConnectionManager>(
        builder: (context, mgr, _) {
          return ListView(
            children: [
              const _SectionHeader(title: 'Connection'),
              SwitchListTile(
                title: const Text('Auto-Reconnect'),
                subtitle: const Text('Automatically reconnect when connection is lost'),
                value: mgr.autoReconnect,
                onChanged: (value) => mgr.autoReconnect = value,
              ),
              const Divider(),
              const _SectionHeader(title: 'Device UUIDs'),
              ListTile(
                title: const Text('Service UUID'),
                subtitle: const Text('0000ffff-0000-1000-8000-00805f9b34fb'),
                trailing: const Icon(Icons.info_outline),
                onTap: () => _showInfoDialog(
                  context,
                  'Service UUID',
                  'This is the BLE service UUID for your yoga mat. Update in ble_client.dart if different.',
                ),
              ),
              ListTile(
                title: const Text('RX Characteristic'),
                subtitle: const Text('0000ff01-0000-1000-8000-00805f9b34fb'),
                trailing: const Icon(Icons.info_outline),
                onTap: () => _showInfoDialog(
                  context,
                  'RX Characteristic',
                  'This characteristic is used for receiving notifications from the device.',
                ),
              ),
              ListTile(
                title: const Text('TX Characteristic'),
                subtitle: const Text('0000ff02-0000-1000-8000-00805f9b34fb'),
                trailing: const Icon(Icons.info_outline),
                onTap: () => _showInfoDialog(
                  context,
                  'TX Characteristic',
                  'This characteristic is used for writing commands to the device.',
                ),
              ),
              const Divider(),
              const _SectionHeader(title: 'About'),
              const ListTile(
                title: Text('App Version'),
                subtitle: Text('1.0.0'),
              ),
              ListTile(
                title: const Text('GitHub Repository'),
                subtitle: const Text('Smart Yoga Mat App'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {},
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
