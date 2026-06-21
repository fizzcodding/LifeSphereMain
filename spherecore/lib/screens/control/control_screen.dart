import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mjpeg_stream/mjpeg_stream.dart';
import 'package:http/http.dart' as http;
import '../../themes/app_theme.dart';
import '../../widgets/sidebar.dart';
import '../../utils/toast.dart';

enum ControlMode {auto, manual, hybrid}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  ControlMode _mode = ControlMode.auto;
  final _channel = WebSocketChannel.connect(Uri.parse(''));

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control'),
      ),
      body: Center(
        child: Text('Mode: $_mode'),
      ),
    );
  }
}
