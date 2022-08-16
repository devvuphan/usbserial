import 'dart:async';

import 'package:byte_array/byte_array.dart';

import 'types.dart';

/// Test harnass stub for UsbPort.
/// Sends the data back with a delay.
class EchoPort extends AsyncDataSinkSource {
  Stream<ByteArray>? _stream;
  late StreamController<ByteArray> _controller;
  bool _running = false;
  late List<ByteArray> _buffer;
  final Duration writeDelay;

  EchoPort({this.writeDelay = const Duration(seconds: 0)}) {
    _stream = fakeData();
    _buffer = [];
  }

  Stream<ByteArray> fakeData() {
    void start() {
      _running = true;
      if (_buffer.length > 0) {
        _buffer.forEach((data) {
          _controller.add(data);
        });
        _buffer.clear();
      }
    }

    void stop() {
      _running = false;
    }

    // _controller = StreamController(
    //     onListen: start, onPause: stop, onResume: start, onCancel: stop);
    _controller = StreamController.broadcast(onListen: start, onCancel: stop);

    return _controller.stream;
  }

  @override
  Stream<ByteArray>? get inputStream {
    return _stream;
  }

  Future<void> _write(ByteArray data) async {
    if (_running) {
      _controller.add(data);
    } else {
      _buffer.add(data);
    }
  }

  @override
  Future<void> write(ByteArray data) async {
    if (writeDelay == Duration(seconds: 0)) {
      return _write(data);
    } else {
      Future<void>.delayed(writeDelay, () {
        return _write(data);
      });
    }
  }

  void close() {
    _controller.close();
  }
}
