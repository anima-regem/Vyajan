import 'dart:math';

import 'package:http/http.dart' as http;

import 'constants.dart';

String getVersion() => appVersion;

Future<String?> getLatestVersion() async {
  try {
    final response = await http.get(Uri.parse('$rawGithubUrl/VERSION'));
    if (response.statusCode == 200) {
      return response.body.trim();
    }
  } catch (_) {
    // Best effort update check.
  }
  return null;
}

bool isValidUrl(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return false;

  try {
    final uri = Uri.parse(input);
    return uri.hasScheme && uri.hasAuthority;
  } catch (_) {
    return false;
  }
}

String? extractSourceDomain(String url) {
  try {
    final host = Uri.parse(url).host.toLowerCase();
    if (host.startsWith('www.')) {
      return host.substring(4);
    }
    return host;
  } catch (_) {
    return null;
  }
}

String normalizeWhitespace(String input) {
  return input.replaceAll(RegExp(r'\s+'), ' ').replaceAll('\n', ' ').trim();
}

String summarizeToLength(
  String input, {
  int maxChars = 140,
}) {
  final cleaned = normalizeWhitespace(input);
  if (cleaned.length <= maxChars) {
    return cleaned;
  }

  final cut = cleaned.substring(0, maxChars);
  final lastSpace = cut.lastIndexOf(' ');
  if (lastSpace <= 0) {
    return '$cut...';
  }
  return '${cut.substring(0, lastSpace)}...';
}

double medianHours(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[mid];
  }
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

T? mostFrequent<T>(Iterable<T> values) {
  final counts = <T, int>{};
  for (final value in values) {
    counts.update(value, (count) => count + 1, ifAbsent: () => 1);
  }

  if (counts.isEmpty) {
    return null;
  }

  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

int clampInt(int value, int minValue, int maxValue) {
  return max(minValue, min(maxValue, value));
}
