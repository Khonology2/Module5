import 'package:flutter/material.dart';
import 'package:pdh/progress_visuals_screen.dart';

/// Admin-only Progress Visuals screen. Uses the same UI as the Progress Visuals screen.
/// Not shared with manager/employee. Clicking "Progress Visuals" in the admin sidebar goes here.
class AdminProgressVisualsScreen extends StatelessWidget {
  const AdminProgressVisualsScreen({
    super.key,
    this.embedded = false,
    this.selectedManagerId,
  });

  final bool embedded;
  final String? selectedManagerId;

  @override
  Widget build(BuildContext context) {
    return ProgressVisualsScreen(
      embedded: true,
      forAdminOversight: true,
      selectedManagerId: selectedManagerId,
    );
  }
}
