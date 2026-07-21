// Core protocol tests: length-prefixed framing must survive arbitrary
// stream chunking (the essence of reliable TCP message reassembly).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pim/core/protocol/framing.dart';
import 'package:pim/core/protocol/wire_message.dart';

void main() {
  test('FrameReader reassembles a single frame (kind + body)', () async {
    final reader = FrameReader();
    final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
    final encoded = FrameCodec.encode(FrameKind.control, payload);

    final frames = <Uint8List>[];
    reader.frames.listen(frames.add);

    reader.add(encoded);
    await Future<void>.delayed(Duration.zero);

    expect(frames.length, 1);
    expect(frames.first.first, FrameKind.control);
    expect(frames.first.sublist(1), payload);
  });

  test('FrameReader handles bytes split across many chunks', () async {
    final reader = FrameReader();
    final payload = Uint8List.fromList(List<int>.generate(300, (i) => i % 256));
    final encoded = FrameCodec.encode(FrameKind.chunk, payload);

    final frames = <Uint8List>[];
    reader.frames.listen(frames.add);

    // Feed one byte at a time — the hardest fragmentation case.
    for (final byte in encoded) {
      reader.add(Uint8List.fromList([byte]));
    }
    await Future<void>.delayed(Duration.zero);

    expect(frames.length, 1);
    expect(frames.first.first, FrameKind.chunk);
    expect(frames.first.sublist(1), payload);
  });

  test('FrameReader splits two frames arriving in one chunk', () async {
    final reader = FrameReader();
    final a = FrameCodec.encode(FrameKind.control, Uint8List.fromList([10, 20]));
    final b =
        FrameCodec.encode(FrameKind.control, Uint8List.fromList([30, 40, 50]));
    final combined = Uint8List.fromList([...a, ...b]);

    final frames = <Uint8List>[];
    reader.frames.listen(frames.add);

    reader.add(combined);
    await Future<void>.delayed(Duration.zero);

    expect(frames.length, 2);
    expect(frames[0].sublist(1), Uint8List.fromList([10, 20]));
    expect(frames[1].sublist(1), Uint8List.fromList([30, 40, 50]));
  });

  test('WireMessage round-trips through encode/decode', () {
    final msg = WireMessage(MsgType.text, {'id': 'abc', 'body': 'привіт'});
    final decoded = WireMessage.decode(msg.encode());

    expect(decoded.type, MsgType.text);
    expect(decoded.str('id'), 'abc');
    expect(decoded.str('body'), 'привіт');
  });
}
