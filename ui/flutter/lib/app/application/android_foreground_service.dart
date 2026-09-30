import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../l10n/l10n.dart';

/// Keeps the Android process alive while Gopeed is available for downloads.
class AndroidForegroundService {
  const AndroidForegroundService._();

  static Future<void> _taskQueue = Future<void>.value();

  static Future<void> _enqueue(Future<void> Function() action) {
    final next = _taskQueue.then((_) => action(), onError: (_, _) => action());
    _taskQueue = next;
    return next;
  }

  static Future<void> ensureRunning([AppLocalizations? l10n]) => start(l10n);

  static Future<void> start([AppLocalizations? l10n]) => _enqueue(() => _start(l10n));

  static Future<void> stop() => _enqueue(_stop);

  static Future<bool> isRunning() async {
    if (!Platform.isAndroid) return false;
    return FlutterForegroundTask.isRunningService;
  }

  static Future<void> _start([AppLocalizations? l10n]) async {
    if (!Platform.isAndroid) return;
    final localizations = l10n ?? appLocalizationsFor('');

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gopeed_service',
        channelName: localizations.androidForegroundServiceChannel,
        channelImportance: NotificationChannelImportance.LOW,
        showWhen: true,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Android 13+ requires runtime permission to show the service notification.
    // A denial only hides it from the notification drawer; the service can run.
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission == NotificationPermission.denied) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      _throwOnFailure(await FlutterForegroundTask.restartService());
      return;
    }

    _throwOnFailure(
      await FlutterForegroundTask.startService(
        notificationTitle: localizations.androidForegroundNotificationTitle,
        notificationText: localizations.androidForegroundNotificationText,
      ),
    );
  }

  static Future<void> _stop() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      _throwOnFailure(await FlutterForegroundTask.stopService());
    }
  }

  static void _throwOnFailure(ServiceRequestResult result) {
    if (result case ServiceRequestFailure(:final error)) {
      throw error;
    }
  }
}
