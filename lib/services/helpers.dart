bool isYouTubeUrl(String url) {
  return url.toLowerCase().contains('youtube.com/') ||
      url.toLowerCase().contains('youtu.be/');
}

bool isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && uri.hasAuthority;
  } catch (e) {
    return false;
  }
}

String? getYouTubeThumbnail(String url) {
  String? videoId;

  if (url.contains('youtube.com')) {
    final uri = Uri.parse(url);
    videoId = uri.queryParameters['v'];
  } else if (url.contains('youtu.be')) {
    videoId = url.split('/').last.split('?').first;
  }

  if (videoId != null) {
    return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
  }
  return null;
}
