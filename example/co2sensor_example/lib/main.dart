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
  String _co2 = "Unknown"; // CO2の状態変数を追加
  String _deviceInfo = "Unknown";
  Timer? _timer; // Timerを追加

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
      // センサーデータを一括で取得
      Map<String, dynamic> sensorData = await _mcnDevice.getCo2SensorAllValue();

      setState(() {
        _temperature = "${sensorData['temp']} °C";
        _humidity = "${sensorData['humidity']} %";
        _co2 = "${sensorData['co2']} ppm";
      });
    } catch (e) {
      setState(() {
        _temperature = "Error: ${e.toString()}";
        _humidity = "Error: ${e.toString()}";
        _co2 = "Error: ${e.toString()}";
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
      title: 'mCn CO2 Sensor Demo',
      home: Scaffold(
        appBar: AppBar(
          title: Text('MCN Device Demo'),
        ),
        body: Center(
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
                SizedBox(height: 10),
                Text(
                  "CO₂: $_co2",
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 20),
                // ボタンを保持する場合はコメントアウトを外す
                /*
                ElevatedButton(
                  onPressed: _getSensorData,
                  child: Text('Get Sensor Data'),
                ),
                */
              ],
            ),
          ),
        ),
      ),
    );
  }
}
