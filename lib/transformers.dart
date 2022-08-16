import 'dart:async';
import 'dart:typed_data';

import 'package:byte_array/byte_array.dart';

/// wildcardFind searches the haystack for a copy of needle.
/// both needle and haystack must be Lists. Needle may
/// contain null's, that position is then treated as a wildcard.
int wildcardFind(dynamic needle, dynamic haystack) {
  final int? hl = haystack.length;
  final int? nl = needle.length;

  if (nl == 0) {
    return 0;
  }

  if (hl! < nl!) {
    return -1;
  }

  for (int i = 0; i <= (hl - nl); i++) {
    bool found = true;
    for (int j = 0; j < nl; j++) {
      if (needle[j] != null && (haystack[i + j] != needle[j])) {
        found = false;
        break;
      }
    }
    if (found) {
      return i;
    }
  }
  return -1;
}

/// parent abstract class to all transformers adding dispose method.
abstract class DisposableStreamTransformer<T, R> implements StreamTransformer<T, R> {
  void dispose();
}

/// This transformer takes an incoming stream and splits it
/// along the "terminator" marks. Great for parsing incoming
/// serial streams that end on \r\n.
class TerminatedTransformer implements DisposableStreamTransformer<ByteArray, ByteArray> {
  bool? cancelOnError;
  final ByteArray? terminator;
  final int maxLen; // maximum length the partial buffer will hold before it starts flushing.
  final stripTerminator;

  late StreamController _controller;
  StreamSubscription? _subscription;
  late Stream<ByteArray> _stream;
  late List<int> _partial;

  /// Splits the incoming stream at the given terminator sequence.
  /// maxLen is the maximum number of bytes that will be collected
  /// before a terminator is detected. If more data arrives the oldest
  /// bytes will be discarded.
  /// terminator is a ByteArray of bytes.
  /// stripTerminator is a boolean indicating if the terminator should
  /// remain attached in the output.
  ///
  /// This constructor creates a single stream
  TerminatedTransformer({bool sync: false, this.cancelOnError, this.terminator, this.maxLen = 1024, this.stripTerminator = true}) {
    _partial = [];
    _controller = new StreamController<ByteArray>(
        onListen: _onListen,
        onCancel: _onCancel,
        onPause: () {
          _subscription!.pause();
        },
        onResume: () {
          _subscription!.resume();
        },
        sync: sync);
  }

  /// Splits the incoming stream at the given terminator sequence.
  /// maxLen is the maximum number of bytes that will be collected
  /// before a terminator is detected. If more data arrives the oldest
  /// bytes will be discarded.
  /// terminator is a ByteArray of bytes.
  /// stripTerminator is a boolean indicating if the terminator should
  /// remain attached in the output.
  ///
  /// This constructor creates a broadcast stream
  TerminatedTransformer.broadcast({bool sync: false, this.cancelOnError, this.terminator, this.maxLen = 1024, this.stripTerminator = true}) {
    _partial = [];
    _controller = new StreamController<ByteArray>.broadcast(onListen: _onListen, onCancel: _onCancel, sync: sync);
  }

  void _onListen() {
    _subscription = _stream.listen(onData, onError: _controller.addError, onDone: _controller.close, cancelOnError: cancelOnError);
  }

  void _onCancel() {
    _subscription!.cancel();
    _subscription = null;
  }

  void onData(ByteArray data) {
    if (_partial.length > maxLen) {
      _partial = _partial.sublist(_partial.length - maxLen);
    }
    for (int i = 0; i < data.length; i++) {
      _partial.add(data[i]);
    }

    while (((_partial.length - terminator!.length) > 0)) {
      int index = wildcardFind(terminator, _partial);
      if (index < 0) {
        break;
      }
      if (stripTerminator) {
        ByteArray message = ByteArray(_partial.take(index).toList().length);
        for (int i = 0; i < _partial.take(index).toList().length; i++) {
          message.writeByte(_partial.take(index).toList()[i]);
        }
        _controller.add(message);
      } else {
        ByteArray message = ByteArray(_partial.take(index + terminator!.length).toList().length);
        for (int i = 0; i < _partial.take(index + terminator!.length).toList().length; i++) {
          message.writeByte(_partial.take(index + terminator!.length).toList()[i]);
        }
        _controller.add(message);
      }

      _partial = _partial.sublist(index + terminator!.length);
    }
  }

