// lib/mcn_device.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

// センサーモードの定義
enum SensorMode { TempSensor, HumidSensor }

/// 抽象基底クラス
abstract class McnDeviceBase {
  UsbPort? _port;
  StreamSubscription<String>? _subscription;
  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _commandController = StreamController<String>();

  McnDeviceBase();

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

  /// コマンド送信とレスポンス待機
  Future<Map<String, dynamic>> _sendCommandAndAwaitResponse(
      Map<String, dynamic> command) {
    Completer<Map<String, dynamic>> completer = Completer();
    StreamSubscription<Map<String, dynamic>>? subscription;

    subscription = _responseController.stream.listen((response) {
      if (response.containsKey("error")) {
        completer.complete(response);
      } else if (command["command"] == "getTemp" &&
          response.containsKey("temp")) {
        completer.complete(response);
      } else if (command["command"] == "getHumid" &&
          response.containsKey("humid")) {
        completer.complete(response);
      } else if (command["command"] == "getMcnInfo" &&
          response.containsKey("deviceVersion")) {
        completer.complete(response);
      } else if (command["command"] == "setMode" &&
          response.containsKey("status")) {
        completer.complete(response);
      }
      subscription?.cancel();
    });

    // コマンド送信
    String jsonCommand = jsonEncode(command);
    _commandController.add(jsonCommand);

    // タイムアウト設定
    completer.future.timeout(Duration(seconds: 5), onTimeout: () {
      subscription?.cancel();
      return {"error": "Timeout waiting for device response."};
    }).then((value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
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

/// TempSensorモード用クラス
class TempSensorDevice extends McnDeviceBase {
  TempSensorDevice._(UsbPort port) {
    this._port = port;
  }

  /// 温度取得メソッド
  Future<double> getInternalTemp() async {
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
}

/// HumidSensorモード用クラス
class HumidSensorDevice extends McnDeviceBase {
  HumidSensorDevice._(UsbPort port) {
    this._port = port;
  }

  /// 湿度取得メソッド
  Future<double> getHumid() async {
    Map<String, dynamic> response =
        await _sendCommandAndAwaitResponse({"command": "getHumid"});
    if (response.containsKey("humid")) {
      return response["humid"].toDouble();
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
}

/// McnDeviceクラス
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

  /// センサーモードの設定
  Future<McnDeviceBase> setMode(SensorMode mode) async {
    Map<String, dynamic> command;
    if (mode == SensorMode.TempSensor) {
      command = {"command": "setMode", "mode": "TempSensor"};
    } else if (mode == SensorMode.HumidSensor) {
      command = {"command": "setMode", "mode": "HumidSensor"};
    } else {
      throw Exception("Unsupported mode");
    }

    Map<String, dynamic> response = await _sendCommandAndAwaitResponse(command);
    if (response.containsKey("error")) {
      throw Exception("Error setting mode: ${response["error"]}");
    } else {
      print("Mode set to $mode");
      if (mode == SensorMode.TempSensor) {
        return TempSensorDevice._(_port!);
      } else if (mode == SensorMode.HumidSensor) {
        return HumidSensorDevice._(_port!);
      } else {
        throw Exception("Unsupported mode");
      }
    }
  }

  /// コマンド送信とレスポンス待機
  Future<Map<String, dynamic>> _sendCommandAndAwaitResponse(
      Map<String, dynamic> command) {
    Completer<Map<String, dynamic>> completer = Completer();
    StreamSubscription<Map<String, dynamic>>? subscription;

    subscription = _responseController.stream.listen((response) {
      if (response.containsKey("error")) {
        completer.complete(response);
      } else if (command["command"] == "getTemp" &&
          response.containsKey("temp")) {
        completer.complete(response);
      } else if (command["command"] == "getHumid" &&
          response.containsKey("humid")) {
        completer.complete(response);
      } else if (command["command"] == "getMcnInfo" &&
          response.containsKey("deviceVersion")) {
        completer.complete(response);
      } else if (command["command"] == "setMode" &&
          response.containsKey("status")) {
        completer.complete(response);
      }
      subscription?.cancel();
    });

    // コマンド送信
    String jsonCommand = jsonEncode(command);
    _commandController.add(jsonCommand);

    // タイムアウト設定
    completer.future.timeout(Duration(seconds: 5), onTimeout: () {
      subscription?.cancel();
      return {"error": "Timeout waiting for device response."};
    }).then((value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
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
