import 'package:flutter/material.dart';
import 'package:pdh/widgets/khonnect_chat_widget.dart';

/// Example usage of the KhonnectChatWidget
/// 
/// This widget can be used in two modes:
/// 1. Floating button mode (default) - Shows as a floating action button that opens a modal
/// 2. Embedded widget mode - Shows as an embedded widget that can expand/collapse inline
/// 
/// Example 1: Floating button mode (default)
/// ```dart
/// Stack(
///   children: [
///     // Your main content
///     YourMainContent(),
///     // Floating chat button
///     KhonnectChatWidget(
///       isFloating: true, // Default
///     ),
///   ],
/// )
/// ```
/// 
/// Example 2: Embedded widget mode
/// ```dart
/// Column(
///   children: [
///     // Your other content
///     YourOtherContent(),
///     // Embedded chat widget
///     KhonnectChatWidget(
///       isFloating: false,
///       initiallyExpanded: false, // Start minimized
///     ),
///   ],
/// )
/// ```
/// 
/// Example 3: Embedded widget starting expanded
/// ```dart
/// KhonnectChatWidget(
///   isFloating: false,
///   initiallyExpanded: true, // Start expanded
/// )
/// ```

class KhonnectChatWidgetExample extends StatelessWidget {
  const KhonnectChatWidgetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Your main app content
          const Center(
            child: Text(
              'Your App Content Here',
              style: TextStyle(color: Colors.white),
            ),
          ),
          // Floating chat widget (default mode)
          const KhonnectChatWidget(
            isFloating: true,
          ),
        ],
      ),
    );
  }
}

