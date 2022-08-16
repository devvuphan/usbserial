import 'dart:async';

import 'package:byte_array/byte_array.dart';

abstract class AsyncDataSinkSource {
  Future<void> write(ByteArray data);
  Stream<ByteArray>? get inputStream;
}
