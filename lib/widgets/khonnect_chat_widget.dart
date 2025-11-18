import 'package:flutter/material.dart';
import 'package:pdh/team_chats.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';

/// Helper function to show the Khonnect chat modal from anywhere in the app
/// This ensures consistent behavior whenever team chat is accessed
void showKhonnectChatModal(BuildContext context) {
  // Ensure we're using the root navigator and have Material context
  final navigator = Navigator.of(context, rootNavigator: true);
  
  showDialog(
    context: navigator.context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) {
      return Material(
        color: Colors.transparent,
        child: Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
            final maxHeight = (MediaQuery.of(ctx).size.height * 0.8).clamp(
              360.0,
              800.0,
            );
            final maxWidth = (MediaQuery.of(ctx).size.width * 0.9).clamp(
              400.0,
              600.0,
            );
            return SizedBox(
              width: maxWidth,
              height: maxHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header matching Rare Goals modal style
                  Padding(
                    padding: const EdgeInsets.all(20),
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
                              const SizedBox(height: 2),
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
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
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
      child: const Icon(
        Icons.chat_bubble_outline,
        color: Colors.white,
      ),
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
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.2),
          ),
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
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedEmbeddedWidget() {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 600,
        maxWidth: 500,
      ),
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
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.2),
          ),
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

