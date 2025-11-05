import 'package:flutter/material.dart';
import '../models/device_info.dart';

class DeviceList extends StatelessWidget {
  final List<DeviceInfo> devices;
  final DeviceInfo? selectedDevice;
  final void Function(DeviceInfo) onDeviceTap;

  const DeviceList({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.onDeviceTap,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            const Text('Tap "Scan Devices" to discover nearby devices'),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: devices.length,
      padding: const EdgeInsets.all(8),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = devices[index];
        final isSelected = selectedDevice?.id == device.id;

        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                device.type == LinkType.ble
                    ? Icons.bluetooth
                    : Icons.bluetooth_connected,
                color: Colors.white,
              ),
            ),
            title: Text(
              device.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${device.type.name.toUpperCase()} • ${_truncateId(device.id)}'),
                if (device.rssi != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        device.signalIcon,
                        size: 16,
                        color: _getSignalColor(device.rssi!),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${device.signalStrength} (${device.rssi} dBm)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getSignalColor(device.rssi!),
                        ),
                      ),
                    ],
                  ),
                ],
                if (device.isPaired)
                  Chip(
                    label: const Text('Paired'),
                    labelStyle: const TextStyle(fontSize: 10),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            trailing: Icon(
              isSelected ? Icons.check_circle : Icons.link,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onTap: () => onDeviceTap(device),
          ),
        );
      },
    );
  }

  String _truncateId(String id) {
    if (id.length > 20) {
      return '${id.substring(0, 17)}...';
    }
    return id;
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.orange;
    if (rssi >= -85) return Colors.deepOrange;
    return Colors.red;
  }
}
