import 'package:flutter/material.dart';

enum LinkType { ble, classic }

class DeviceInfo {
  final String id; // MAC for Classic, ID for BLE
  final String name;
  final LinkType type;
  final int? rssi; // Signal strength
  final bool isPaired;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    this.rssi,
    this.isPaired = false,
  });

  DeviceInfo copyWith({
    String? id,
    String? name,
    LinkType? type,
    int? rssi,
    bool? isPaired,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rssi: rssi ?? this.rssi,
      isPaired: isPaired ?? this.isPaired,
    );
  }

  String get signalStrength {
    if (rssi == null) return 'Unknown';
    if (rssi! >= -50) return 'Excellent';
    if (rssi! >= -70) return 'Good';
    if (rssi! >= -85) return 'Fair';
    return 'Weak';
  }

  IconData get signalIcon {
    if (rssi == null) return Icons.signal_cellular_null;
    if (rssi! >= -50) return Icons.signal_cellular_4_bar;
    if (rssi! >= -70) return Icons.signal_cellular_alt_2_bar;
    if (rssi! >= -85) return Icons.signal_cellular_alt_1_bar;
    return Icons.signal_cellular_0_bar;
  }
}

enum ConnState {
  disconnected,
  scanning,
  connecting,
  connected,
  retrying,
  error
}

class ConnectionStats {
  final int bytesReceived;
  final int bytesSent;
  final DateTime connectedSince;
  final int reconnectAttempts;
  final double dataRateBytesPerSecond;

  ConnectionStats({
    this.bytesReceived = 0,
    this.bytesSent = 0,
    DateTime? connectedSince,
    this.reconnectAttempts = 0,
    this.dataRateBytesPerSecond = 0.0,
  }) : connectedSince = connectedSince ?? DateTime.now();

  ConnectionStats copyWith({
    int? bytesReceived,
    int? bytesSent,
    DateTime? connectedSince,
    int? reconnectAttempts,
    double? dataRateBytesPerSecond,
  }) {
    return ConnectionStats(
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesSent: bytesSent ?? this.bytesSent,
      connectedSince: connectedSince ?? this.connectedSince,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      dataRateBytesPerSecond: dataRateBytesPerSecond ?? this.dataRateBytesPerSecond,
    );
  }

  Duration get connectionDuration => DateTime.now().difference(connectedSince);
}
