import 'package:flutter/material.dart';
import 'package:pdh/team_chats.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';

/// Helper function to show the Khonnect chat modal from anywhere in the app
/// This ensures consistent behavior whenever team chat is accessed
void showKhonnectChatModal(BuildContext context) {
  // Open the chat modal using the provided context and the root navigator
  showDialog(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) {
      return Material(
        color: Colors.transparent,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenSize = MediaQuery.of(ctx).size;
              final maxHeight = (screenSize.height * 0.9).clamp(
                360.0,
                screenSize.height,
              );
              final maxWidth = (screenSize.width * 0.9).clamp(
                420.0,
                screenSize.width,
              );

              return Container(
                width: maxWidth,
                height: maxHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chat with your team',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share updates, ask questions, and keep everyone aligned.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Chat container
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
                          child: const TeamChatsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
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
              );
            },
          ),
        ),
      );
    },
  );
}

/// An expandable chat widget that can be used as a floating button or embedded widget
/// Matches the styling of the "Rare Goals" modal popup
class KhonnectChatWidget extends StatefulWidget {
  /// Whether the widget should start in expanded state
  final bool initiallyExpanded;

  /// Whether to show as a floating button (true) or embedded widget (false)
  final bool isFloating;

  /// Position of the floating button
  final Alignment floatingPosition;

  const KhonnectChatWidget({
    super.key,
    this.initiallyExpanded = false,
    this.isFloating = true,
    this.floatingPosition = Alignment.bottomRight,
  });

  @override
  State<KhonnectChatWidget> createState() => _KhonnectChatWidgetState();
}

class _KhonnectChatWidgetState extends State<KhonnectChatWidget> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _showChatModal() {
    showKhonnectChatModal(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFloating) {
      // Floating button mode
      return Positioned(
        bottom: 20,
        right: 20,
        child: _isExpanded
            ? _buildExpandedFloatingWidget()
            : _buildFloatingButton(),
      );
    } else {
      // Embedded widget mode
      return _isExpanded
          ? _buildExpandedEmbeddedWidget()
          : _buildMinimizedEmbeddedWidget();
    }
  }

  Widget _buildFloatingButton() {
    return FloatingActionButton(
      onPressed: _showChatModal,
      backgroundColor: AppColors.activeColor,
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
    );
  }

  Widget _buildExpandedFloatingWidget() {
    return Container(
      width: 400,
      height: 600,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.activeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khonnect',
                        style: AppTypography.heading4.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Team Chat',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _toggleExpanded,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          // Chat content
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Container(
                color: Colors.transparent,
                child: TeamChatsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimizedEmbeddedWidget() {
    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.activeColor,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Khonnect',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Tap to open chat',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedEmbeddedWidget() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.activeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khonnect',
                        style: AppTypography.heading4.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Team Chat',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _toggleExpanded,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          // Chat content
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Container(
                color: Colors.transparent,
                child: TeamChatsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
