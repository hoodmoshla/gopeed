import 'dart:async';

import 'package:flutter/material.dart' show Icons, Material;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart'
    hide Column, Expanded, Row, Spacer, Stack, Positioned, Flexible, StatefulBuilder, showToast;

import '../../../../api/model/create_task.dart';
import '../../../../api/model/options.dart' as api_options;
import '../../../../api/model/request.dart';
import '../../../../api/model/resolve_result.dart';
import '../../../../api/model/resolve_task.dart';
import '../../../../api/model/resource.dart';
import '../../../../core/capabilities/app_capabilities.dart';
import '../../../../core/utils/android_app_channel.dart';
import '../../../../core/utils/url_extractor.dart';
import '../../../../shared/theme/app_palette.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../util/util.dart';

class SharePopupPage extends ConsumerStatefulWidget {
  const SharePopupPage({
    super.key,
    required this.initialUrl,
    this.initialTitle,
    this.onDismissed,
    this.showToastOnSubmit = true,
  });

  final String initialUrl;
  final String? initialTitle;
  final VoidCallback? onDismissed;
  final bool showToastOnSubmit;

  @override
  ConsumerState<SharePopupPage> createState() => _SharePopupPageState();
}

class _SharePopupPageState extends ConsumerState<SharePopupPage> {
  late String _url;
  String? _title;
  bool _resolving = true;
  String? _resolveError;
  ResolveResult? _resolveResult;

  List<FileInfo> _videoFiles = [];
  List<FileInfo> _audioFiles = [];
  List<FileInfo> _otherFiles = [];

