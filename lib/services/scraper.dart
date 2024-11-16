import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

class WebScraper {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  static Future<Map<String, String?>> scrapeMetadata(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load page');
      }

      final document = parse(response.body);
      return {
        'title': _extractTitle(document),
        'description': _extractDescription(document),
        'image': _extractImage(document, url),
        'siteName': _extractSiteName(document, url),
        'url': url,
      };
    } catch (e) {
      print('Error scraping metadata: $e');
      return {
        'title': null,
        'description': null,
        'image': null,
        'siteName': null,
        'url': url,
      };
    }
  }

  static String? _extractTitle(Document document) {
    // Try multiple selectors in order of preference
    final selectors = [
      'meta[property="og:title"]',
      'meta[name="twitter:title"]',
      'meta[name="title"]',
      'title',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        if (selector == 'title') {
          return element.text.trim();
        } else {
          return element.attributes['content']?.trim();
        }
      }
    }
    return null;
  }

  static String? _extractDescription(Document document) {
    final selectors = [
      'meta[property="og:description"]',
      'meta[name="twitter:description"]',
      'meta[name="description"]',
      'meta[itemprop="description"]',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      final content = element?.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }

    // Fallback: Try to extract from first paragraph
    final firstParagraph = document.querySelector('p');
    if (firstParagraph != null) {
      final text = firstParagraph.text.trim();
      if (text.length > 150) {
        return '${text.substring(0, 147)}...';
      }
      return text;
    }

    return null;
  }

  static String? _extractImage(Document document, String baseUrl) {
    final selectors = [
      'meta[property="og:image"]',
      'meta[name="twitter:image"]',
      'meta[itemprop="image"]',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      final content = element?.attributes['content'];
      if (content != null && content.isNotEmpty) {
        return _normalizeUrl(content, baseUrl);
      }
    }

    // Fallback: Try to find first relevant image
    final img = document.querySelector('article img, main img, .content img');
    final imgSrc = img?.attributes['src'];
    return imgSrc != null ? _normalizeUrl(imgSrc, baseUrl) : null;
  }

  static String? _extractSiteName(Document document, String url) {
    final selectors = [
      'meta[property="og:site_name"]',
      'meta[name="application-name"]',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      final content = element?.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }

    // Fallback: Try to extract from canonical URL or original URL
    try {
      final canonical =
          document.querySelector('link[rel="canonical"]')?.attributes['href'];
      final uri = Uri.parse(canonical ?? url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return null;
    }
  }

  static String _normalizeUrl(String url, String baseUrl) {
    try {
      if (url.startsWith('//')) {
        return 'https:$url';
      }
      if (url.startsWith('/')) {
        final baseUri = Uri.parse(baseUrl);
        return '${baseUri.scheme}://${baseUri.host}$url';
      }
      if (!url.startsWith('http')) {
        final baseUri = Uri.parse(baseUrl);
        return '${baseUri.scheme}://${baseUri.host}/${url.startsWith('/') ? url.substring(1) : url}';
      }
      return url;
    } catch (_) {
      return url;
    }
  }
}
