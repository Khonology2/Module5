import 'package:flutter/foundation.dart';

/// Service to create audit entries for existing milestones (one-time backfill)
/// DEPRECATED: Use UnifiedMilestoneAudit.backfillExistingMilestones() instead
class MilestoneAuditBackfill {
  /// Create audit entries for all existing milestones (one-time operation)
  /// DEPRECATED: This service is disabled - use UnifiedMilestoneAudit.backfillExistingMilestones()
  static Future<void> backfillExistingMilestones() async {
    if (kDebugMode) {
      print(
        'Legacy milestone audit backfill is DISABLED - use UnifiedMilestoneAudit.backfillExistingMilestones() instead',
      );
    }

    // DISABLED: Use unified audit system instead
    // This legacy service was causing permission-denied errors
    return;
  }
}