  @override
  Stream<ByteArray> bind(Stream<ByteArray> stream) {
    this._stream = stream;
    return _controller.stream as Stream<ByteArray>;
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() => StreamTransformer.castFrom<ByteArray, ByteArray, RS, RT>(this);

  @override
  void dispose() {
    _controller.close();
  }
}

/// This transformer takes an incoming stream and splits it
/// along the "terminator" marks and returns a String! Great
/// for parsing incoming serial streams that end on \r\n.
class TerminatedStringTransformer implements DisposableStreamTransformer<ByteArray, String> {
  bool? cancelOnError;
  final ByteArray? terminator;
  final int maxLen; // maximum length the partial buffer will hold before it starts flushing.
  final stripTerminator;

  late StreamController _controller;
  StreamSubscription? _subscription;
  late Stream<ByteArray> _stream;
  late List<int> _partial;

  /// Splits the incoming stream at the given terminator sequence
  /// and converts to input to a string.
  ///
  /// maxLen is the maximum number of bytes that will be collected
  /// before a terminator is detected. If more data arrives the oldest
  /// bytes will be discarded.
  /// terminator is a ByteArray of bytes.
  /// stripTerminator is a boolean indicating if the terminator should
  /// remain attached in the output.
  ///
  /// This constructor creates a single string stream
  TerminatedStringTransformer({bool sync: false, this.cancelOnError, this.terminator, this.maxLen = 1024, this.stripTerminator = true}) {
    _partial = [];
    _controller = new StreamController<String>(
        onListen: _onListen,
        onCancel: _onCancel,
        onPause: () {
          _subscription!.pause();
        },
        onResume: () {
          _subscription!.resume();
        },
        sync: sync);
  }

  /// Splits the incoming stream at the given terminator sequence
  /// and converts to input to a string.
  ///
  /// maxLen is the maximum number of bytes that will be collected
  /// before a terminator is detected. If more data arrives the oldest
  /// bytes will be discarded.
  /// terminator is a ByteArray of bytes.
  /// stripTerminator is a boolean indicating if the terminator should
  /// remain attached in the output.
  ///
  /// This constructor creates a broadcast string stream
  TerminatedStringTransformer.broadcast({bool sync: false, this.cancelOnError, this.terminator, this.maxLen = 1024, this.stripTerminator = true}) {
    _partial = [];
    _controller = new StreamController<String>.broadcast(onListen: _onListen, onCancel: _onCancel, sync: sync);
  }

  void _onListen() {
    _subscription = _stream.listen(onData, onError: _controller.addError, onDone: _controller.close, cancelOnError: cancelOnError);
  }

  void _onCancel() {
    _subscription!.cancel();
    _subscription = null;
  }

  void onData(ByteArray data) {
    if (_partial.length > maxLen) {
      _partial = _partial.sublist(_partial.length - maxLen);
    }
    for (int i = 0; i < data.length; i++) {
      _partial.add(data[i]);
    }

    while (((_partial.length - terminator!.length) > 0)) {
      int index = wildcardFind(terminator, _partial);
      if (index < 0) {
        break;
      }
      if (stripTerminator) {
        ByteArray message = ByteArray(_partial.take(index).toList().length);
        for (int i = 0; i < _partial.take(index).toList().length; i++) {
          message.writeByte(_partial.take(index).toList()[i]);
        }
        List<int> dataOut = [];
        for (int i = 0; i < message.length; i++) {
          dataOut.add(message[i]);
        }
        _controller.add(String.fromCharCodes(dataOut));
      } else {
        ByteArray message = ByteArray(_partial.take(index + terminator!.length).toList().length);
        for (int i = 0; i < _partial.take(index + terminator!.length).toList().length; i++) {
          message.writeByte(_partial.take(index + terminator!.length).toList()[i]);
        }
        List<int> dataOut = [];
        for (int i = 0; i < message.length; i++) {
          dataOut.add(message[i]);
        }
        _controller.add(String.fromCharCodes(dataOut));
      }
      _partial = _partial.sublist(index + terminator!.length);
    }
  }

