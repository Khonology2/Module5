import 'package:flutter/material.dart';

class SidebarState {
  SidebarState._internal();
  static final SidebarState instance = SidebarState._internal();

  // Controls whether the sidebar is collapsed (icons only) or expanded (icons + text)
  final ValueNotifier<bool> isCollapsed = ValueNotifier<bool>(false);

  // Initialize based on screen width
  void initForWidth(double width) {
    if (width < 600) {
      // Small screens use hamburger drawer; collapse state irrelevant
      isCollapsed.value = true;
    } else if (width < 1000) {
      // Medium screens default to collapsed
      isCollapsed.value = true;
    } else {
      // Large screens default to expanded
      isCollapsed.value = false;
    }
  }
}


