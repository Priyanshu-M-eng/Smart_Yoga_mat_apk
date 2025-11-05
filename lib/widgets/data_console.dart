import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/connection_manager.dart';
import '../models/device_info.dart';

class DataConsole extends StatefulWidget {
  final ConnectionManager manager;

  const DataConsole({super.key, required this.manager});

  @override
  State<DataConsole> createState() => _DataConsoleState();
}

class _DataConsoleState extends State<DataConsole> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _cmdController = TextEditingController(text: 'LED:ON');

  @override
  void initState() {
    super.initState();
    widget.manager.data.listen((data) {
      if (mounted) {
        setState(() {
          _logs.add('📥 ${utf8.decode(data, allowMalformed: true)}');
          _scrollToEnd();
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cmdController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendCommand() async {
    if (_cmdController.text.isEmpty) return;
    try {
      await widget.manager.sendText('${_cmdController.text}\n');
      if (!mounted) return;
      setState(() {
        _logs.add('📤 ${_cmdController.text}');
        _scrollToEnd();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    }
  }

  Future<void> _readOnce() async {
    try {
      final data = await widget.manager.readOnce();
      if (data != null && mounted) {
        setState(() {
          _logs.add('📖 ${utf8.decode(data, allowMalformed: true)}');
          _scrollToEnd();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Read failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.manager.state == ConnState.connected;

    return Column(
      children: [
        Expanded(
          child: _logs.isEmpty
              ? _buildEmptyState(context)
              : _buildConsole(context),
        ),
        _buildCommandBar(context, isConnected),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.terminal,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Console is empty',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          const Text('Send commands to see data'),
        ],
      ),
    );
  }

  Widget _buildConsole(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.grey[900],
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText(
              _logs[index],
              style: TextStyle(
                color: _logs[index].startsWith('📤')
                    ? Colors.cyanAccent
                    : _logs[index].startsWith('📥')
                        ? Colors.greenAccent
                        : Colors.yellowAccent,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommandBar(BuildContext context, bool isConnected) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cmdController,
                    decoration: InputDecoration(
                      labelText: 'Command',
                      hintText: 'Enter command...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.code),
                      enabled: isConnected,
                    ),
                    onSubmitted: isConnected ? (_) => _sendCommand() : null,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isConnected ? _sendCommand : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (widget.manager.mode == LinkType.ble)
                  OutlinedButton.icon(
                    onPressed: isConnected ? _readOnce : null,
                    icon: const Icon(Icons.download),
                    label: const Text('Read (BLE)'),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _logs.clear());
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear'),
                ),
                OutlinedButton.icon(
                  onPressed: isConnected
                      ? () {
                          _cmdController.text = 'STATUS';
                          _sendCommand();
                        }
                      : null,
                  icon: const Icon(Icons.info),
                  label: const Text('Status'),
                ),
                OutlinedButton.icon(
                  onPressed: isConnected
                      ? () {
                          _cmdController.text = 'LED:ON';
                          _sendCommand();
                        }
                      : null,
                  icon: const Icon(Icons.lightbulb),
                  label: const Text('LED ON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
