import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopeed/api/model/downloader_config.dart';
import 'package:gopeed/app/application/app_runtime_controller.dart';
import 'package:gopeed/app/application/background_service_controller.dart';
import 'package:gopeed/core/common/api_server_state.dart';
import 'package:gopeed/core/common/start_config.dart';
import 'package:gopeed/features/tasks/application/tasks_controller.dart';
import 'package:gopeed/features/tasks/domain/task_record.dart';
import 'package:gopeed/l10n/l10n.dart';

TaskRecord _makeTask({required String id, required TaskStatus status, bool uploading = false, String? uploadSpeed}) {
  return TaskRecord(
    id: id,
    name: 'task-$id',
    status: status,
    downloaded: '0 B',
    url: 'https://example.com/$id',
    storagePath: '/downloads/$id',
    files: const [],
    uploading: uploading,
    uploadSpeed: uploading ? (uploadSpeed ?? '100 KB/s') : null,
  );
}

class _TestTasksController extends TasksController {
  _TestTasksController(this._initialTasks);

  final List<TaskRecord> _initialTasks;

  @override
  Future<TasksState> build() async {
    return TasksState(tasks: _initialTasks);
  }

  void setTasks(List<TaskRecord> tasks) {
    state = AsyncValue.data(TasksState(tasks: tasks));
  }
}

class _TestRuntimeController extends AppRuntimeController {
  _TestRuntimeController([this._locale = 'en']);

  final String _locale;

  @override
  Future<AppRuntimeState> build() async {
    final config = DownloaderConfig();
    config.extra.locale = _locale;
    return AppRuntimeState(
      startConfig: StartConfig(),
      apiServerState: const ApiServerState(
        enabled: false,
        mcpEnabled: false,
        running: false,
        network: '',
        address: '',
        runningPort: 0,
        pendingApply: false,
        lastError: '',
      ),
      downloaderConfig: config,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundService', () {
    test('testBackgroundServicePolicy', () {
      // Empty or null task list does not require background service
      expect(BackgroundServicePolicy.isRequired(null), isFalse);
      expect(BackgroundServicePolicy.isRequired([]), isFalse);

      // Inactive tasks do not require service
      final pausedTask = _makeTask(id: '1', status: TaskStatus.paused);
      final completedTask = _makeTask(id: '2', status: TaskStatus.completed);
      final failedTask = _makeTask(id: '3', status: TaskStatus.failed);

      expect(BackgroundServicePolicy.isRequired([pausedTask]), isFalse);
      expect(BackgroundServicePolicy.isRequired([completedTask]), isFalse);
      expect(BackgroundServicePolicy.isRequired([failedTask]), isFalse);
      expect(BackgroundServicePolicy.isRequired([pausedTask, completedTask, failedTask]), isFalse);

      // Active downloading task requires service
      final downloadingTask = _makeTask(id: '4', status: TaskStatus.downloading);
      expect(BackgroundServicePolicy.isRequired([downloadingTask]), isTrue);
      expect(BackgroundServicePolicy.isRequired([pausedTask, downloadingTask]), isTrue);

      // Active uploading task requires service
      final uploadingTask = _makeTask(id: '5', status: TaskStatus.completed, uploading: true);
      expect(BackgroundServicePolicy.isRequired([uploadingTask]), isTrue);
      expect(BackgroundServicePolicy.isRequired([failedTask, uploadingTask]), isTrue);

      // Both downloading and uploading
      expect(BackgroundServicePolicy.isRequired([downloadingTask, uploadingTask]), isTrue);
    });

    test('testBackgroundServiceController', () async {
      final testTasks = _TestTasksController([]);
      final testRuntime = _TestRuntimeController('en');
      final startCalls = <AppLocalizations?>[];
      final stopCalls = <int>[];

      final container = ProviderContainer(
        overrides: [
          tasksControllerProvider.overrideWith(() => testTasks),
          appRuntimeControllerProvider.overrideWith(() => testRuntime),
          backgroundServiceStartActionProvider.overrideWithValue(([l10n]) async {
            startCalls.add(l10n);
          }),
          backgroundServiceStopActionProvider.overrideWithValue(() async {
            stopCalls.add(1);
          }),
        ],
      );
      addTearDown(container.dispose);

      // Listen to keep controller alive
      final sub = container.listen(backgroundServiceControllerProvider, (_, _) {});
      addTearDown(sub.close);

      // Allow initial build
      await container.pump();

      // Initially no active tasks: background service is not required
      expect(container.read(backgroundServiceRequiredProvider), isFalse);
      expect(container.read(backgroundServiceControllerProvider), isFalse);
      expect(startCalls, isEmpty);

      // Add a downloading task
      testTasks.setTasks([_makeTask(id: '1', status: TaskStatus.downloading)]);
      await container.pump();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(backgroundServiceRequiredProvider), isTrue);
      expect(container.read(backgroundServiceControllerProvider), isTrue);
      expect(startCalls.length, 1);
      expect(startCalls.first, isNotNull);

      // When task is completed, service should be stopped
      testTasks.setTasks([_makeTask(id: '1', status: TaskStatus.completed)]);
      await container.pump();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(backgroundServiceRequiredProvider), isFalse);
      expect(container.read(backgroundServiceControllerProvider), isFalse);
      expect(stopCalls.length, greaterThanOrEqualTo(1));
    });
  });
}
