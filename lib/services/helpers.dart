import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vyajan/services/constants.dart';

String getVersion() {
  return appVersion;
}

Future<String?> getLatestVersion() async {
  try {
    final response = await http.get(Uri.parse('$rawGithubUrl/VERSION'));

    if (response.statusCode == 200) {
      return response.body.trim();
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}

bool isYouTubeUrl(String url) {
  return url.toLowerCase().contains('youtube.com/') ||
      url.toLowerCase().contains('youtu.be/');
}

bool isInstagramUrl(String url) {
  return url.toLowerCase().contains('instagram.com/');
}

bool isTwitterUrl(String url) {
  return url.toLowerCase().contains('twitter.com') ||
      url.toLowerCase().contains('x.com');
}

bool isLinkedInUrl(String url) {
  return url.toLowerCase().contains('linkedin.com');
}

bool isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && uri.hasAuthority;
  } catch (e) {
    return false;
  }
}

Future<String?> getYouTubeThumbnail(String url) async {
  try {
    String? videoId;
    String? playlistId;
    final uri = Uri.parse(url.trim());

    // Handle youtu.be URLs
    if (uri.host == 'youtu.be') {
      videoId = uri.pathSegments.firstOrNull;
    }
    // Handle youtube.com URLs
    else if (uri.host == 'youtube.com' || uri.host == 'www.youtube.com') {
      // Handle shorts
      if (uri.pathSegments.contains('shorts')) {
        videoId = uri.pathSegments[uri.pathSegments.indexOf('shorts') + 1];
      }
      // Handle watch URLs
      else if (uri.pathSegments.contains('watch')) {
        videoId = uri.queryParameters['v'];
        playlistId = uri.queryParameters['list'];
      }
      // Handle playlist URLs
      else if (uri.pathSegments.contains('playlist')) {
        playlistId = uri.queryParameters['list'];
      }
    }

    if (videoId != null) {
      // Try different quality options for videos
      final qualities = [
        'maxresdefault', // 1920x1080
        'sddefault', // 640x480
        'hqdefault', // 480x360
        'mqdefault', // 320x180
        'default', // 120x90
      ];

      for (final quality in qualities) {
        final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/$quality.jpg';
        if (await _isImageAvailable(thumbnailUrl)) {
          return thumbnailUrl;
        }
      }
    }

    if (playlistId != null) {
      try {
        // First try: Direct playlist thumbnail URL patterns
        final playlistPatterns = [
          'https://img.youtube.com/vi/$playlistId/hqdefault.jpg',
          'https://i.ytimg.com/vi/$playlistId/hqdefault.jpg',
          'https://i.ytimg.com/an_webp/$playlistId/mqdefault_6s.webp?du=3000&sqp=1',
          'https://i.ytimg.com/vi/$playlistId/0.jpg',
          'https://i.ytimg.com/vi/$playlistId/1.jpg',
          'https://i.ytimg.com/vi/$playlistId/2.jpg',
          'https://i.ytimg.com/vi/$playlistId/3.jpg',
        ];

        for (final pattern in playlistPatterns) {
          if (await _isImageAvailable(pattern)) {
            return pattern;
          }
        }

        // Second try: OEmbed approach
        final oembedUrl =
            'https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/playlist?list=$playlistId';
        final oembedResponse = await http.get(Uri.parse(oembedUrl));

        if (oembedResponse.statusCode == 200) {
          final data = json.decode(oembedResponse.body);
          final thumbnailUrl = data['thumbnail_url'] as String?;
          if (thumbnailUrl != null && await _isImageAvailable(thumbnailUrl)) {
            return thumbnailUrl;
          }
        }

        // Third try: Use playlist page to extract first video ID
        final playlistUrl = 'https://www.youtube.com/playlist?list=$playlistId';
        final response = await http.get(Uri.parse(playlistUrl));

        if (response.statusCode == 200) {
          // Look for video ID in the HTML response
          final videoIdMatch =
              RegExp(r'"videoId":"([^"]+)"').firstMatch(response.body);
          if (videoIdMatch != null) {
            final firstVideoId = videoIdMatch.group(1);
            if (firstVideoId != null) {
              // Try getting thumbnail of the first video
              for (final quality in ['maxresdefault', 'hqdefault']) {
                final firstVideoThumbnail =
                    'https://img.youtube.com/vi/$firstVideoId/$quality.jpg';
                if (await _isImageAvailable(firstVideoThumbnail)) {
                  return firstVideoThumbnail;
                }
              }
            }
          }
        }
      } catch (e) {
        // If any of the additional playlist approaches fail, continue to next approach
      }
    }

    return null;
  } catch (e) {
    return null;
  }
}

Future<bool> _isImageAvailable(String url) async {
  try {
    final response = await http.head(Uri.parse(url));
    return response.statusCode == 200 &&
        response.headers['content-type']?.startsWith('image/') == true;
  } catch (e) {
    return false;
  }
}

Future<String?> getInstagramThumbnail(String url) async {
  try {
    final uri = Uri.parse(url.trim());

    if (uri.host != 'www.instagram.com' && uri.host != 'instagram.com') {
      return null;
    }

    final pathSegments = uri.pathSegments;

    // Check if it's a post
    if (pathSegments.contains('p')) {
      final contentId = pathSegments[pathSegments.indexOf('p') + 1];

      final thumbnailUrl =
          'https://www.instagram.com/p/$contentId/media/?size=t';

      return thumbnailUrl;
    }

    print('\n❌ Not a valid Instagram post URL');
    return null;
  } catch (e) {
    print('\n❌ Error: $e');
    return null;
  }
}

class TwitterData {
  final String? html;
  final String? text;
  final String? authorName;

  TwitterData({
    this.html,
    this.text,
    this.authorName,
  });

  @override
  String toString() {
    return 'TwitterData(authorName: $authorName, text: $text';
  }
}

Future<TwitterData?> getTwitterData(String url) async {
  try {
    final uri = Uri.parse(url.trim());

    if (uri.host != 'twitter.com' && uri.host != 'x.com') {
      return null;
    }

    final pathSegments = uri.pathSegments;

    // Check if it's a tweet
    if (pathSegments.contains('status')) {
      final username = pathSegments[0];
      final contentId = pathSegments[pathSegments.indexOf('status') + 1];

      // Construct the full tweet URL and encode it
      final tweetUrl = 'https://twitter.com/$username/status/$contentId';
      final encodedUrl = Uri.encodeComponent(tweetUrl);

      // Create oEmbed API URL with maxwidth to ensure we get the largest possible preview
      final oembedUrl =
          'https://publish.twitter.com/oembed?url=$encodedUrl&omit_script=true&maxwidth=550';

      final response = await http.get(Uri.parse(oembedUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final html = data['html'] as String?;
        final authorName = data['author_name'] as String?;

        // Extract text content from HTML
        final textContent = html?.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (textContent != null) {}

        return TwitterData(
          html: html,
          text: textContent,
          authorName: authorName,
        );
      } else {
        return null;
      }
    }

    return null;
  } catch (e) {
    print('\nError: $e');
    return null;
  }
}
