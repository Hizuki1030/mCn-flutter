// main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mcn/mcn.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Changed to StatelessWidget
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCN Motor Control Demo',
      home: MotorControlPage(), // Separate StatefulWidget
    );
  }
}

class MotorControlPage extends StatefulWidget {
  @override
  _MotorControlPageState createState() => _MotorControlPageState();
}

class _MotorControlPageState extends State<MotorControlPage> {
  late McnDevice _mcnDevice;
  String _deviceInfo = "Unknown";
  Timer? _timer;

  // Motor speeds
  double _motor0Speed = 0.0;
  double _motor1Speed = 0.0;

  @override
  void initState() {
    super.initState();
    _mcnDevice = McnDevice();
    _initializeDevice();
  }

  Future<void> _initializeDevice() async {
    bool success = await _mcnDevice.initialize();
    if (success) {
      print("Device initialized successfully.");
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

  Future<void> _setMotor0Speed(double speed) async {
    try {
      await _mcnDevice.setMotor0Speed(speed.toInt());
      setState(() {
        _motor0Speed = speed;
      });
      if (mounted) {
        _showSnackBar('Motor 0 speed set to ${speed.toInt()}°');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to set Motor 0 speed: $e');
      }
    }
  }

  Future<void> _setMotor1Speed(double speed) async {
    try {
      await _mcnDevice.setMotor1Speed(speed.toInt());
      setState(() {
        _motor1Speed = speed;
      });
      if (mounted) {
        _showSnackBar('Motor 1 speed set to ${speed.toInt()}°');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to set Motor 1 speed: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    // Use ScaffoldMessenger from the current context
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _mcnDevice.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MCN Motor Control Demo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Device Info: $_deviceInfo",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Divider(),
              SizedBox(height: 20),
              Text(
                "Motor 0 Control",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _motor0Speed,
                min: 0,
                max: 360,
                divisions: 36,
                label: 'Motor 0: ${_motor0Speed.toInt()}°',
                onChanged: (value) {
                  setState(() {
                    _motor0Speed = value;
                  });
                },
                onChangeEnd: (value) {
                  _setMotor0Speed(value);
                },
              ),
              SizedBox(height: 20),
              Text(
                "Motor 1 Control",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _motor1Speed,
                min: 0,
                max: 360,
                divisions: 36,
                label: 'Motor 1: ${_motor1Speed.toInt()}°',
                onChanged: (value) {
                  setState(() {
                    _motor1Speed = value;
                  });
                },
                onChangeEnd: (value) {
                  _setMotor1Speed(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
