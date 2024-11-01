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
        _responseController.add({"error": "Input stream error: $e"});
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
    return await _sendCommandAndAwaitResponse<double>(
      "getTemp",
      (response) {
        if (response.containsKey("temp")) {
          return response["temp"].toDouble();
        } else {
          throw Exception("Unexpected response structure.");
        }
      },
    );
  }

  /// CO2取得メソッド
  Future<double> getCO2() async {
    return await _sendCommandAndAwaitResponse<double>(
      "getCO2",
      (response) {
        if (response.containsKey("co2")) {
          return response["co2"].toDouble();
        } else {
          throw Exception("Unexpected response structure.");
        }
      },
    );
  }

  /// デバイス情報取得メソッド
  Future<Map<String, dynamic>> getMcnInfo() async {
    return await _sendCommandAndAwaitResponse<Map<String, dynamic>>(
      "getMcnInfo",
      (response) {
        if (response.containsKey("deviceVersion") &&
            response.containsKey("firmwareType")) {
          return {
            "deviceVersion": response["deviceVersion"],
            "firmwareType": response["firmwareType"],
          };
        } else {
          throw Exception("Unexpected response structure.");
        }
      },
    );
  }

  /// コマンド送信とレスポンス待機（ジェネリック化）
  Future<T> _sendCommandAndAwaitResponse<T>(
      String command, T Function(Map<String, dynamic>) parser) async {
    Completer<T> completer = Completer();
    StreamSubscription<Map<String, dynamic>>? subscription;

    subscription = _responseController.stream.listen((response) {
      if (response.containsKey("error")) {
        completer.completeError(
            Exception("Error from device: ${response["error"]}"));
        subscription?.cancel();
      } else {
        try {
          T result = parser(response);
          completer.complete(result);
          subscription?.cancel();
        } catch (e) {
          completer.completeError(e);
          subscription?.cancel();
        }
      }
    });

    // コマンド送信
    _commandController.add(command);

    // タイムアウト設定
    try {
      return await completer.future.timeout(Duration(seconds: 5));
    } on TimeoutException {
      subscription?.cancel();
      throw Exception("Timeout waiting for device response.");
    } catch (e) {
      subscription?.cancel();
      rethrow;
    }
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
      // エラーレスポンスとして扱う
      _responseController.add({"error": "Invalid JSON format"});
    }
  }
}
