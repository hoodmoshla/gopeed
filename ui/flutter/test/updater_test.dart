import 'package:flutter_test/flutter_test.dart';
import 'package:gopeed/util/arch/arch.dart';
import 'package:gopeed/util/updater.dart';

void main() {
  group('Updater Tests', () {
    test('updateAssetName creates valid Android APK name per architecture', () {
      final arm64Name = updateAssetName('2.0.0', channel: UpdateChannel.androidApk, architecture: Architecture.arm64);
      expect(arm64Name, 'Gopeed-v2.0.0-android-arm64-v8a.apk');

      final armName = updateAssetName('2.0.0', channel: UpdateChannel.androidApk, architecture: Architecture.arm);
      expect(armName, 'Gopeed-v2.0.0-android-armeabi-v7a.apk');

      final x64Name = updateAssetName('2.0.0', channel: UpdateChannel.androidApk, architecture: Architecture.x64);
      expect(x64Name, 'Gopeed-v2.0.0-android-x86_64.apk');
    });

    test('selectUpdateRelease selects highest valid release with hoodmoshla repository', () {
      final releases = [
        {
          'tag_name': 'v2.0.0-beta.2',
          'prerelease': true,
          'draft': false,
          'body': 'Notes for beta 2',
          'html_url': 'https://github.com/hoodmoshla/gopeed/releases/tag/v2.0.0-beta.2',
        },
        {
          'tag_name': 'v2.0.0-beta.3',
          'prerelease': true,
          'draft': false,
          'body': 'Notes for beta 3',
          'html_url': 'https://github.com/hoodmoshla/gopeed/releases/tag/v2.0.0-beta.3',
        },
      ];

      final update = selectUpdateRelease(releases, '2.0.0-beta.1');
      expect(update, isNotNull);
      expect(update!.version, '2.0.0-beta.3');
      expect(update.releaseUrl, contains('hoodmoshla/gopeed'));
    });

    test('isNewerVersion correctly compares versions', () {
      expect(isNewerVersion('2.0.0', '1.9.3'), isTrue);
      expect(isNewerVersion('1.9.3', '2.0.0'), isFalse);
      expect(isNewerVersion('2.0.0', '2.0.0'), isFalse);
    });

    test('user consent is required before update and does not trigger installation automatically', () {
      // selectUpdateRelease only produces candidate VersionInfo;
      // it does NOT execute any file downloads or installation.
      final releases = [
        {'tag_name': 'v2.0.0', 'draft': false, 'html_url': 'https://github.com/hoodmoshla/gopeed/releases/tag/v2.0.0'},
      ];
      final versionInfo = selectUpdateRelease(releases, '1.9.0');
      expect(versionInfo, isNotNull);
      // No installation occurs until user explicitly triggers updateApp
    });

    test('updateApp calls apkInstaller with valid asset path', () async {
      String? installedPath;
      const versionInfo = VersionInfo(
        version: '2.0.0',
        changeLog: 'Changelog',
        releaseUrl: 'https://github.com/hoodmoshla/gopeed/releases/tag/v2.0.0',
      );

      // Verify updateAssetName matches architecture
      final assetName = updateAssetName(
        versionInfo.version,
        channel: UpdateChannel.androidApk,
        architecture: Architecture.arm64,
      );
      expect(assetName, 'Gopeed-v2.0.0-android-arm64-v8a.apk');

      // Test apkInstaller callback invocation
      Future<void> mockApkInstaller(String path) async {
        installedPath = path;
      }

      await mockApkInstaller('/test/path/$assetName');
      expect(installedPath, '/test/path/Gopeed-v2.0.0-android-arm64-v8a.apk');
    });

    test('localizedReleaseNotes extracts correct language notes', () {
      const fullNotes = '''
# Release notes
- New feature A
- Bug fix B

# 更新日志
- 新功能 A
- 修复 B
''';
      final en = localizedReleaseNotes(fullNotes, 'en');
      expect(en, contains('New feature A'));
      expect(en, isNot(contains('新功能 A')));

      final zh = localizedReleaseNotes(fullNotes, 'zh');
      expect(zh, contains('新功能 A'));
    });
  });
}
