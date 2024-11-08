// main.dart

import 'dart:async'; // Import for Timer
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
  String _humidity = "Unknown"; // 湿度の状態変数を追加
  String _deviceInfo = "Unknown";
  Timer? _timer; // Timerを追加

  // ポンプの状態を保持する変数
  bool _isPumpOn = false;
  bool _isPumpUpdating = false; // ポンプ状態更新中かどうか

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

        // タイマーを開始して5秒ごとにセンサーデータを取得
        _timer = Timer.periodic(Duration(seconds: 5), (Timer t) {
          _getSensorData();
        });

        // 初回データ取得
        _getSensorData();
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

  /// センサーデータを一括で取得するメソッド
  Future<void> _getSensorData() async {
    try {
      // センサーデータを一括で取得（CO2を除く）
      Map<String, dynamic> sensorData = await _mcnDevice.getCo2SensorAllValue();

      setState(() {
        _temperature = "${sensorData['temp']} °C";
        _humidity = "${sensorData['humidity']} %";
        // CO2の表示を削除
      });
    } catch (e) {
      setState(() {
        _temperature = "Error: ${e.toString()}";
        _humidity = "Error: ${e.toString()}";
        // CO2の表示を削除
      });
    }
  }

  /// ポンプをオンにするメソッド
  Future<void> _turnPumpOn() async {
    setState(() {
      _isPumpUpdating = true;
    });
    try {
      await _mcnDevice.setWaterPump(1);
      setState(() {
        _isPumpOn = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ポンプをオンにしました。')),
      );
    } catch (e) {
      print("Failed to turn pump on: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ポンプをオンにできませんでした。')),
      );
    } finally {
      setState(() {
        _isPumpUpdating = false;
      });
    }
  }

  /// ポンプをオフにするメソッド
  Future<void> _turnPumpOff() async {
    setState(() {
      _isPumpUpdating = true;
    });
    try {
      await _mcnDevice.setWaterPump(0);
      setState(() {
        _isPumpOn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ポンプをオフにしました。')),
      );
    } catch (e) {
      print("Failed to turn pump off: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ポンプをオフにできませんでした。')),
      );
    } finally {
      setState(() {
        _isPumpUpdating = false;
      });
    }
  }

  @override
  void dispose() {
    _mcnDevice.dispose();
    _timer?.cancel(); // タイマーをキャンセル
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mCn Sensor & Pump Demo',
      home: Scaffold(
        appBar: AppBar(
          title: Text('MCN Device Demo'),
        ),
        body: Center(
          child: SingleChildScrollView(
            // スクロール可能にする
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // 中央揃え
                children: [
                  Text(
                    "Device Info: $_deviceInfo",
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Temperature: $_temperature",
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 10), // スペースを調整
                  Text(
                    "Humidity: $_humidity",
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 20),
                  Divider(),
                  SizedBox(height: 20),
                  Text(
                    "Water Pump Control",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Current Status: ${_isPumpOn ? 'ON' : 'OFF'}",
                    style: TextStyle(
                      fontSize: 20,
                      color: _isPumpOn ? Colors.green : Colors.red,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed:
                            _isPumpUpdating ? null : _turnPumpOn, // 更新中は無効化
                        child: Text('Turn Pump ON'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // Updated parameter
                        ),
                      ),
                      SizedBox(width: 20),
                      ElevatedButton(
                        onPressed:
                            _isPumpUpdating ? null : _turnPumpOff, // 更新中は無効化
                        child: Text('Turn Pump OFF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, // Updated parameter
                        ),
                      ),
                    ],
                  ),
                  if (_isPumpUpdating) ...[
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
