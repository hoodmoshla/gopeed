import 'package:flutter_test/flutter_test.dart';
import 'package:gopeed/core/utils/url_extractor.dart';

void main() {
  group('UrlExtractor Tests', () {
    test('extracts and cleans YouTube link with tracking parameters', () {
      const input =
          'Check out this awesome video: https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=123456789&feature=shared on YouTube!';
      final url = UrlExtractor.extractPrimaryUrl(input);
      expect(url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('extracts YouTube short link with si and feature tracking', () {
      const input = 'https://youtu.be/dQw4w9WgXcQ?si=abcdef12345';
      final url = UrlExtractor.extractPrimaryUrl(input);
      expect(url, 'https://youtu.be/dQw4w9WgXcQ');
    });

    test('extracts Facebook watch link and cleans ref tracking', () {
      const input = 'Amazing video here: https://fb.watch/abc123xyz/?ref=sharing';
      final url = UrlExtractor.extractPrimaryUrl(input);
      expect(url, 'https://fb.watch/abc123xyz/');
    });

    test('extracts X/Twitter status link and cleans tracking', () {
      const input = 'Breaking news: https://x.com/flutterdev/status/1234567890?s=20 (must read)';
      final url = UrlExtractor.extractPrimaryUrl(input);
      expect(url, 'https://x.com/flutterdev/status/1234567890');
    });

    test('extracts link surrounded by Arabic text and Arabic punctuation', () {
      const input = 'شاهد هذا الشرح الممتاز: https://example.com/tutorial.mp4، أتمنى لك التوفيق!';
      final url = UrlExtractor.extractPrimaryUrl(input);
      expect(url, 'https://example.com/tutorial.mp4');
    });

    test('extracts link enclosed in parentheses and brackets', () {
      const input = '(https://example.com/file.zip)';
      final url = UrlExtractor.extractPrimaryUrl(input);
      expect(url, 'https://example.com/file.zip');
    });

    test('extracts magnet links without altering parameters', () {
      const input = 'Torrent: magnet:?xt=urn:btih:d4c679a94025a1e2f9d51e7a5c8846c4f03914a8&dn=Ubuntu';
      final url = UrlExtractor.extractPrimaryUrl(input);
      expect(url, 'magnet:?xt=urn:btih:d4c679a94025a1e2f9d51e7a5c8846c4f03914a8&dn=Ubuntu');
    });

    test('extracts multiple URLs in text', () {
      const input = 'First: https://example.com/one.mp4 and second: https://example.com/two.mp4';
      final urls = UrlExtractor.extractUrls(input);
      expect(urls.length, 2);
      expect(urls[0], 'https://example.com/one.mp4');
      expect(urls[1], 'https://example.com/two.mp4');
    });

    test('returns null for text without valid URLs', () {
      const input = 'Hello world this is just regular text with no links whatsoever.';
      final url = UrlExtractor.extractPrimaryUrl(input);
      expect(url, isNull);
      expect(UrlExtractor.extractUrls(input), isEmpty);
    });

    test('correctly identifies valid and invalid URLs', () {
      expect(UrlExtractor.isValidUrl('https://google.com'), isTrue);
      expect(UrlExtractor.isValidUrl('http://localhost:8080/test'), isTrue);
      expect(UrlExtractor.isValidUrl('magnet:?xt=urn:btih:123'), isTrue);
      expect(UrlExtractor.isValidUrl('not a url'), isFalse);
      expect(UrlExtractor.isValidUrl('http://'), isFalse);
      expect(UrlExtractor.isValidUrl(null), isFalse);
    });
  });
}
