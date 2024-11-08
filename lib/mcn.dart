// lib/mcn_device.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

class McnDevice {
  UsbPort? _port;
  StreamSubscription<String>? _subscription;
  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _commandController = StreamController<String>();

  McnDevice();

  /// デバイスの初期化と接続
  Future<bool> initialize() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      print("No USB devices found.");
      return false;
    }

    _port = await devices[0].create();
    if (_port == null) {
      print("Failed to create port.");
      return false;
    }

    if (!await _port!.open()) {
      print("Failed to open port.");
      return false;
    }

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
      115200,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    // リスナーの設定
    _subscription = _port!.inputStream
        ?.map((data) => data.toList())
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      _handleIncomingData,
      onError: (e) {
        print("Error in input stream: $e");
      },
    );

    // コマンド送信リスナー
    _commandController.stream.listen((command) {
      _sendCommand(command);
    });

    return true;
  }

  /// デバイスのクローズ
  void dispose() {
    _subscription?.cancel();
    _port?.close();
    _responseController.close();
    _commandController.close();
  }

  /// 温度取得メソッド
  Future<double> getTemp() async {
    Map<String, dynamic> response =
        await _sendCommandAndAwaitResponse({"command": "getTemp"});
    if (response.containsKey("temp")) {
      return response["temp"].toDouble();
    } else if (response.containsKey("error")) {
      throw Exception("Error from device: ${response["error"]}");
    } else {
      throw Exception("Unexpected response from device.");
    }
  }

  /// CO2取得メソッド
  Future<int> getCO2() async {
    Map<String, dynamic> response =
        await _sendCommandAndAwaitResponse({"command": "getCO2"});
    if (response.containsKey("co2")) {
      return response["co2"].toInt();
    } else if (response.containsKey("error")) {
      throw Exception("Error from device: ${response["error"]}");
    } else {
      throw Exception("Unexpected response from device.");
    }
  }

  /// 湿度取得メソッド
  Future<double> getHumidity() async {
    Map<String, dynamic> response =
        await _sendCommandAndAwaitResponse({"command": "getHumidity"});
    if (response.containsKey("humidity")) {
      return response["humidity"].toDouble();
    } else if (response.containsKey("error")) {
      throw Exception("Error from device: ${response["error"]}");
    } else {
      throw Exception("Unexpected response from device.");
    }
  }

  /// デバイス情報取得メソッド
  Future<Map<String, dynamic>> getMcnInfo() async {
    Map<String, dynamic> response =
        await _sendCommandAndAwaitResponse({"command": "getMcnInfo"});
    if (response.containsKey("deviceVersion") &&
        response.containsKey("firmwareType")) {
      return {
        "deviceVersion": response["deviceVersion"],
        "firmwareType": response["firmwareType"],
      };
    } else if (response.containsKey("error")) {
      throw Exception("Error from device: ${response["error"]}");
    } else {
      throw Exception("Unexpected response from device.");
    }
  }

  /// co2センサー全情報取得メソッド
  Future<Map<String, dynamic>> getCo2SensorAllValue() async {
    Map<String, dynamic> response =
        await _sendCommandAndAwaitResponse({"command": "getCo2SensorValue"});
    if (response.containsKey("temp") &&
        response.containsKey("co2") &&
        response.containsKey("humidity")) {
      return {
        "temp": response["temp"].toDouble(),
        "co2": response["co2"].toInt(),
        "humidity": response["humidity"].toDouble(),
      };
    } else if (response.containsKey("error")) {
      throw Exception("Error from device: ${response["error"]}");
    } else {
      throw Exception("Unexpected response from device.");
    }
  }

  /// 水ポンプの設定メソッド
  Future<void> setWaterPump(int value) async {
    // Validate the input value if necessary
    if (value != 0 && value != 1) {
      throw ArgumentError("Invalid value for setWaterPump. Use 0 or 1.");
    }

    // Construct the command map
    Map<String, dynamic> command = {
      "command": "setWaterPump",
      "value": value,
    };

    try {
      // Send the command and await the response
      Map<String, dynamic> response =
          await _sendCommandAndAwaitResponse(command);

      // Handle the response
      if (response.containsKey("success") && response["success"] == true) {
        // Command was successful
        print("Water pump set successfully.");
      } else if (response.containsKey("error")) {
        // Device returned an error
        throw Exception("Error from device: ${response["error"]}");
      } else {
        // Unexpected response format
        throw Exception("Unexpected response from device.");
      }
    } catch (e) {
      // Handle any exceptions that occur during the process
      print("Failed to set water pump: $e");
      rethrow;
    }
  }

  /// コマンド送信とレスポンス待機
  Future<Map<String, dynamic>> _sendCommandAndAwaitResponse(
      Map<String, dynamic> command) {
    Completer<Map<String, dynamic>> completer = Completer();
    StreamSubscription<Map<String, dynamic>>? subscription;

    subscription = _responseController.stream.listen((response) {
      if (!completer.isCompleted) {
        completer.complete(response);
        subscription?.cancel();
      }
    });

    // コマンド送信
    String jsonCommand = jsonEncode(command);
    _commandController.add(jsonCommand);

    // タイムアウト設定
    completer.future.timeout(Duration(seconds: 5), onTimeout: () {
      if (!completer.isCompleted) {
        completer.complete({"error": "Timeout waiting for device response."});
      }
      subscription?.cancel();
      return {"error": "Timeout waiting for device response."};
    }).catchError((e) {
      // 予期せぬエラーの処理
      if (!completer.isCompleted) {
        completer.complete({"error": "Unknown error: $e"});
      }
    });

    return completer.future;
  }

  /// コマンドの送信
  void _sendCommand(String command) {
    String cmdWithNewline = "$command\n";
    List<int> bytes = utf8.encode(cmdWithNewline);
    _port?.write(Uint8List.fromList(bytes));
  }

  /// 受信データの処理
  void _handleIncomingData(String data) {
    try {
      Map<String, dynamic> jsonResponse = jsonDecode(data);
      _responseController.add(jsonResponse);
    } catch (e) {
      print("Failed to decode JSON: $e");
      // エラーレスポンスとして扱う場合
      _responseController.add({"error": "Invalid JSON format"});
    }
  }
}