  // Selected file index within _resolveResult.res.files
  int _selectedGlobalIndex = 0;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _url = UrlExtractor.cleanUrl(widget.initialUrl);
    _title = widget.initialTitle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startResolve();
    });
  }

  Future<void> _startResolve() async {
    if (!mounted) return;
    setState(() {
      _resolving = true;
      _resolveError = null;
    });

    try {
      final gopeed = ref.read(gopeedServiceProvider);
      final result = await gopeed.resolve(ResolveTask(req: Request(url: _url)));

      if (!mounted) return;

      final files = result.res.files;
      final videoFiles = <FileInfo>[];
      final audioFiles = <FileInfo>[];
      final otherFiles = <FileInfo>[];

      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final name = f.name.toLowerCase();
        if (_isVideo(name)) {
          videoFiles.add(f);
        } else if (_isAudio(name)) {
          audioFiles.add(f);
        } else {
          otherFiles.add(f);
        }
      }

      int defaultSelection = 0;
      if (files.isNotEmpty) {
        // Default to first video or first file
        if (videoFiles.isNotEmpty) {
          defaultSelection = files.indexOf(videoFiles.first);
        } else {
          defaultSelection = 0;
        }
      }

      setState(() {
        _resolving = false;
        _resolveResult = result;
        if ((_title == null || _title!.isEmpty) && result.res.name.isNotEmpty) {
          _title = result.res.name;
        }
        _videoFiles = videoFiles;
        _audioFiles = audioFiles;
        _otherFiles = otherFiles;
        _selectedGlobalIndex = defaultSelection >= 0 ? defaultSelection : 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveError = e.toString();
      });
    }
  }

  bool _isVideo(String name) {
    return name.contains('.mp4') ||
        name.contains('.mkv') ||
        name.contains('.webm') ||
        name.contains('.flv') ||
        name.contains('.mov') ||
        name.contains('.ts') ||
        name.contains('1080p') ||
        name.contains('720p') ||
        name.contains('480p') ||
        name.contains('360p') ||
        name.contains('2160p') ||
        name.contains('video');
  }

  bool _isAudio(String name) {
    return name.contains('.mp3') ||
        name.contains('.m4a') ||
        name.contains('.aac') ||
        name.contains('.flac') ||
        name.contains('.wav') ||
        name.contains('.ogg') ||
        name.contains('.opus') ||
        name.contains('audio') ||
        name.contains('kbps');
  }

  Future<void> _handleDownload() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      final gopeed = ref.read(gopeedServiceProvider);
      final result = _resolveResult;

      if (result != null && result.res.files.isNotEmpty) {
        final selectedIndex = _selectedGlobalIndex;
        if (result.id.isNotEmpty) {
          await gopeed.createTask(
            CreateTask(
              rid: result.id,
              opts: api_options.Options(selectFiles: [selectedIndex]),
            ),
          );
        } else {
          final file = result.res.files[selectedIndex];
          await gopeed.createTask(
            CreateTask(
              req: file.req ?? Request(url: _url),
              opts: api_options.Options(name: file.name),
            ),
          );
        }
      } else {
        // Direct download without resolved streams
        await gopeed.createTask(CreateTask(req: Request(url: _url)));
      }

      if (widget.showToastOnSubmit && mounted) {
        showAppToast(context, 'تمت إضافة المهمة وبدأ التنزيل', type: AppToastType.success);
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _dismiss(submitted: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      if (widget.showToastOnSubmit) {
        showAppToast(context, 'حدث خطأ: $e', type: AppToastType.error);
      }
    }
  }

  Future<void> _dismiss({bool submitted = false}) async {
    widget.onDismissed?.call();
    if (context.mounted) {
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      }
    }
    await AndroidAppChannel.moveTaskToBack();
  }

  String _getHost(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host.replaceFirst('www.', '');
      }
    } catch (_) {}
    return 'رابط';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final host = _getHost(_url);
    final titleText = (_title != null && _title!.isNotEmpty) ? _title! : host;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: const Color(0x73000000), // Semi-transparent dimmed barrier
        child: Stack(
          children: [
            // Barrier tap to dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _downloading ? null : () => _dismiss(submitted: false),
                child: const SizedBox.expand(),
              ),
            ),
            // Bottom Sheet container
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(maxHeight: size.height * 0.85, maxWidth: 600),
                decoration: BoxDecoration(
                  color: palette.cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, -4))],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 8),
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: palette.textMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      // Header Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: palette.brand.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                host,
                                style: TextStyle(color: palette.brand, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تنزيل عبر Gopeed',
                                style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            GestureDetector(
                              onTap: _downloading ? null : () => _dismiss(submitted: false),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: palette.surfaceSoft.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, size: 18, color: palette.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Video/Content Preview Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.surfaceSoft.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.border.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: palette.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _videoFiles.isNotEmpty
                                      ? Icons.movie_outlined
                                      : (_audioFiles.isNotEmpty ? Icons.audiotrack_outlined : Icons.download),
                                  color: palette.brand,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      titleText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _url,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: palette.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Quality Selection Body
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: _buildQualitySection(palette),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Action Buttons (Download Button)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: PrimaryButton(
                          onPressed: _downloading ? null : _handleDownload,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_downloading)
                                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              else
                                const Icon(Icons.download_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _downloading ? 'جاري البدء...' : 'بدء التنزيل',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySection(AppPalette palette) {
    if (_resolving) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: 14),
            Text('جاري فحص الرابط وتحليل الجودات المتاحة...', style: TextStyle(color: palette.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    final result = _resolveResult;
    if (_resolveError != null || result == null || result.res.files.isEmpty) {
      // Direct Download Option
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(Icons.link, color: palette.brand, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تنزيل الرابط المباشر',
                    style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'سيتم تنزيل المحتوى مباشرة عبر محرك Gopeed',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: palette.brand, size: 20),
          ],
        ),
      );
    }

    final files = result.res.files;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_videoFiles.isNotEmpty) ...[
          _buildCategoryHeader('فيديو (Video)', Icons.videocam, palette),
          const SizedBox(height: 8),
          ..._videoFiles.map((file) {
            final globalIdx = files.indexOf(file);
            return _buildFileItem(file, globalIdx, palette);
          }),
          const SizedBox(height: 14),
        ],
        if (_audioFiles.isNotEmpty) ...[
          _buildCategoryHeader('صوت (Audio)', Icons.audiotrack, palette),
          const SizedBox(height: 8),
          ..._audioFiles.map((file) {
            final globalIdx = files.indexOf(file);
            return _buildFileItem(file, globalIdx, palette);
          }),
          const SizedBox(height: 14),
        ],
        if (_otherFiles.isNotEmpty) ...[
          _buildCategoryHeader('الملفات', Icons.insert_drive_file, palette),
          const SizedBox(height: 8),
          ..._otherFiles.map((file) {
            final globalIdx = files.indexOf(file);
            return _buildFileItem(file, globalIdx, palette);
          }),
        ],
      ],
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon, AppPalette palette) {
    return Row(
      children: [
        Icon(icon, size: 16, color: palette.brand),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFileItem(FileInfo file, int globalIndex, AppPalette palette) {
    final isSelected = _selectedGlobalIndex == globalIndex;
    final sizeText = file.size > 0 ? Util.fmtByte(file.size) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGlobalIndex = globalIndex;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? palette.brand.withValues(alpha: 0.08) : palette.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? palette.brand : palette.border.withValues(alpha: 0.7),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected ? palette.brand : palette.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? palette.brand : palette.textPrimary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (sizeText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sizeText,
                    style: TextStyle(color: palette.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
