enum MediaType { image, video, audio, other }

const Set<String> _imageExt = {
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'tiff', 'tif',
  'svg',
};
const Set<String> _videoExt = {
  'mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v', 'wmv', 'flv', '3gp', 'mpeg', 'mpg',
};
const Set<String> _audioExt = {
  'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'opus', 'wma', 'aiff', 'amr',
};

/// Classifies a file by its extension so we can pick the right in-app viewer.
MediaType mediaTypeFromName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return MediaType.other;
  final ext = name.substring(dot + 1).toLowerCase();
  if (_imageExt.contains(ext)) return MediaType.image;
  if (_videoExt.contains(ext)) return MediaType.video;
  if (_audioExt.contains(ext)) return MediaType.audio;
  return MediaType.other;
}
