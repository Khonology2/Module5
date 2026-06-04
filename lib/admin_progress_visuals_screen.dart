import 'package:flutter/material.dart';
import 'package:pdh/progress_visuals_screen.dart';

/// Admin-only Progress Visuals. Delegates to [ProgressVisualsScreen];
/// metrics are loaded from PostgreSQL via [BackendAuthService].
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
