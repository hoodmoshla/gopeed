import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopeed/api/model/create_task.dart';
import 'package:gopeed/api/model/resolve_result.dart';
import 'package:gopeed/api/model/resolve_task.dart';
import 'package:gopeed/api/model/resource.dart';
import 'package:gopeed/core/capabilities/app_capabilities.dart';
import 'package:gopeed/core/capabilities/capability_rpc.dart';
import 'package:gopeed/core/capabilities/gopeed_capability.dart';
import 'package:gopeed/features/tasks/presentation/pages/share_popup_page.dart';
import 'package:gopeed/shared/theme/app_component_themes.dart';
import 'package:gopeed/shared/theme/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('gopeed.com/app'),
      (call) async {
        if (call.method == 'moveTaskToBack') return true;
        if (call.method == 'finish') return null;
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('gopeed.com/app'),
      null,
    );
  });

  testWidgets('SharePopupPage resolves and creates task with selected quality', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CreateTask? submittedTask;
    final registry = CapabilityRegistry(createAppCapabilityCodecs())
      ..bind(GopeedMethods.resolve, (ResolveTask req) {
        return ResolveResult(
          id: 'test-res-id',
          res: Resource(
            name: 'Test YouTube Video Title',
            size: 50000000,
            files: [
              FileInfo(name: '1080p FHD (video/mp4)', size: 45000000),
              FileInfo(name: '720p HD (video/mp4)', size: 25000000),
              FileInfo(name: '128kbps (audio/mp3)', size: 5000000),
            ],
          ),
        );
      })
      ..bind(GopeedMethods.createTask, (CreateTask req) {
        submittedTask = req;
        return 'created-task-id';
      });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appCapabilitiesProvider.overrideWithValue(AppCapabilities(LocalCapabilityInvoker(registry)))],
        child: shad.ShadcnApp(
          theme: AppTheme.light(),
          materialTheme: AppTheme.materialLight(),
          home: const AppComponentThemes(
            child: SharePopupPage(initialUrl: 'https://youtu.be/dQw4w9WgXcQ?si=test1234', showToastOnSubmit: false),
          ),
        ),
      ),
    );

    // Initial loading frame
    await tester.pump();
    // Resolve complete frame
    await tester.pumpAndSettle();

    // Verify Title and host rendered
    expect(find.text('Test YouTube Video Title'), findsOneWidget);
    expect(find.text('youtu.be'), findsOneWidget);

    // Verify Video and Audio sections
    expect(find.text('فيديو (Video)'), findsOneWidget);
    expect(find.text('صوت (Audio)'), findsOneWidget);
    expect(find.text('1080p FHD (video/mp4)'), findsOneWidget);
    expect(find.text('720p HD (video/mp4)'), findsOneWidget);
    expect(find.text('128kbps (audio/mp3)'), findsOneWidget);

    // Select second video option (720p)
    await tester.tap(find.text('720p HD (video/mp4)'));
    await tester.pumpAndSettle();

    // Tap Download Button
    await tester.tap(find.text('بدء التنزيل'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify task creation
    expect(submittedTask, isNotNull);
    expect(submittedTask?.rid, 'test-res-id');
    expect(submittedTask?.opts?.selectFiles, [1]);
  });

  testWidgets('SharePopupPage handles resolve failure with direct download option', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CreateTask? submittedTask;
    final registry = CapabilityRegistry(createAppCapabilityCodecs())
      ..bind(GopeedMethods.resolve, (ResolveTask req) {
        throw StateError('Cannot resolve URL');
      })
      ..bind(GopeedMethods.createTask, (CreateTask req) {
        submittedTask = req;
        return 'created-task-id';
      });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appCapabilitiesProvider.overrideWithValue(AppCapabilities(LocalCapabilityInvoker(registry)))],
        child: shad.ShadcnApp(
          theme: AppTheme.light(),
          materialTheme: AppTheme.materialLight(),
          home: const AppComponentThemes(
            child: SharePopupPage(initialUrl: 'https://example.com/file.zip', showToastOnSubmit: false),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify direct download option is displayed
    expect(find.text('تنزيل الرابط المباشر'), findsOneWidget);

    // Tap Download Button
    await tester.tap(find.text('بدء التنزيل'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(submittedTask, isNotNull);
    expect(submittedTask?.req?.url, 'https://example.com/file.zip');
  });

  testWidgets('SharePopupPage dismisses on close without creating task', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var dismissed = false;
    var taskCreated = false;
    final registry = CapabilityRegistry(createAppCapabilityCodecs())
      ..bind(GopeedMethods.resolve, (ResolveTask req) {
        return ResolveResult(
          id: 'test-id',
          res: Resource(
            name: 'Video',
            files: [FileInfo(name: 'file.mp4', size: 1000)],
          ),
        );
      })
      ..bind(GopeedMethods.createTask, (_) {
        taskCreated = true;
        return 'id';
      });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appCapabilitiesProvider.overrideWithValue(AppCapabilities(LocalCapabilityInvoker(registry)))],
        child: shad.ShadcnApp(
          theme: AppTheme.light(),
          materialTheme: AppTheme.materialLight(),
          home: AppComponentThemes(
            child: SharePopupPage(initialUrl: 'https://example.com/video.mp4', onDismissed: () => dismissed = true),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Tap Close Icon (X)
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    expect(taskCreated, isFalse);
  });
}
