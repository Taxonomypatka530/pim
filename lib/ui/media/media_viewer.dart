import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_view/photo_view.dart';

import '../../core/media_type.dart';

/// Opens [path] in the right in-app viewer for its media type.
/// Returns false if the type has no built-in viewer (caller should fall back
/// to opening it externally).
bool openMedia(BuildContext context, String path, String fileName) {
  final type = mediaTypeFromName(fileName);
  switch (type) {
    case MediaType.image:
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ImageViewerScreen(path: path, fileName: fileName),
      ));
      return true;
    case MediaType.video:
    case MediaType.audio:
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MediaPlayerScreen(
          path: path,
          fileName: fileName,
          isVideo: type == MediaType.video,
        ),
      ));
      return true;
    case MediaType.other:
      return false;
  }
}

/// Full-screen, pinch-to-zoom image viewer.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({
    super.key,
    required this.path,
    required this.fileName,
  });

  final String path;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(fileName, overflow: TextOverflow.ellipsis),
      ),
      body: PhotoView(
        imageProvider: FileImage(File(path)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 5,
        initialScale: PhotoViewComputedScale.contained,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stack) => const Center(
          child: Icon(Icons.broken_image_rounded,
              color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}

/// In-app player. Videos use media_kit's polished controls; audio gets our own
/// custom transport (art, seek bar, play/pause, timecodes).
class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({
    super.key,
    required this.path,
    required this.fileName,
    required this.isVideo,
  });

  final String path;
  final String fileName;
  final bool isVideo;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  late final Player _player;
  VideoController? _videoController;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _player = Player();
    if (widget.isVideo) {
      _videoController = VideoController(_player);
    }
    _subs.add(_player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(_player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    }));
    _player.open(Media(widget.path));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: Video(controller: _videoController!),
        ),
      );
    }
    return _AudioView(
      fileName: widget.fileName,
      position: _position,
      duration: _duration,
      playing: _playing,
      onSeek: (d) => _player.seek(d),
      onPlayPause: () => _player.playOrPause(),
    );
  }
}

class _AudioView extends StatelessWidget {
  const _AudioView({
    required this.fileName,
    required this.position,
    required this.duration,
    required this.playing,
    required this.onSeek,
    required this.onPlayPause,
  });

  final String fileName;
  final Duration position;
  final Duration duration;
  final bool playing;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlayPause;

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = duration.inMilliseconds.toDouble();
    final value =
        total <= 0 ? 0.0 : position.inMilliseconds.clamp(0, total).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(fileName, overflow: TextOverflow.ellipsis)),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Album-art placeholder.
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, Colors.black, 0.25)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(Icons.music_note_rounded,
                  size: 96, color: scheme.onPrimary),
            ),
            const SizedBox(height: 32),
            Text(
              fileName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                max: total <= 0 ? 1 : total,
                onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(position),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  Text(_fmt(duration),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FloatingActionButton.large(
              onPressed: onPlayPause,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
