import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/connection_manager.dart';
import '../models/device_info.dart';

class ConnectionPanel extends StatelessWidget {
  final ConnectionManager manager;

  const ConnectionPanel({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    if (manager.device == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No device connected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            const Text('Scan and connect to a device to see details'),
          ],
        ),
      );
    }

    final device = manager.device!;
    final stats = manager.stats;
    final isConnected = manager.state == ConnState.connected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeviceCard(context, device),
          const SizedBox(height: 16),
          if (isConnected) ...[
            _buildStatsCard(context, stats),
            const SizedBox(height: 16),
          ],
          _buildInfoCard(context),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, DeviceInfo device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    device.type == LinkType.ble
                        ? Icons.bluetooth
                        : Icons.bluetooth_connected,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        device.type == LinkType.ble ? 'BLE (GATT)' : 'Classic (SPP)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(context, 'Device ID', device.id),
            if (device.rssi != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Signal Strength',
                '${device.signalStrength} (${device.rssi} dBm)',
              ),
            ],
            if (device.isPaired) ...[
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Pairing Status', 'Paired'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, ConnectionStats stats) {
    final duration = stats.connectionDuration;
    final durationStr = '${duration.inMinutes}m ${duration.inSeconds % 60}s';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connection Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow(
              context,
              'Connected Since',
              DateFormat('HH:mm:ss').format(stats.connectedSince),
              Icons.access_time,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              'Duration',
              durationStr,
              Icons.timer,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              'Data Received',
              _formatBytes(stats.bytesReceived),
              Icons.download,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              'Data Sent',
              _formatBytes(stats.bytesSent),
              Icons.upload,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              'Data Rate',
              '${_formatBytes(stats.dataRateBytesPerSecond.toInt())}/s',
              Icons.speed,
            ),
            if (stats.reconnectAttempts > 0) ...[
              const SizedBox(height: 12),
              _buildStatRow(
                context,
                'Reconnect Attempts',
                stats.reconnectAttempts.toString(),
                Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                manager.mode == LinkType.ble
                    ? 'Use the Console tab to send commands and receive data via BLE GATT characteristics.'
                    : 'Use the Console tab to send commands and receive data via Classic SPP.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
