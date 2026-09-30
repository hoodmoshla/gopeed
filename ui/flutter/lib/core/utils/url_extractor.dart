class UrlExtractor {
  UrlExtractor._();

  static final RegExp _urlRegex = RegExp(
    r'(?:(?:https?|ftp|ed2k)://|magnet:\?)[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  /// Extracts all candidate URLs found within [text].
  static List<String> extractUrls(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    final matches = _urlRegex.allMatches(text);
    final results = <String>[];
    for (final match in matches) {
      final raw = match.group(0);
      if (raw != null && raw.isNotEmpty) {
        final cleaned = cleanUrl(raw);
        if (isValidUrl(cleaned)) {
          results.add(cleaned);
        }
      }
    }
    return results;
  }

  /// Extracts the first valid actionable URL found within [text].
  static String? extractPrimaryUrl(String? text) {
    final urls = extractUrls(text);
    return urls.isNotEmpty ? urls.first : null;
  }

  /// Trims surrounding punctuation and strips tracking parameters while
  /// preserving functional query parameters (e.g. YouTube `v`, `t`, `list`).
  static String cleanUrl(String rawUrl) {
    var url = rawUrl.trim();

    // Strip wrapping quotes or brackets: "(http://...)", "<http://...>", etc.
    while (url.isNotEmpty) {
      final first = url[0];
      final last = url[url.length - 1];
      if ((first == '(' && last == ')') ||
          (first == '<' && last == '>') ||
          (first == '[' && last == ']') ||
          (first == '{' && last == '}') ||
          (first == '"' && last == '"') ||
          (first == "'" && last == "'")) {
        url = url.substring(1, url.length - 1).trim();
      } else {
        break;
      }
    }

    // Strip trailing punctuation often appended in conversation or prose
    while (url.isNotEmpty && _isTrailingPunctuation(url[url.length - 1])) {
      url = url.substring(0, url.length - 1).trim();
    }

    // Handle magnet links separately (do not strip query parameters)
    if (url.toLowerCase().startsWith('magnet:?')) {
      return url;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return url;
    }

    // Remove tracking query parameters
    if (uri.queryParameters.isNotEmpty) {
      final cleanParams = Map<String, String>.from(uri.queryParameters);
      const trackingKeys = {
        'si',
        'feature',
        'fbclid',
        'igsh',
        'utm_source',
        'utm_medium',
        'utm_campaign',
        'utm_term',
        'utm_content',
        'ref',
        'ref_src',
        'share_id',
        's', // Twitter / X tracking param like ?s=20
      };

      var changed = false;
      for (final key in trackingKeys) {
        if (cleanParams.containsKey(key)) {
          cleanParams.remove(key);
          changed = true;
        }
      }

      if (changed) {
        if (cleanParams.isEmpty) {
          return Uri(
            scheme: uri.scheme,
            userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
            host: uri.host,
            port: uri.hasPort ? uri.port : null,
            path: uri.path,
            fragment: uri.hasFragment ? uri.fragment : null,
          ).toString();
        }
        return uri.replace(queryParameters: cleanParams).toString();
      }
    }

    return url;
  }

  /// Checks if [url] is a valid URL with an acceptable scheme.
  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.trim().toLowerCase();
    if (lower.startsWith('magnet:?')) {
      return lower.length > 'magnet:?'.length;
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https' && scheme != 'ftp' && scheme != 'ed2k') {
      return false;
    }
    return uri.host.isNotEmpty && (uri.host.contains('.') || uri.host == 'localhost');
  }

  static bool _isTrailingPunctuation(String char) {
    return char == '.' ||
        char == ',' ||
        char == '!' ||
        char == '?' ||
        char == ';' ||
        char == ':' ||
        char == ')' ||
        char == ']' ||
        char == '}' ||
        char == '>' ||
        char == '"' ||
        char == "'" ||
        char == '»' ||
        char == '«' ||
        char == '؛' ||
        char == '،';
  }
}
