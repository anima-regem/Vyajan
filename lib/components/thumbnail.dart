import 'package:flutter/material.dart';
import 'package:vyajan/services/helpers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class _YouTubeThumbnailCache {
  static final Map<String, Future<String?>> _cache = {};

  static Future<String?> getThumbnail(String url) {
    if (!_cache.containsKey(url)) {
      _cache[url] = getYouTubeThumbnail(url);
    }
    return _cache[url]!;
  }
}

class CachedYouTubeThumbnail extends StatelessWidget {
  final String url;

  const CachedYouTubeThumbnail({
    required this.url,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: FutureBuilder<String?>(
        future: _YouTubeThumbnailCache.getThumbnail(url),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              // Enable image caching
              cacheWidth: 800, // Adjust based on your needs
              cacheHeight: 450,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 100),
            );
          }
          // Skeleton with play button placeholder
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CachedInstagramThumbnail extends StatelessWidget {
  final String url;

  const CachedInstagramThumbnail({
    super.key,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: getInstagramThumbnail(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey,
              ),
            ),
          );
        }

        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          width: double.infinity,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }
}