  @override
  Stream<String> bind(Stream<ByteArray> stream) {
    this._stream = stream;
    return _controller.stream as Stream<String>;
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() => StreamTransformer.castFrom<ByteArray, String, RS, RT>(this);

  @override
  void dispose() {
    _controller.close();
  }
}

/// Assembles messages that start with a fixed sequence of zero or more magic
/// bytes followed by a single byte that indicates the length of the rest of
/// the packet.
/// null is accepted as a wildcard byte.
/// <MAGIC BYTE> <LENGTH> <DATA1> <DATA2> ,...
/// example: [0x25] magic
/// 0x25 0x02 0x01 0x02
///
/// example [null] magic (will match any header byte)
/// 0x60 0x03 0x01 0x03 0x02
/// 0x10 0x04 0x01 0x02 0x03 0x04
///
/// Will clear input if no data is received for at least 1 second.
class MagicHeaderAndLengthByteTransformer implements DisposableStreamTransformer<ByteArray, ByteArray> {
  final List<int?>? header;
  final Duration clearTimeout;
  late List<int> _partial;
  Timer? _timer;
  late bool _dataSinceLastTick;
  bool? cancelOnError;
  final int maxLen; // maximum length the partial buffer will hold before it starts flushing.

  late StreamController _controller;
  StreamSubscription? _subscription;
  late Stream<ByteArray> _stream;

  MagicHeaderAndLengthByteTransformer({bool sync: false, this.cancelOnError, this.header, this.maxLen = 1024, this.clearTimeout = const Duration(seconds: 1)}) {
    _partial = [];
    _controller = new StreamController<ByteArray>(
        onListen: _onListen,
        onCancel: _onCancel,
        onPause: () {
          _subscription!.pause();
        },
        onResume: () {
          _subscription!.resume();
        },
        sync: sync);
  }

  MagicHeaderAndLengthByteTransformer.broadcast(
      {bool sync: false, this.cancelOnError, this.header, this.maxLen = 1024, this.clearTimeout = const Duration(seconds: 1)}) {
    _partial = [];
    _controller = new StreamController<ByteArray>.broadcast(onListen: _onListen, onCancel: _onCancel, sync: sync);
  }

  void _onListen() {
    _startTimer();
    _subscription = _stream.listen(onData, onError: _controller.addError, onDone: _controller.close, cancelOnError: cancelOnError);
  }

  void _onCancel() {
    _stopTimer();
    _subscription!.cancel();
    _subscription = null;
  }

  void onData(ByteArray data) {
    _dataSinceLastTick = true;
    if (_partial.length > maxLen) {
      _partial = _partial.sublist(_partial.length - maxLen);
    }
    for (int i = 0; i < data.length; i++) {
      _partial.add(data[i]);
    }

    while (_partial.length > 0) {
      int index = wildcardFind(header, _partial);
      if (index < 0) {
        return;
      }

      if (index > 0) {
        _partial = _partial.sublist(index);
      }

      if (_partial.length < header!.length + 1) {
        // not completely arrived yet.
        return;
      }

      int len = _partial[header!.length];
      if (_partial.length < len + header!.length + 1) {
        // not completely arrived yet.
        return;
      }
      ByteArray dataOut = ByteArray(_partial.sublist(0, len + header!.length + 1).length);
      for (int i = 0; i < _partial.sublist(0, len + header!.length + 1).length; i++) {
        dataOut.writeByte(_partial.sublist(0, len + header!.length + 1)[i]);
      }
      _controller.add(dataOut);
      _partial = _partial.sublist(len + header!.length + 1);
    }
  }

  @override
  Stream<ByteArray> bind(Stream<ByteArray> stream) {
    this._stream = stream;
    return _controller.stream as Stream<ByteArray>;
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() => StreamTransformer.castFrom<ByteArray, ByteArray, RS, RT>(this);

  void _onTimer(Timer timer) {
    if (_partial.length > 0 && !_dataSinceLastTick) {
      _partial.clear();
    }
    _dataSinceLastTick = false;
  }

  void _stopTimer() {
    _timer!.cancel();
    _timer = null;
  }

  void _startTimer() {
    _dataSinceLastTick = false;
    _timer = Timer.periodic(clearTimeout, this._onTimer);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
