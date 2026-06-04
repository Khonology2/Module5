// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/learning_assignment_service.dart';
import 'package:pdh/widgets/custom_logo_loader.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';
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
  bool _loading = true;
  bool _loadFailed = false;
  String? _errorMessage;
  String? _assignmentId;
  String? _employeeUserId;
  String? _videoUrl;
  String _title = 'Tutorial';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assignmentId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

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
    if (assignmentId == null || employeeId == null) {
      setState(() {
        _loading = false;
        _loadFailed = true;
        _errorMessage = 'Missing assignment information.';
      });
      return;
    }

    try {
      if ((_videoUrl == null || _videoUrl!.isEmpty) &&
          tutorialId != null &&
          tutorialId.isNotEmpty) {
        final tutorial = await _learningService.getTutorial(tutorialId);
        _videoUrl = tutorial.videoUrl;
        _title = tutorial.title;
      }

      if (_videoUrl == null || _videoUrl!.trim().isEmpty) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _errorMessage = 'No video URL is available for this tutorial.';
        });
        return;
      }

      if (!_started) {
        _started = true;
        await _learningService.startAssignment(
          assignmentId: assignmentId,
          employeeUserId: employeeId,
        );
      }

      final uri = Uri.tryParse(_videoUrl!.trim());
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
              if (mounted) setState(() => _loading = false);
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
          ),
        )
        ..loadRequest(uri);

      if (mounted) {
        setState(() {
          _controller = controller;
          _loading = false;
        });
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

    if (_controller == null || _loading) {
      return const Center(child: CustomLogoLoader());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: DashboardChrome.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: WebViewWidget(controller: _controller!),
      ),
    );
  }
}
