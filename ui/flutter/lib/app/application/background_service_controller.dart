import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tasks/application/tasks_controller.dart';
import '../../features/tasks/domain/task_record.dart';
import '../../l10n/l10n.dart';
import 'android_foreground_service.dart';
import 'app_runtime_controller.dart';

/// Evaluates whether a set of tasks requires background processing.
class BackgroundServicePolicy {
  const BackgroundServicePolicy._();

  static bool isRequired(Iterable<TaskRecord>? tasks) {
    if (tasks == null) return false;
    return tasks.any(isTaskActive);
  }

  static bool isTaskActive(TaskRecord task) {
    return task.uploading || task.status == TaskStatus.downloading;
  }
}

/// Computes whether any active task requires keeping the foreground service alive.
final backgroundServiceRequiredProvider = Provider<bool>((ref) {
  final tasksState = ref.watch(tasksControllerProvider).value;
  if (tasksState == null) return false;
  return BackgroundServicePolicy.isRequired(tasksState.tasks);
});

typedef BackgroundServiceStartAction = Future<void> Function([AppLocalizations? l10n]);
typedef BackgroundServiceStopAction = Future<void> Function();

final backgroundServiceStartActionProvider = Provider<BackgroundServiceStartAction>((ref) {
  return AndroidForegroundService.start;
});

final backgroundServiceStopActionProvider = Provider<BackgroundServiceStopAction>((ref) {
  return AndroidForegroundService.stop;
});

final backgroundServiceControllerProvider = NotifierProvider<BackgroundServiceController, bool>(
  BackgroundServiceController.new,
);

class BackgroundServiceController extends Notifier<bool> {
  Future<void> _operationQueue = Future<void>.value();
  bool? _lastKnownRequired;
  String? _lastLocale;

  @override
  bool build() {
    final required = ref.watch(backgroundServiceRequiredProvider);
    final runtime = ref.watch(appRuntimeControllerProvider).value;
    final locale = runtime?.downloaderConfig.extra.locale ?? '';
    final l10n = appLocalizationsFor(locale);

    if (_lastKnownRequired != required || (required && _lastLocale != locale)) {
      _lastKnownRequired = required;
      _lastLocale = locale;
      unawaited(_reconcile(required, l10n));
    }

    return required;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _operationQueue.then((_) => action(), onError: (_, _) => action());
    _operationQueue = next;
    return next;
  }

  Future<void> _reconcile(bool required, AppLocalizations l10n) {
    return _enqueue(() async {
      state = required;
      if (required) {
        final start = ref.read(backgroundServiceStartActionProvider);
        await start(l10n);
      } else {
        final stop = ref.read(backgroundServiceStopActionProvider);
        await stop();
      }
    });
  }
}
