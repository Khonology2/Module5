// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/learning_assignment_service.dart';
import 'package:pdh/utils/learning_video_url.dart';
import 'package:pdh/widgets/custom_logo_loader.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EmployeeLearningWatchScreen extends StatefulWidget {
  const EmployeeLearningWatchScreen({super.key});

  @override
  State<EmployeeLearningWatchScreen> createState() =>
      _EmployeeLearningWatchScreenState();
}

class _EmployeeLearningWatchScreenState extends State<EmployeeLearningWatchScreen> {
  final _learningService = LearningAssignmentService.instance;
  WebViewController? _controller;
  VideoPlayerController? _videoController;
  bool _loading = true;
  bool _loadFailed = false;
  String? _errorMessage;
  String? _assignmentId;
  String? _employeeUserId;
  String? _videoUrl;
  String _title = 'Tutorial';
  bool _started = false;
  LearningVideoPlayerType _playerType = LearningVideoPlayerType.webPage;
  Timer? _progressTimer;
  int _lastReportedProgress = 0;
  bool _watchInitialized = false;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_watchInitialized) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    _watchInitialized = true;
    _assignmentId = args['assignmentId']?.toString();
    _employeeUserId = args['employeeUserId']?.toString();
    _videoUrl = args['videoUrl']?.toString();
    _title = args['title']?.toString() ?? 'Tutorial';
    final tutorialId = args['tutorialId']?.toString();

    _initWatch(tutorialId);
  }

  Future<void> _initWatch(String? tutorialId) async {
    final assignmentId = _assignmentId;
    final employeeId = _employeeUserId;

    try {
      if ((_videoUrl == null || _videoUrl!.isEmpty) &&
          tutorialId != null &&
          tutorialId.isNotEmpty) {
        final tutorial = await _learningService.getTutorial(tutorialId);
        _videoUrl = tutorial.videoUrl;
        _title = tutorial.title;
      }

      final normalized = LearningVideoUrl.normalize(_videoUrl ?? '');
      if (normalized == null || normalized.isEmpty) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _errorMessage = 'No video URL is available for this tutorial.';
        });
        return;
      }

      _videoUrl = normalized;
      _playerType = LearningVideoUrl.playerTypeFor(normalized);

      if (assignmentId != null &&
          employeeId != null &&
          employeeId.isNotEmpty &&
          !_started) {
        _started = true;
        await _learningService.startAssignment(
          assignmentId: assignmentId,
          employeeUserId: employeeId,
        );
      }

      switch (_playerType) {
        case LearningVideoPlayerType.directVideo:
          await _initDirectVideoPlayer(normalized);
          break;
        case LearningVideoPlayerType.embeddedWeb:
        case LearningVideoPlayerType.webPage:
          await _initWebPlayer(
            LearningVideoUrl.embedUrlFor(normalized) ?? normalized,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _errorMessage = 'Failed to load tutorial: $e';
        });
      }
    }
  }

  Future<void> _initDirectVideoPlayer(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    controller.setLooping(false);
    controller.addListener(_onVideoProgress);
    await controller.play();

    if (mounted) {
      setState(() {
        _videoController = controller;
        _loading = false;
        _loadFailed = false;
      });
      _scheduleProgressUpdates();
    }
  }

  Future<void> _initWebPlayer(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      setState(() {
        _loading = false;
        _loadFailed = true;
        _errorMessage = 'The tutorial URL is not valid.';
      });
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(LearningVideoUrl.desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _loadFailed = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
              _reportWatchProgress(25);
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _loadFailed = true;
                _errorMessage =
                    'Could not load the tutorial in the app viewer. '
                    'Some providers block embedded playback — try signing in '
                    'within this panel if prompted.';
              });
            }
          },
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            if (target == null) {
              return NavigationDecision.prevent;
            }
            if (LearningVideoUrl.shouldKeepNavigationInApp(target)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(uri);

    if (mounted) {
      setState(() {
        _controller = controller;
        _loading = false;
      });
      _scheduleProgressUpdates();
    }
  }

  void _onVideoProgress() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return;
    final position = controller.value.position;
    final pct = ((position.inMilliseconds / duration.inMilliseconds) * 100)
        .round()
        .clamp(0, 99);
    _reportWatchProgress(pct);
  }

  void _scheduleProgressUpdates() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_playerType != LearningVideoPlayerType.directVideo) {
        _reportWatchProgress(
          (_lastReportedProgress + 10).clamp(0, 90),
        );
      }
    });
  }

  Future<void> _reportWatchProgress(int progress) async {
    final assignmentId = _assignmentId;
    final employeeId = _employeeUserId;
    if (assignmentId == null || employeeId == null) return;
    if (progress <= _lastReportedProgress) return;

    _lastReportedProgress = progress;
    try {
      await _learningService.updateWatchProgress(
        assignmentId: assignmentId,
        employeeUserId: employeeId,
        watchProgress: progress,
      );
    } catch (_) {}
  }

  Future<void> _markComplete() async {
    final assignmentId = _assignmentId;
    final employeeId = _employeeUserId;
    if (assignmentId == null || employeeId == null) return;

    try {
      await _learningService.completeAssignment(
        assignmentId: assignmentId,
        employeeUserId: employeeId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tutorial marked complete.',
              style: TextStyle(color: DashboardChrome.fg),
            ),
            backgroundColor: DashboardChrome.cardFill,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update progress: $e'),
            backgroundColor: DashboardChrome.cardFill,
          ),
        );
      }
    }
  }

  Color _barFill() => DashboardChrome.cardFill;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: employeeDashboardLightModeNotifier,
      builder: (context, light, _) {
        return EmployeeDashboardThemeScope(
          light: light,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: _barFill(),
              foregroundColor: DashboardChrome.fg,
              elevation: 0,
              title: Text(
                _title,
                style: AppTypography.heading4.copyWith(
                  color: DashboardChrome.fg,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                TextButton(
                  onPressed: _markComplete,
                  child: Text(
                    'Mark complete',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.activeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: DashboardThemedBackground(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _buildBody(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loadFailed) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: DashboardChrome.cardFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DashboardChrome.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: AppColors.activeColor, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Unable to load tutorial.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: DashboardChrome.fg,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DashboardChrome.fg,
                    side: BorderSide(color: DashboardChrome.border),
                  ),
                  child: const Text('Back to My Learning'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading &&
        _controller == null &&
        _videoController == null) {
      return const Center(child: CustomLogoLoader());
    }

    if (_playerType == LearningVideoPlayerType.directVideo &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      return _buildDirectVideoPlayer();
    }

    if (_controller != null) {
      return _buildWebPlayer();
    }

    return const Center(child: CustomLogoLoader());
  }

  Widget _buildDirectVideoPlayer() {
    final controller = _videoController!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: DashboardChrome.border),
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
        ),
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(controller),
              _VideoControls(controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebPlayer() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: DashboardChrome.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: double.infinity,
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: WebViewWidget(controller: _controller!),
            ),
          ),
        ),
        if (_loading)
          const Positioned.fill(
            child: Center(child: CustomLogoLoader()),
          ),
      ],
    );
  }
}

class _VideoControls extends StatefulWidget {
  const _VideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            },
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.activeColor,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
