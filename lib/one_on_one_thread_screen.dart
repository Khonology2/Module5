import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/one_on_one_meeting.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/one_on_one_meeting_service.dart';

class OneOnOneThreadModal extends StatelessWidget {
  const OneOnOneThreadModal({
    super.key,
    this.initialMeetingId,
    this.employeeId,
    this.managerId,
    this.participantName,
  });

  final String? initialMeetingId;
  final String? employeeId;
  final String? managerId;
  final String? participantName;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxHeight = (screenSize.height * 0.9).clamp(360.0, screenSize.height);
    final maxWidth = (screenSize.width * 0.9).clamp(420.0, screenSize.width);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: maxWidth,
          height: maxHeight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '1:1 Thread',
                textAlign: TextAlign.center,
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Review the agenda, timeline, and next step in one place.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    child: OneOnOneThreadScreen(
                      initialMeetingId: initialMeetingId,
                      employeeId: employeeId,
                      managerId: managerId,
                      participantName: participantName,
                      embedded: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OneOnOneThreadScreen extends StatefulWidget {
  const OneOnOneThreadScreen({
    super.key,
    this.initialMeetingId,
    this.employeeId,
    this.managerId,
    this.participantName,
    this.embedded = false,
  });

  final String? initialMeetingId;
  final String? employeeId;
  final String? managerId;
  final String? participantName;
  final bool embedded;

  @override
  State<OneOnOneThreadScreen> createState() => _OneOnOneThreadScreenState();
}

class _OneOnOneThreadScreenState extends State<OneOnOneThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  static const Color _threadPageBackground = Color(0xFF09111F);
  static final Color _threadSurfaceColor = Colors.white.withValues(alpha: 0.14);
  static final List<BoxShadow> _threadSurfaceShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      offset: const Offset(0, 3.55),
      blurRadius: 3.55,
      spreadRadius: 0,
    ),
  ];

  bool _isInitializing = true;
  bool _isSubmitting = false;
  String? _loadError;
  String? _meetingId;
  String? _employeeId;
  String? _managerId;
  _PickedMeetingWindow? _draftMeetingWindow;
  _PendingTimeAction? _pendingTimeAction;
  String? _pendingMeetingId;

  @override
  void initState() {
    super.initState();
    _initializeThread();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeThread() async {
    try {
      final role = await _loadCurrentRole();
      var meetingId = _trimmed(widget.initialMeetingId);
      var employeeId = _trimmed(widget.employeeId);
      var managerId = _trimmed(widget.managerId);

      if (meetingId != null) {
        final meeting = await OneOnOneMeetingService.getMeeting(meetingId);
        if (meeting != null) {
          employeeId ??= _trimmed(meeting.employeeId);
          managerId ??= _trimmed(meeting.managerId);
        }
      }

      if ((meetingId == null || meetingId.isEmpty) &&
          employeeId != null &&
          employeeId.isNotEmpty) {
        if ((role == 'manager' || role == 'admin') &&
            (managerId == null || managerId.isEmpty) &&
            _currentUserId != null &&
            _currentUserId.isNotEmpty) {
          managerId = _currentUserId;
        }
        if (managerId != null && managerId.isNotEmpty) {
          final latest = await OneOnOneMeetingService.getLatestBetween(
            managerId: managerId,
            employeeId: employeeId,
          );
          if (latest != null) {
            employeeId = latest.employeeId;
            managerId = latest.managerId;
            if (!_canStartFollowUpThread(latest)) {
              meetingId = latest.meetingId;
            }
          }
        }
      }

      if (role == 'employee' &&
          (employeeId == null || employeeId.isEmpty) &&
          _currentUserId != null &&
          _currentUserId.isNotEmpty) {
        employeeId = _currentUserId;
      }

      if ((role == 'manager' || role == 'admin') &&
          (managerId == null || managerId.isEmpty) &&
          _currentUserId != null &&
          _currentUserId.isNotEmpty) {
        managerId = _currentUserId;
      }

      if (!mounted) return;
      setState(() {
        _meetingId = meetingId;
        _employeeId = employeeId;
        _managerId = managerId;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load this 1:1 thread: $e';
        _isInitializing = false;
      });
    }
  }

  Future<String> _loadCurrentRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'employee';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = (snap.data()?['role'] ?? 'employee').toString().trim();
      return role.isEmpty ? 'employee' : role.toLowerCase();
    } catch (_) {
      return 'employee';
    }
  }

  String? _trimmed(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  bool _hasMeetingEnded(OneOnOneMeeting meeting) {
    if (meeting.status != OneOnOneMeetingStatus.accepted) return false;
    final start = meeting.proposedStartDateTime;
    if (start == null) return false;
    final end = meeting.proposedEndDateTime ?? start.add(const Duration(hours: 1));
    return end.isBefore(DateTime.now());
  }

  bool _canStartFollowUpThread(OneOnOneMeeting meeting) {
    return meeting.status == OneOnOneMeetingStatus.cancelled || _hasMeetingEnded(meeting);
  }

  bool _hasPendingTimeAction(_PendingTimeAction action, OneOnOneMeeting? meeting) {
    return _pendingTimeAction == action &&
        _draftMeetingWindow != null &&
        _pendingMeetingId == meeting?.meetingId;
  }

  void _setPendingTimeAction({
    required _PendingTimeAction action,
    required _PickedMeetingWindow picked,
    required OneOnOneMeeting? meeting,
  }) {
    setState(() {
      _pendingTimeAction = action;
      _draftMeetingWindow = picked;
      _pendingMeetingId = meeting?.meetingId;
    });
  }

  void _clearPendingTimeAction() {
    _pendingTimeAction = null;
    _draftMeetingWindow = null;
    _pendingMeetingId = null;
  }

  Future<_UserSummary> _loadUserSummary(String? uid, {String fallback = 'Team member'}) async {
    final id = _trimmed(uid);
    if (id == null) {
      return _UserSummary(name: widget.participantName ?? fallback, role: null);
    }

    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(id).get();
      final data = snap.data();
      final name = (data?['displayName'] ?? data?['name'] ?? data?['email'] ?? fallback)
          .toString()
          .trim();
      final role = data?['role']?.toString().trim().toLowerCase();
      return _UserSummary(
        name: name.isEmpty ? fallback : name,
        role: role?.isEmpty == true ? null : role,
      );
    } catch (_) {
      return _UserSummary(name: widget.participantName ?? fallback, role: null);
    }
  }

  Future<_ThreadHeaderData> _loadHeaderData({
    required String? employeeId,
    required String? managerId,
    required bool isManagerActor,
    required bool isEmployeeActor,
  }) async {
    if (isEmployeeActor) {
      final manager = await _loadUserSummary(managerId, fallback: 'Manager');
      return _ThreadHeaderData(
        title: manager.name,
        subtitle: '1:1 with your manager',
        roleLabel: manager.role == 'admin' ? 'Admin' : 'Manager',
      );
    }

    if (isManagerActor) {
      final employee = await _loadUserSummary(
        employeeId,
        fallback: widget.participantName ?? 'Employee',
      );
      return _ThreadHeaderData(
        title: employee.name,
        subtitle: '1:1 thread',
        roleLabel: employee.role == 'manager' ? 'Manager' : 'Employee',
      );
    }

    final employee = await _loadUserSummary(
      employeeId,
      fallback: widget.participantName ?? 'Employee',
    );
    final manager = await _loadUserSummary(managerId, fallback: 'Manager');
    return _ThreadHeaderData(
      title: '${manager.name} and ${employee.name}',
      subtitle: 'Viewing 1:1 conversation',
      roleLabel: 'Read-only',
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (widget.embedded) {
      return SafeArea(child: content);
    }

    return _buildScaffold(child: content);
  }

  Widget _buildContent() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.activeColor),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _loadError!,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_meetingId == null) {
      return _buildThreadBody(meeting: null);
    }

    return StreamBuilder<OneOnOneMeeting?>(
      stream: OneOnOneMeetingService.streamMeeting(_meetingId!),
      builder: (context, snapshot) {
        final meeting = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting && meeting == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.activeColor),
          );
        }
        if (!snapshot.hasData || meeting == null) {
          return _buildMissingMeetingState();
        }

        final needsStateRefresh =
            _employeeId != meeting.employeeId || _managerId != meeting.managerId;
        if (needsStateRefresh) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _employeeId = meeting.employeeId;
              _managerId = meeting.managerId;
            });
          });
        }

        return _buildThreadBody(meeting: meeting);
      },
    );
  }

  Widget _buildScaffold({required Widget child}) {
    return Scaffold(
      backgroundColor: _threadPageBackground,
      appBar: AppBar(
        backgroundColor: _threadSurfaceColor,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('1:1 Thread'),
      ),
      body: SafeArea(child: child),
    );
  }

  Widget _buildMissingMeetingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(
              'This 1:1 thread could not be found.',
              style: AppTypography.heading4.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'It may have been removed or the link is missing the latest meeting context.',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreadBody({required OneOnOneMeeting? meeting}) {
    final effectiveEmployeeId = meeting?.employeeId ?? _employeeId;
    final effectiveManagerId = meeting?.managerId ?? _managerId;
    final currentUserId = _currentUserId;
    final isManagerActor = currentUserId != null &&
        currentUserId.isNotEmpty &&
        effectiveManagerId == currentUserId;
    final isEmployeeActor = currentUserId != null &&
        currentUserId.isNotEmpty &&
        effectiveEmployeeId == currentUserId;
    final allowFollowUpRequest =
        meeting != null && isManagerActor && _canStartFollowUpThread(meeting);

    final showComposer = meeting == null ||
        meeting.status != OneOnOneMeetingStatus.accepted &&
            meeting.status != OneOnOneMeetingStatus.cancelled ||
        allowFollowUpRequest;

    return FutureBuilder<_ThreadHeaderData>(
      future: _loadHeaderData(
        employeeId: effectiveEmployeeId,
        managerId: effectiveManagerId,
        isManagerActor: isManagerActor,
        isEmployeeActor: isEmployeeActor,
      ),
      builder: (context, snapshot) {
        final header =
            snapshot.data ??
            _ThreadHeaderData(
              title: widget.participantName ?? '1:1 conversation',
              subtitle: 'Loading participant details',
              roleLabel: 'Thread',
            );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(header, meeting),
            const SizedBox(height: 12),
            _buildNextStepCard(
              meeting: meeting,
              isManagerActor: isManagerActor,
              isEmployeeActor: isEmployeeActor,
            ),
            const SizedBox(height: 12),
            _buildTimelineCard(meeting: meeting),
            const SizedBox(height: 12),
            _buildContextCard(meeting),
            if (showComposer) ...[
              const SizedBox(height: 12),
              _buildActionComposer(
                meeting: meeting,
                isManagerActor: isManagerActor,
                isEmployeeActor: isEmployeeActor,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeaderCard(_ThreadHeaderData header, OneOnOneMeeting? meeting) {
    return AppComponents.card(
      backgroundColor: _threadSurfaceColor,
      borderColor: Colors.white.withValues(alpha: 0.08),
      boxShadow: _threadSurfaceShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.activeColor.withValues(alpha: 0.16),
                child: Text(
                  header.title.isNotEmpty ? header.title[0].toUpperCase() : '1',
                  style: AppTypography.heading4.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      header.title,
                      style: AppTypography.heading4.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      header.subtitle,
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              _buildBadge(
                label: meeting == null ? 'New thread' : _humanStatus(meeting),
                color: AppColors.activeColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaChip(Icons.person_outline, header.roleLabel),
              if (meeting != null && meeting.proposedStartDateTime != null)
                _buildMetaChip(
                  Icons.schedule_outlined,
                  meeting.status == OneOnOneMeetingStatus.accepted
                      ? 'Time confirmed'
                      : 'Time proposed',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepCard({
    required OneOnOneMeeting? meeting,
    required bool isManagerActor,
    required bool isEmployeeActor,
  }) {
    return AppComponents.card(
      backgroundColor: _threadSurfaceColor,
      borderColor: Colors.white.withValues(alpha: 0.08),
      boxShadow: _threadSurfaceShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next step',
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _nextStepCopy(
              meeting: meeting,
              isManagerActor: isManagerActor,
              isEmployeeActor: isEmployeeActor,
            ),
            style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard({required OneOnOneMeeting? meeting}) {
    final items = _timelineItems(meeting);
    return AppComponents.card(
      backgroundColor: _threadSurfaceColor,
      borderColor: Colors.white.withValues(alpha: 0.08),
      boxShadow: _threadSurfaceShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Start the conversation by sending a request or proposing a time.',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
            )
          else
            ...items.map(_buildTimelineItem),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: item.highlight ? AppColors.activeColor : Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.timeLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.timeLabel!,
                    style: AppTypography.bodySmall.copyWith(color: Colors.white54),
                  ),
                ],
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextCard(OneOnOneMeeting? meeting) {
    return AppComponents.card(
      backgroundColor: _threadSurfaceColor,
      borderColor: Colors.white.withValues(alpha: 0.08),
      boxShadow: _threadSurfaceShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Context',
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildContextRow(
            label: 'Agenda',
            value: meeting == null
                ? 'Not added yet.'
                : ((meeting.agenda ?? '').trim().isEmpty
                    ? 'No agenda added yet.'
                    : meeting.agenda!.trim()),
          ),
          const SizedBox(height: 10),
          _buildContextRow(
            label: 'Employee reply',
            value: meeting == null
                ? 'No reply yet.'
                : ((meeting.employeeMessage ?? '').trim().isEmpty
                    ? 'No reply yet.'
                    : meeting.employeeMessage!.trim()),
          ),
          const SizedBox(height: 10),
          _buildContextRow(
            label: 'Meeting window',
            value: meeting == null
                ? 'No time proposed yet.'
                : _meetingWindowLabel(meeting),
          ),
        ],
      ),
    );
  }

  Widget _buildContextRow({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildActionComposer({
    required OneOnOneMeeting? meeting,
    required bool isManagerActor,
    required bool isEmployeeActor,
  }) {
    final managerDraftPending = _hasPendingTimeAction(
      _PendingTimeAction.managerPropose,
      meeting,
    );
    final employeeDraftPending = _hasPendingTimeAction(
      _PendingTimeAction.employeeSuggest,
      meeting,
    );
    final activeDraftPending = managerDraftPending || employeeDraftPending;

    final primary = _primaryAction(
      meeting: meeting,
      isManagerActor: isManagerActor,
      isEmployeeActor: isEmployeeActor,
    );
    final secondary = _secondaryAction(
      meeting: meeting,
      isManagerActor: isManagerActor,
      isEmployeeActor: isEmployeeActor,
    );

    return AppComponents.card(
      backgroundColor: _threadSurfaceColor,
      borderColor: Colors.white.withValues(alpha: 0.08),
      boxShadow: _threadSurfaceShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reply',
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          if (primary == null && secondary == null)
            Text(
              'No response is required from you right now.',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
            )
          else ...[
            TextField(
              controller: _messageController,
              enabled: !_isSubmitting,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: isEmployeeActor
                    ? 'Add a reply or context (optional)'
                    : 'Add an agenda or message (optional)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            if (activeDraftPending) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      managerDraftPending
                          ? 'Selected meeting window'
                          : 'Selected suggested time',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white60,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatMeetingRange(
                        _draftMeetingWindow!.start,
                        _draftMeetingWindow!.end,
                      ),
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  if (managerDraftPending) {
                                    _proposeTimeAsManager(meeting);
                                  } else {
                                    _suggestTimeAsEmployee(meeting!);
                                  }
                                },
                          child: const Text('Change time'),
                        ),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(_clearPendingTimeAction);
                                },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_isSubmitting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(color: AppColors.activeColor),
                ),
              ),
            if (primary != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : primary.onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(primary.label),
                ),
              ),
            if (secondary != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : secondary.onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(secondary.label),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  _ThreadAction? _primaryAction({
    required OneOnOneMeeting? meeting,
    required bool isManagerActor,
    required bool isEmployeeActor,
  }) {
    if (meeting == null) {
      if (isManagerActor && _employeeId != null && _employeeId!.isNotEmpty) {
        return _ThreadAction(label: 'Request a 1:1', onPressed: _requestOneOnOne);
      }
      return null;
    }

    if (isManagerActor && _canStartFollowUpThread(meeting)) {
      return _ThreadAction(
        label: 'Request another 1:1',
        onPressed: _requestOneOnOne,
      );
    }

    if (isEmployeeActor &&
        meeting.waitingOn == OneOnOneWaitingOn.employee &&
        meeting.status == OneOnOneMeetingStatus.requested) {
      if (meeting.proposedStartDateTime == null) {
        final pending = _hasPendingTimeAction(
          _PendingTimeAction.employeeSuggest,
          meeting,
        );
        return _ThreadAction(
          label: pending ? 'Send proposed time' : 'Propose a time',
          onPressed: () => pending
              ? _submitSuggestedTimeAsEmployee(meeting)
              : _suggestTimeAsEmployee(meeting),
        );
      }
      return _ThreadAction(
        label: 'Accept proposed time',
        onPressed: () => _acceptMeeting(meeting, notifyManager: true),
      );
    }

    if (isEmployeeActor &&
        meeting.waitingOn == OneOnOneWaitingOn.employee &&
        (meeting.status == OneOnOneMeetingStatus.proposed ||
            meeting.status == OneOnOneMeetingStatus.rescheduled)) {
      return _ThreadAction(
        label: 'Accept proposed time',
        onPressed: () => _acceptMeeting(meeting, notifyManager: true),
      );
    }

    if (isManagerActor &&
        meeting.waitingOn == OneOnOneWaitingOn.manager &&
        meeting.proposedStartDateTime != null) {
      return _ThreadAction(
        label: 'Accept proposed time',
        onPressed: () => _acceptMeeting(meeting, notifyManager: false),
      );
    }

    if (isManagerActor &&
        meeting.waitingOn == OneOnOneWaitingOn.manager &&
        meeting.status == OneOnOneMeetingStatus.requested) {
      final pending = _hasPendingTimeAction(
        _PendingTimeAction.managerPropose,
        meeting,
      );
      return _ThreadAction(
        label: pending ? 'Send proposed time' : 'Propose a time',
        onPressed: () => pending
            ? _submitProposedTimeAsManager(meeting)
            : _proposeTimeAsManager(meeting),
      );
    }

    return null;
  }

  _ThreadAction? _secondaryAction({
    required OneOnOneMeeting? meeting,
    required bool isManagerActor,
    required bool isEmployeeActor,
  }) {
    if (meeting == null) {
      if (isManagerActor && _employeeId != null && _employeeId!.isNotEmpty) {
        final pending = _hasPendingTimeAction(
          _PendingTimeAction.managerPropose,
          null,
        );
        return _ThreadAction(
          label: pending ? 'Send proposed time' : 'Propose a time',
          onPressed: () => pending
              ? _submitProposedTimeAsManager(null)
              : _proposeTimeAsManager(null),
        );
      }
      return null;
    }

    if (isManagerActor && _canStartFollowUpThread(meeting)) {
      final pending = _hasPendingTimeAction(
        _PendingTimeAction.managerPropose,
        meeting,
      );
      return _ThreadAction(
        label: pending ? 'Send proposed time' : 'Propose a new time',
        onPressed: () => pending
            ? _submitProposedTimeAsManager(meeting)
            : _proposeTimeAsManager(meeting),
      );
    }

    if (isEmployeeActor &&
        meeting.waitingOn == OneOnOneWaitingOn.employee &&
        meeting.status == OneOnOneMeetingStatus.requested) {
      return _ThreadAction(
        label: 'Acknowledge for now',
        onPressed: () => _acknowledgeRequest(meeting),
      );
    }

    if (isEmployeeActor &&
        meeting.waitingOn == OneOnOneWaitingOn.employee &&
        (meeting.status == OneOnOneMeetingStatus.proposed ||
            meeting.status == OneOnOneMeetingStatus.rescheduled)) {
      final pending = _hasPendingTimeAction(
        _PendingTimeAction.employeeSuggest,
        meeting,
      );
      return _ThreadAction(
        label: pending ? 'Send suggested time' : 'Suggest a different time',
        onPressed: () => pending
            ? _submitSuggestedTimeAsEmployee(meeting)
            : _suggestTimeAsEmployee(meeting),
      );
    }

    if (isManagerActor &&
        meeting.proposedStartDateTime != null &&
        meeting.status != OneOnOneMeetingStatus.accepted &&
        meeting.status != OneOnOneMeetingStatus.cancelled) {
      final pending = _hasPendingTimeAction(
        _PendingTimeAction.managerPropose,
        meeting,
      );
      return _ThreadAction(
        label: pending ? 'Send proposed time' : 'Propose a different time',
        onPressed: () => pending
            ? _submitProposedTimeAsManager(meeting)
            : _proposeTimeAsManager(meeting),
      );
    }

    return null;
  }

  Future<void> _requestOneOnOne() async {
    final employeeId = _employeeId;
    if (employeeId == null || employeeId.isEmpty) return;

    await _runAction(() async {
      final meetingId = await ManagerRealtimeService.requestOneOnOne(
        employeeId: employeeId,
        agenda: _messageController.text.trim(),
        recipientActionRoute: '/one_on_one_thread',
      );
      if (!mounted) return;
      setState(() {
        _meetingId = meetingId;
        _messageController.clear();
        _clearPendingTimeAction();
      });
      _showSnackBar('1:1 request sent.');
    });
  }

  Future<void> _proposeTimeAsManager(OneOnOneMeeting? existingMeeting) async {
    final employeeId = existingMeeting?.employeeId ?? _employeeId;
    if (employeeId == null || employeeId.isEmpty) return;

    final picked = await _pickMeetingWindow(
      initialStart:
          _hasPendingTimeAction(_PendingTimeAction.managerPropose, existingMeeting)
          ? _draftMeetingWindow?.start
          : existingMeeting?.proposedStartDateTime,
      initialEnd:
          _hasPendingTimeAction(_PendingTimeAction.managerPropose, existingMeeting)
          ? _draftMeetingWindow?.end
          : existingMeeting?.proposedEndDateTime,
    );
    if (picked == null) return;

    _setPendingTimeAction(
      action: _PendingTimeAction.managerPropose,
      picked: picked,
      meeting: existingMeeting,
    );
  }

  Future<void> _submitProposedTimeAsManager(OneOnOneMeeting? existingMeeting) async {
    final employeeId = existingMeeting?.employeeId ?? _employeeId;
    final picked = _draftMeetingWindow;
    if (employeeId == null || employeeId.isEmpty || picked == null) return;

    final message = _messageController.text.trim();

    await _runAction(() async {
      if (existingMeeting == null ||
          existingMeeting.status == OneOnOneMeetingStatus.cancelled ||
          existingMeeting.status == OneOnOneMeetingStatus.accepted) {
        final meetingId = await ManagerRealtimeService.scheduleMeeting(
          employeeId: employeeId,
          scheduledStartTime: picked.start,
          scheduledEndTime: picked.end,
          purpose: message.isEmpty ? '1:1' : message,
          recipientActionRoute: '/one_on_one_thread',
        );
        if (!mounted) return;
        setState(() {
          _meetingId = meetingId;
          _messageController.clear();
          _clearPendingTimeAction();
        });
      } else {
        await OneOnOneMeetingService.managerProposeNewTime(
          meetingId: existingMeeting.meetingId,
          proposedStartDateTime: picked.start,
          proposedEndDateTime: picked.end,
          agenda: message.isEmpty ? null : message,
        );
        await AlertService.createOneOnOneProposedAlert(
          employeeId: existingMeeting.employeeId,
          managerId: existingMeeting.managerId,
          meetingId: existingMeeting.meetingId,
          proposedStartDateTime: picked.start,
          proposedEndDateTime: picked.end,
          agenda: message.isEmpty ? null : message,
          actionRouteOverride: '/one_on_one_thread',
        );
        if (!mounted) return;
        setState(() {
          _messageController.clear();
          _clearPendingTimeAction();
        });
      }

      _showSnackBar('Proposed time sent.');
    });
  }

  Future<void> _acknowledgeRequest(OneOnOneMeeting meeting) async {
    final message = _messageController.text.trim();
    await _runAction(() async {
      await OneOnOneMeetingService.employeeAcknowledgeRequest(
        meetingId: meeting.meetingId,
        message: message.isEmpty ? null : message,
      );

      final currentUserName = await _currentUserDisplayName();
      await AlertService.createGeneralAlert(
        userId: meeting.managerId,
        title: '1:1 Acknowledged',
        message:
            '$currentUserName acknowledged your 1:1 request. Propose a time when you’re ready.',
        type: AlertType.oneOnOneRequested,
        priority: AlertPriority.low,
        actionText: 'View',
        actionRoute: '/one_on_one_thread',
        actionData: {
          'meetingId': meeting.meetingId,
          'employeeId': meeting.employeeId,
        },
        fromUserId: meeting.employeeId,
        fromUserName: currentUserName,
      );

      if (!mounted) return;
      setState(() {
        _messageController.clear();
        _clearPendingTimeAction();
      });
      _showSnackBar('Acknowledged.');
    });
  }

  Future<void> _suggestTimeAsEmployee(OneOnOneMeeting meeting) async {
    final picked = await _pickMeetingWindow(
      initialStart: _hasPendingTimeAction(_PendingTimeAction.employeeSuggest, meeting)
          ? _draftMeetingWindow?.start
          : meeting.proposedStartDateTime,
      initialEnd: _hasPendingTimeAction(_PendingTimeAction.employeeSuggest, meeting)
          ? _draftMeetingWindow?.end
          : meeting.proposedEndDateTime,
    );
    if (picked == null) return;

    _setPendingTimeAction(
      action: _PendingTimeAction.employeeSuggest,
      picked: picked,
      meeting: meeting,
    );
  }

  Future<void> _submitSuggestedTimeAsEmployee(OneOnOneMeeting meeting) async {
    final picked = _draftMeetingWindow;
    if (picked == null) return;

    final message = _messageController.text.trim();

    await _runAction(() async {
      await OneOnOneMeetingService.employeeSuggestNewTime(
        meetingId: meeting.meetingId,
        proposedStartDateTime: picked.start,
        proposedEndDateTime: picked.end,
        agenda: message.isEmpty ? null : message,
      );
      await AlertService.createOneOnOneRescheduledAlertToManager(
        managerId: meeting.managerId,
        employeeId: meeting.employeeId,
        meetingId: meeting.meetingId,
        proposedStartDateTime: picked.start,
        proposedEndDateTime: picked.end,
        actionRouteOverride: '/one_on_one_thread',
      );

      if (!mounted) return;
      setState(() {
        _messageController.clear();
        _clearPendingTimeAction();
      });
      _showSnackBar('New time sent.');
    });
  }

  Future<void> _acceptMeeting(
    OneOnOneMeeting meeting, {
    required bool notifyManager,
  }) async {
    await _runAction(() async {
      await OneOnOneMeetingService.acceptMeeting(meetingId: meeting.meetingId);
      await AlertService.createOneOnOneAcceptedAlertToManager(
        managerId: notifyManager ? meeting.managerId : meeting.employeeId,
        employeeId: notifyManager ? meeting.employeeId : meeting.managerId,
        meetingId: meeting.meetingId,
        acceptedStartDateTime: meeting.proposedStartDateTime,
        acceptedEndDateTime: meeting.proposedEndDateTime,
        actionRouteOverride: '/one_on_one_thread',
      );
      if (!mounted) return;
      setState(() {
        _messageController.clear();
        _clearPendingTimeAction();
      });
      _showSnackBar('Meeting time accepted.');
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      await action();
    } catch (e) {
      _showSnackBar('Could not update 1:1: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<_PickedMeetingWindow?> _pickMeetingWindow({
    DateTime? initialStart,
    DateTime? initialEnd,
  }) async {
    final now = DateTime.now();
    final startBase = initialStart != null && initialStart.isAfter(now)
        ? initialStart
        : now.add(const Duration(days: 1));
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: startBase,
    );
    if (pickedDate == null || !mounted) return null;

    final pickedStartTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startBase),
    );
    if (pickedStartTime == null || !mounted) return null;

    final start = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedStartTime.hour,
      pickedStartTime.minute,
    );

    final endBase = initialEnd != null && initialEnd.isAfter(start)
        ? initialEnd
        : start.add(const Duration(minutes: 60));
    final pickedEndTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(endBase),
    );
    if (pickedEndTime == null) return null;

    final end = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedEndTime.hour,
      pickedEndTime.minute,
    );

    if (!end.isAfter(start)) {
      _showSnackBar('End time must be after start time.');
      return null;
    }

    return _PickedMeetingWindow(start: start, end: end);
  }

  List<_TimelineItem> _timelineItems(OneOnOneMeeting? meeting) {
    if (meeting == null) return const [];

    final items = <_TimelineItem>[
      _TimelineItem(
        title: meeting.proposedStartDateTime == null
            ? '1:1 request created'
            : '1:1 thread opened',
        timeLabel: _formatTimestamp(meeting.createdAt),
        description: (meeting.agenda ?? '').trim().isEmpty
            ? 'No agenda was added yet.'
            : meeting.agenda!.trim(),
      ),
    ];

    if ((meeting.employeeMessage ?? '').trim().isNotEmpty) {
      items.add(
        _TimelineItem(
          title: 'Employee reply added',
          timeLabel: _formatTimestamp(meeting.updatedAt),
          description: meeting.employeeMessage!.trim(),
        ),
      );
    }

    if (meeting.proposedStartDateTime != null) {
      items.add(
        _TimelineItem(
          title: meeting.status == OneOnOneMeetingStatus.accepted
              ? 'Meeting time confirmed'
              : 'Latest meeting window proposed',
          timeLabel: _formatMeetingRange(
            meeting.proposedStartDateTime!,
            meeting.proposedEndDateTime,
          ),
          description: meeting.waitingOn == OneOnOneWaitingOn.none
              ? 'No further response is required.'
              : 'Waiting on ${meeting.waitingOn.name}.',
        ),
      );
    }

    items.add(
      _TimelineItem(
        title: 'Current status',
        timeLabel: _formatTimestamp(meeting.updatedAt),
        description: _nextStepCopy(
          meeting: meeting,
          isManagerActor: meeting.managerId == _currentUserId,
          isEmployeeActor: meeting.employeeId == _currentUserId,
        ),
        highlight: true,
      ),
    );

    return items;
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String _humanStatus(OneOnOneMeeting meeting) {
    switch (meeting.status) {
      case OneOnOneMeetingStatus.requested:
        return meeting.waitingOn == OneOnOneWaitingOn.manager
            ? 'Waiting for manager'
            : 'Waiting for employee';
      case OneOnOneMeetingStatus.proposed:
        return meeting.waitingOn == OneOnOneWaitingOn.employee
            ? 'Time proposed'
            : 'Waiting for manager';
      case OneOnOneMeetingStatus.accepted:
        return 'Confirmed';
      case OneOnOneMeetingStatus.rescheduled:
        return meeting.waitingOn == OneOnOneWaitingOn.manager
            ? 'Employee suggested a new time'
            : 'Rescheduled';
      case OneOnOneMeetingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _nextStepCopy({
    required OneOnOneMeeting? meeting,
    required bool isManagerActor,
    required bool isEmployeeActor,
  }) {
    if (meeting == null) {
      if (isManagerActor) {
        return 'Start the conversation by sending a request or proposing a meeting window.';
      }
      return 'This thread has not started yet.';
    }

    if (_hasMeetingEnded(meeting)) {
      return isManagerActor
          ? 'This meeting has ended. Start a new 1:1 when you are ready.'
          : 'This meeting has ended. Your manager can start a new 1:1 when needed.';
    }

    if (meeting.status == OneOnOneMeetingStatus.accepted) {
      return 'The meeting is confirmed. Use the thread to review the agenda and time.';
    }

    if (meeting.status == OneOnOneMeetingStatus.cancelled) {
      return 'This 1:1 was cancelled. Start a new thread if you still want to meet.';
    }

    if (isManagerActor) {
      if (meeting.waitingOn == OneOnOneWaitingOn.manager &&
          meeting.proposedStartDateTime != null) {
        return 'The employee suggested a time. Accept it or send back a different one.';
      }
      if (meeting.waitingOn == OneOnOneWaitingOn.manager) {
        return 'The employee has acknowledged the request. Propose a meeting time when you are ready.';
      }
      return 'You are waiting for the employee to respond.';
    }

    if (isEmployeeActor) {
      if (meeting.waitingOn == OneOnOneWaitingOn.employee &&
          meeting.proposedStartDateTime != null) {
        return 'Your manager proposed a meeting window. Accept it or suggest a different time.';
      }
      if (meeting.waitingOn == OneOnOneWaitingOn.employee) {
        return 'Your manager requested a 1:1. Propose a time or acknowledge it for now.';
      }
      return 'You are waiting for the manager to take the next step.';
    }

    return 'This thread is waiting on ${meeting.waitingOn.name}.';
  }

  String _meetingWindowLabel(OneOnOneMeeting meeting) {
    final start = meeting.proposedStartDateTime;
    if (start == null) return 'No time proposed yet.';
    return _formatMeetingRange(start, meeting.proposedEndDateTime);
  }

  String _formatMeetingRange(DateTime start, DateTime? end) {
    final localizations = MaterialLocalizations.of(context);
    final startDate = localizations.formatMediumDate(start);
    final startTime = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start));
    if (end == null) return '$startDate at $startTime';

    final endDate = localizations.formatMediumDate(end);
    final endTime = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end));
    final sameDay =
        start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) {
      return '$startDate, $startTime to $endTime';
    }
    return '$startDate, $startTime to $endDate, $endTime';
  }

  String _formatTimestamp(DateTime dateTime) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(dateTime);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
    return '$date at $time';
  }

  Future<String> _currentUserDisplayName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'Employee';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final data = snap.data();
      final name =
          (data?['displayName'] ?? data?['name'] ?? currentUser.displayName ?? 'Employee')
              .toString()
              .trim();
      return name.isEmpty ? 'Employee' : name;
    } catch (_) {
      final fallback = currentUser.displayName?.trim();
      return (fallback == null || fallback.isEmpty) ? 'Employee' : fallback;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ThreadAction {
  const _ThreadAction({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;
}

class _PickedMeetingWindow {
  const _PickedMeetingWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

enum _PendingTimeAction { managerPropose, employeeSuggest }

class _TimelineItem {
  const _TimelineItem({
    required this.title,
    this.timeLabel,
    this.description,
    this.highlight = false,
  });

  final String title;
  final String? timeLabel;
  final String? description;
  final bool highlight;
}

class _ThreadHeaderData {
  const _ThreadHeaderData({
    required this.title,
    required this.subtitle,
    required this.roleLabel,
  });

  final String title;
  final String subtitle;
  final String roleLabel;
}

class _UserSummary {
  const _UserSummary({required this.name, required this.role});

  final String name;
  final String? role;
}
