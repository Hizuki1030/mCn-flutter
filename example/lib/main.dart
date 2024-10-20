// main.dart

import 'package:flutter/material.dart';
import 'package:mcn/mcn.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late McnDevice _mcnDevice; // late キーワードを追加
  String _temperature = "Unknown";
  String _deviceInfo = "Unknown";

  @override
  void initState() {
    super.initState();
    _mcnDevice = McnDevice(); // 初期化
    _initializeDevice();
  }

  Future<void> _initializeDevice() async {
    bool success = await _mcnDevice.initialize();
    if (success) {
      print("Device initialized successfully.");
      // 必要に応じてデバイス情報を取得
      try {
        Map<String, dynamic> info = await _mcnDevice.getMcnInfo();
        setState(() {
          _deviceInfo =
              "Version: ${info['deviceVersion']}, Firmware: ${info['firmwareType']}";
        });
      } catch (e) {
        setState(() {
          _deviceInfo = "Error: ${e.toString()}";
        });
      }
    } else {
      setState(() {
        _deviceInfo = "Failed to initialize device.";
      });
    }
  }

  Future<void> _getTemperature() async {
    try {
      double temp = await _mcnDevice.getInternalTemp();
      setState(() {
        _temperature = "$temp °C";
      });
    } catch (e) {
      setState(() {
        _temperature = "Error: ${e.toString()}";
      });
    }
  }

  @override
  void dispose() {
    _mcnDevice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCN Device Demo',
      home: Scaffold(
        appBar: AppBar(
          title: Text('MCN Device Demo'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "Device Info: $_deviceInfo",
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                Text(
                  "Temperature: $_temperature",
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _getTemperature,
                  child: Text('Get Temperature'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
