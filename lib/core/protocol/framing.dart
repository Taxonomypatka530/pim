import 'dart:async';
import 'dart:typed_data';

/// Frame payload kinds. The first byte of every frame payload says how to read
/// the rest: a JSON control message, or a raw binary file chunk.
class FrameKind {
  FrameKind._();
  static const int control = 0;
  static const int chunk = 1;
}

/// Length-prefixed framing for a byte stream.
///
/// Each frame on the wire is a 4-byte big-endian unsigned length followed by
/// exactly that many payload bytes. The payload's first byte is a [FrameKind];
/// the remainder is the body. This lets us recover discrete messages — and
/// distinguish JSON control frames from binary chunks — over a raw TCP stream.
class FrameCodec {
  FrameCodec._();

  /// Encodes [body] as a frame of the given [kind].
  static Uint8List encode(int kind, Uint8List body) {
    final len = 1 + body.length; // kind byte + body
    final out = Uint8List(4 + len);
    out[0] = (len >> 24) & 0xFF;
    out[1] = (len >> 16) & 0xFF;
    out[2] = (len >> 8) & 0xFF;
    out[3] = len & 0xFF;
    out[4] = kind & 0xFF;
    out.setRange(5, 5 + body.length, body);
    return out;
  }
}

/// Incrementally reassembles frames from arbitrarily-chunked socket data.
///
/// Feed raw bytes via [add]; complete frames are emitted on [frames].
class FrameReader {
  FrameReader({this.maxFrameBytes = 512 * 1024 * 1024});

  /// Safety guard against a malformed/hostile length prefix.
  final int maxFrameBytes;

  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>();

  Uint8List _buffer = Uint8List(0);
  int _start = 0;

  Stream<Uint8List> get frames => _controller.stream;

  void add(Uint8List data) {
    final remaining = _buffer.length - _start;
    final merged = Uint8List(remaining + data.length);
    merged.setRange(0, remaining, _buffer, _start);
    merged.setRange(remaining, merged.length, data);
    _buffer = merged;
    _start = 0;
    _drain();
  }

  void _drain() {
    while (_buffer.length - _start >= 4) {
      final p = _start;
      final len = (_buffer[p] << 24) |
          (_buffer[p + 1] << 16) |
          (_buffer[p + 2] << 8) |
          _buffer[p + 3];

      if (len < 0 || len > maxFrameBytes) {
        _controller.addError(
          StateError('Frame length out of range: $len'),
        );
        _start = _buffer.length; // discard the rest; caller will drop socket.
        return;
      }

      if (_buffer.length - _start - 4 < len) {
        return; // wait for more bytes.
      }

      final frame = Uint8List.fromList(
        Uint8List.sublistView(_buffer, _start + 4, _start + 4 + len),
      );
      _controller.add(frame);
      _start += 4 + len;
    }
  }

  Future<void> close() => _controller.close();
}
