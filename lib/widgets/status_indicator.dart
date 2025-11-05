import 'package:flutter/material.dart';
import '../models/device_info.dart';

class StatusIndicator extends StatelessWidget {
  final ConnState state;

  const StatusIndicator({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = _getStateInfo();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _getStateInfo() {
    return switch (state) {
      ConnState.disconnected => ('Disconnected', Colors.grey, Icons.link_off),
      ConnState.scanning => ('Scanning...', Colors.blue, Icons.search),
      ConnState.connecting => ('Connecting...', Colors.orange, Icons.sync),
      ConnState.connected => ('Connected', Colors.green, Icons.check_circle),
      ConnState.retrying => ('Reconnecting...', Colors.amber, Icons.refresh),
      ConnState.error => ('Error', Colors.red, Icons.error_outline),
    };
  }
}
