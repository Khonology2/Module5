// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Language setting has been updated';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get create => 'Create';

  @override
  String get submit => 'Submit';

  @override
  String get view => 'View';

  @override
  String get details => 'Details';

  @override
  String get settings_go_to => 'Go to Settings';

  @override
  String get sign_out => 'Sign Out';

  @override
  String get delete_account => 'Delete Account';

  @override
  String get export_my_data => 'Export My Data';

  @override
  String get send_password_reset_email => 'Send Password Reset Email';

  @override
  String get language_english => 'English';

  @override
  String get language_spanish => 'Spanish';

  @override
  String get language_french => 'French';

  @override
  String get language_german => 'German';

  @override
  String get time_15_minutes => '15 minutes';

  @override
  String get time_30_minutes => '30 minutes';

  @override
  String get time_60_minutes => '1 hour';

  @override
  String get time_120_minutes => '2 hours';

  @override
  String get status_all => 'All Statuses';

  @override
  String get status_verified => 'Verified';

  @override
  String get status_pending => 'Pending';

  @override
  String get status_rejected => 'Rejected';

  @override
  String get audit_export_csv => 'Export as CSV';

  @override
  String get audit_export_pdf => 'Export as PDF';

  @override
  String get audit_submit_for_audit => 'Submit for Audit';

  @override
  String get audit_no_timeline_events_yet => 'No timeline events yet';

  @override
  String get dashboard_refresh_data => 'Refresh Data';

  @override
  String get dashboard_recent_activity => 'Recent Activity';

  @override
  String get dashboard_quick_actions => 'Quick Actions';

  @override
  String get dashboard_upcoming_goals => 'Upcoming Goals';

  @override
  String get dashboard_add_goal => 'Add Goal';

  @override
  String get dashboard_awaiting_manager_approval =>
      'Awaiting manager approval.';

  @override
  String get employee_create_first_goal => 'Create Your First Goal';

  @override
  String get manager_team_kpis => 'Team KPIs';

  @override
  String get manager_team_health => 'Team Health';

  @override
  String get manager_activity_summary => 'Activity Summary';

  @override
  String get manager_top_performers => 'Top Performers';

  @override
  String get manager_no_performers_yet => 'No performers yet';

  @override
  String get manager_quick_actions => 'Quick Actions';

  @override
  String get manager_complete_season => 'Complete Season';

  @override
  String manager_team_size(Object teamSize) {
    return 'Team size: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Join Team Goal';

  @override
  String get team_goal_join_cancel => 'Cancel';

  @override
  String get team_goal_join_confirm => 'Join Team';

  @override
  String team_details_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get team_goal_not_found => 'Team goal not found.';

  @override
  String get manager_inbox_approve => 'Approve';

  @override
  String get manager_inbox_request_changes => 'Request changes';

  @override
  String get manager_inbox_reject => 'Reject';

  @override
  String get manager_inbox_mark_all_as_read => 'Mark all as read';

  @override
  String get manager_inbox_view_goal => 'View Goal';

  @override
  String get manager_inbox_view_badges => 'View Badges';

  @override
  String get manager_inbox_all_priorities => 'All Priorities';

  @override
  String get manager_review_nudge => 'Nudge';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Kudos';

  @override
  String get manager_review_activity => 'Activity';

  @override
  String get manager_review_send => 'Send';

  @override
  String get manager_review_schedule => 'Schedule';

  @override
  String get manager_review_send_kudos => 'Send Kudos';

  @override
  String get manager_review_close => 'Close';

  @override
  String get manager_review_check_authentication => 'Check Authentication';

  @override
  String get season_management_title => 'Season Management';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Manage $seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Extend Season';

  @override
  String get season_management_view_celebration => 'View Celebration';

  @override
  String get season_challenge_title => 'Season Challenge';

  @override
  String get team_challenges_create_season => 'Create Season';

  @override
  String get team_challenges_view_details => 'View Details';

  @override
  String get team_challenges_manage => 'Manage';

  @override
  String get team_challenges_celebration => 'Celebration';

  @override
  String get team_challenges_paused_only => 'Paused only';

  @override
  String get season_details_not_found => 'Season not found';

  @override
  String get season_details_complete_season => 'Complete Season';

  @override
  String get season_details_extend_season => 'Extend Season';

  @override
  String get season_details_celebrate => 'Celebrate';

  @override
  String get season_details_recompute => 'Recompute';

  @override
  String get season_details_delete_season => 'Delete Season';

  @override
  String get season_details_force_complete_title => 'Force Complete Season?';

  @override
  String get season_details_force_complete_confirm => 'Force Complete';

  @override
  String get season_details_complete_title => 'Complete Season?';

  @override
  String get season_details_complete_confirm => 'Complete';

  @override
  String get season_details_delete_title => 'Delete Season?';

  @override
  String get season_details_delete_confirm => 'Delete';

  @override
  String get season_goal_completion_title => 'Complete Season Goal';

  @override
  String get season_goal_completion_go_back => 'Go Back';

  @override
  String get season_celebration_share => 'Share Celebration';

  @override
  String get season_celebration_create_new => 'Create New Season';

  @override
  String get season_celebration_shared_success => 'Celebration shared!';

  @override
  String get employee_season_join => 'Join Season';

  @override
  String get employee_season_view_details => 'View Details';

  @override
  String get employee_season_complete_goals => 'Complete Goals';

  @override
  String get employee_season_update => 'Update';

  @override
  String get employee_season_view_celebration => 'View Celebration';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'Successfully joined \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Error joining season: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'No season goals found for \"$seasonTitle\" yet.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Failed to open goal details: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'Submitted for manager approval';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Failed to submit for approval: $error';
  }

  @override
  String get goal_delete_title => 'Delete Goal';

  @override
  String get goal_deleted => 'Goal deleted';

  @override
  String goal_delete_error(Object error) {
    return 'Failed to delete goal: $error';
  }

  @override
  String get goal_start_success => 'Goal started! +20 points earned 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Error starting goal: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Please start the goal before completing it.';

  @override
  String get goal_complete_require_100 => 'Set progress to 100% to complete.';

  @override
  String get goal_complete_success => 'Goal completed! +100 points earned 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Error completing goal: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Progress updated to $progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Error updating progress: $error';
  }

  @override
  String get goal_set_to_100 => 'Set to 100%';

  @override
  String get goal_submit_for_approval_title => 'Submit for Approval';

  @override
  String get goal_add_milestone => 'Add Milestone';

  @override
  String get goal_milestone_requires_sign_in =>
      'You must be signed in to manage milestones.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Completed goals can no longer accept new milestones.';

  @override
  String get goal_milestone_title_required => 'Title is required.';

  @override
  String get goal_milestone_due_date_required => 'Select a due date.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Failed to save milestone: $error';
  }

  @override
  String get goal_milestone_deadline_hint => 'Tap to choose deadline';

  @override
  String get goal_milestone_change => 'Change';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'Marked as $status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Failed to update milestone: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Delete Milestone';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Remove this milestone from the goal?';

  @override
  String get goal_milestone_deleted => 'Milestone deleted.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Failed to delete milestone: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Edit details';

  @override
  String get goal_milestone_mark_not_started => 'Mark Not Started';

  @override
  String get goal_milestone_mark_in_progress => 'Mark In Progress';

  @override
  String get goal_milestone_mark_blocked => 'Mark Blocked';

  @override
  String get goal_milestone_mark_completed => 'Mark Completed';

  @override
  String get manager_team_workspace_create_team_goal => 'Create Team Goal';

  @override
  String get manager_team_workspace_view_details => 'View Details';

  @override
  String get manager_team_workspace_manage_team => 'Manage Team';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Create Team Goal';

  @override
  String get database_test_title => 'Database Test';

  @override
  String get database_test_add_goal => 'Add Goal';

  @override
  String get database_test_add_sample_goals => 'Add Sample Goals';

  @override
  String get employee_profile_detail_send_nudge => 'Send Nudge';

  @override
  String get employee_profile_detail_schedule_meeting => 'Schedule Meeting';

  @override
  String get employee_profile_detail_give_recognition => 'Give Recognition';

  @override
  String get employee_profile_detail_assign_goal => 'Assign Goal';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Functionality will be implemented here';

  @override
  String get my_goal_workspace_suggest => 'Suggest';

  @override
  String get my_goal_workspace_generate => 'Generate';

  @override
  String get my_goal_workspace_enter_goal_title => 'Please enter a goal title';

  @override
  String get my_goal_workspace_select_target_date =>
      'Please select a target date';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Error creating goal: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Create Goal';

  @override
  String get team_chats_edit_message => 'Edit message';

  @override
  String get team_chats_delete_message_title => 'Delete message?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'This action cannot be undone.';

  @override
  String get gamification_title => 'Gamification';

  @override
  String get gamification_content => 'Gamification Screen Content';

  @override
  String get my_pdp_ok => 'OK';

  @override
  String get my_pdp_upload_file => 'Upload file (PDF/Word/Image)';

  @override
  String get my_pdp_save_note_link => 'Save note/link';

  @override
  String get my_pdp_change_evidence => 'Change Evidence';

  @override
  String get my_pdp_go_to_settings => 'Go to Settings';

  @override
  String get my_pdp_add_session => '+1 session';

  @override
  String get my_pdp_module_complete => 'Module complete';

  @override
  String get role_access_restricted_title => 'Access restricted';

  @override
  String role_access_restricted_body(Object role) {
    return 'Your role ($role) does not have access to this page.';
  }

  @override
  String get role_go_to_my_portal => 'Go to my portal';

  @override
  String get evidence_sign_in_required =>
      'Please sign in to view your evidence.';

  @override
  String get evidence_sort_by_date => 'Sort by Date';

  @override
  String get evidence_sort_by_title => 'Sort by Title';

  @override
  String get evidence_no_evidence_found => 'No evidence found.';

  @override
  String get evidence_dialog_title => 'Evidence';

  @override
  String get employee_profile_remove_photo => 'Remove Photo';

  @override
  String get employee_profile_login_required_remove_photo =>
      'You must be logged in to remove your photo.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Failed to remove photo: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'You must be logged in to upload a photo.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Failed to upload photo: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'You must be logged in to save your profile.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Failed to save profile: $error';
  }

  @override
  String get employee_drawer_exit => 'Exit';

  @override
  String get nav_dashboard => 'Dashboard';

  @override
  String get nav_goal_workspace => 'Goal Workspace';

  @override
  String get nav_my_profile => 'My Profile';

  @override
  String get nav_my_pdp => 'MyPdp';

  @override
  String get nav_progress_visuals => 'Progress Visuals';

  @override
  String get nav_alerts_nudges => 'Alerts & Nudges';

  @override
  String get nav_badges_points => 'Badges & Points';

  @override
  String get nav_season_challenges => 'Season Challenges';

  @override
  String get nav_leaderboard => 'Leaderboard';

  @override
  String get nav_repository_audit => 'Repository & Audit';

  @override
  String get nav_settings_privacy => 'Settings & Privacy';

  @override
  String get nav_team_challenges => 'Team Challenges';

  @override
  String get nav_team_alerts_nudges => 'Team Alerts & Nudges';

  @override
  String get nav_manager_inbox => 'Inbox';

  @override
  String get nav_review_team => 'Review Team';

  @override
  String get nav_admin_dashboard => 'Admin Dashboard';

  @override
  String get nav_user_management => 'User Management';

  @override
  String get nav_analytics => 'Analytics';

  @override
  String get nav_system_settings => 'System Settings';

  @override
  String get nav_security => 'Security';

  @override
  String get nav_backup_restore => 'Backup & Restore';

  @override
  String get employee_portal_title => 'Employee Portal';

  @override
  String get progress_visuals_error_loading_user_data =>
      'Error loading user data';

  @override
  String get progress_visuals_all_departments => 'All Departments';

  @override
  String get progress_visuals_send_nudge => 'Send Nudge';

  @override
  String get progress_visuals_meet => 'Meet';

  @override
  String get progress_visuals_view_details => 'View Details';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Nudge sent to $employeeName';
  }

  @override
  String get progress_visuals_debug_information => 'Debug Information';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Debug Error: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'AI Insights';

  @override
  String get alerts_nudges_ai_assistant => 'AI Assistant';

  @override
  String get alerts_nudges_refresh => 'Refresh';

  @override
  String get alerts_nudges_create_first_goal => 'Create Your First Goal';

  @override
  String get alerts_nudges_dismiss => 'Dismiss';

  @override
  String get alerts_nudges_copy => 'Copy';

  @override
  String get alerts_nudges_edit => 'Edit';

  @override
  String get manager_alerts_add_reschedule_note => 'Add Reschedule Note';

  @override
  String get manager_alerts_skip => 'Skip';

  @override
  String get manager_alerts_save => 'Save';

  @override
  String get manager_alerts_reject_goal => 'Reject Goal';

  @override
  String get manager_alerts_ai_team_insights => 'AI Team Insights';

  @override
  String get manager_alerts_all_priorities => 'All Priorities';

  @override
  String get manager_alerts_review_goal => 'Review Goal';

  @override
  String get manager_alerts_reschedule => 'Reschedule';

  @override
  String get manager_alerts_extend_deadline => 'Extend Deadline';

  @override
  String get manager_alerts_pause_goal => 'Pause Goal';

  @override
  String get manager_alerts_mark_burnout => 'Mark Burnout';

  @override
  String get manager_alerts_select_goal_hint => 'Select Goal';

  @override
  String get manager_alerts_send_bulk_nudge => 'Send Bulk Nudge';

  @override
  String get manager_alerts_send_to_all => 'Send to All';

  @override
  String get notifications_bell_ok => 'OK';

  @override
  String get landing_app_title => 'Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}

/// The translations for English, as used in South Africa (`en_ZA`).
class AppLocalizationsEnZa extends AppLocalizationsEn {
  AppLocalizationsEnZa() : super('en_ZA');

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Language setting has been updated';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get create => 'Create';

  @override
  String get submit => 'Submit';

  @override
  String get view => 'View';

  @override
  String get details => 'Details';

  @override
  String get settings_go_to => 'Go to Settings';

  @override
  String get sign_out => 'Sign Out';

  @override
  String get delete_account => 'Delete Account';

  @override
  String get export_my_data => 'Export My Data';

  @override
  String get send_password_reset_email => 'Send Password Reset Email';

  @override
  String get language_english => 'English';

  @override
  String get language_spanish => 'Spanish';

  @override
  String get language_french => 'French';

  @override
  String get language_german => 'German';

  @override
  String get time_15_minutes => '15 minutes';

  @override
  String get time_30_minutes => '30 minutes';

  @override
  String get time_60_minutes => '1 hour';

  @override
  String get time_120_minutes => '2 hours';

  @override
  String get status_all => 'All Statuses';

  @override
  String get status_verified => 'Verified';

  @override
  String get status_pending => 'Pending';

  @override
  String get status_rejected => 'Rejected';

  @override
  String get audit_export_csv => 'Export as CSV';

  @override
  String get audit_export_pdf => 'Export as PDF';

  @override
  String get audit_submit_for_audit => 'Submit for Audit';

  @override
  String get audit_no_timeline_events_yet => 'No timeline events yet';

  @override
  String get dashboard_refresh_data => 'Refresh Data';

  @override
  String get dashboard_recent_activity => 'Recent Activity';

  @override
  String get dashboard_quick_actions => 'Quick Actions';

  @override
  String get dashboard_upcoming_goals => 'Upcoming Goals';

  @override
  String get dashboard_add_goal => 'Add Goal';

  @override
  String get dashboard_awaiting_manager_approval =>
      'Awaiting manager approval.';

  @override
  String get employee_create_first_goal => 'Create Your First Goal';

  @override
  String get manager_team_kpis => 'Team KPIs';

  @override
  String get manager_team_health => 'Team Health';

  @override
  String get manager_activity_summary => 'Activity Summary';

  @override
  String get manager_top_performers => 'Top Performers';

  @override
  String get manager_no_performers_yet => 'No performers yet';

  @override
  String get manager_quick_actions => 'Quick Actions';

  @override
  String get manager_complete_season => 'Complete Season';

  @override
  String manager_team_size(Object teamSize) {
    return 'Team size: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Join Team Goal';

  @override
  String get team_goal_join_cancel => 'Cancel';

  @override
  String get team_goal_join_confirm => 'Join Team';

  @override
  String team_details_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get team_goal_not_found => 'Team goal not found.';

  @override
  String get manager_inbox_approve => 'Approve';

  @override
  String get manager_inbox_request_changes => 'Request changes';

  @override
  String get manager_inbox_reject => 'Reject';

  @override
  String get manager_inbox_mark_all_as_read => 'Mark all as read';

  @override
  String get manager_inbox_view_goal => 'View Goal';

  @override
  String get manager_inbox_view_badges => 'View Badges';

  @override
  String get manager_inbox_all_priorities => 'All Priorities';

  @override
  String get manager_review_nudge => 'Nudge';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Kudos';

  @override
  String get manager_review_activity => 'Activity';

  @override
  String get manager_review_send => 'Send';

  @override
  String get manager_review_schedule => 'Schedule';

  @override
  String get manager_review_send_kudos => 'Send Kudos';

  @override
  String get manager_review_close => 'Close';

  @override
  String get manager_review_check_authentication => 'Check Authentication';

  @override
  String get season_management_title => 'Season Management';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Manage $seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Extend Season';

  @override
  String get season_management_view_celebration => 'View Celebration';

  @override
  String get season_challenge_title => 'Season Challenge';

  @override
  String get team_challenges_create_season => 'Create Season';

  @override
  String get team_challenges_view_details => 'View Details';

  @override
  String get team_challenges_manage => 'Manage';

  @override
  String get team_challenges_celebration => 'Celebration';

  @override
  String get team_challenges_paused_only => 'Paused only';

  @override
  String get season_details_not_found => 'Season not found';

  @override
  String get season_details_complete_season => 'Complete Season';

  @override
  String get season_details_extend_season => 'Extend Season';

  @override
  String get season_details_celebrate => 'Celebrate';

  @override
  String get season_details_recompute => 'Recompute';

  @override
  String get season_details_delete_season => 'Delete Season';

  @override
  String get season_details_force_complete_title => 'Force Complete Season?';

  @override
  String get season_details_force_complete_confirm => 'Force Complete';

  @override
  String get season_details_complete_title => 'Complete Season?';

  @override
  String get season_details_complete_confirm => 'Complete';

  @override
  String get season_details_delete_title => 'Delete Season?';

  @override
  String get season_details_delete_confirm => 'Delete';

  @override
  String get season_goal_completion_title => 'Complete Season Goal';

  @override
  String get season_goal_completion_go_back => 'Go Back';

  @override
  String get season_celebration_share => 'Share Celebration';

  @override
  String get season_celebration_create_new => 'Create New Season';

  @override
  String get season_celebration_shared_success => 'Celebration shared!';

  @override
  String get employee_season_join => 'Join Season';

  @override
  String get employee_season_view_details => 'View Details';

  @override
  String get employee_season_complete_goals => 'Complete Goals';

  @override
  String get employee_season_update => 'Update';

  @override
  String get employee_season_view_celebration => 'View Celebration';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'Successfully joined \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Error joining season: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'No season goals found for \"$seasonTitle\" yet.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Failed to open goal details: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'Submitted for manager approval';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Failed to submit for approval: $error';
  }

  @override
  String get goal_delete_title => 'Delete Goal';

  @override
  String get goal_deleted => 'Goal deleted';

  @override
  String goal_delete_error(Object error) {
    return 'Failed to delete goal: $error';
  }

  @override
  String get goal_start_success => 'Goal started! +20 points earned 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Error starting goal: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Please start the goal before completing it.';

  @override
  String get goal_complete_require_100 => 'Set progress to 100% to complete.';

  @override
  String get goal_complete_success => 'Goal completed! +100 points earned 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Error completing goal: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Progress updated to $progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Error updating progress: $error';
  }

  @override
  String get goal_set_to_100 => 'Set to 100%';

  @override
  String get goal_submit_for_approval_title => 'Submit for Approval';

  @override
  String get goal_add_milestone => 'Add Milestone';

  @override
  String get goal_milestone_requires_sign_in =>
      'You must be signed in to manage milestones.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Completed goals can no longer accept new milestones.';

  @override
  String get goal_milestone_title_required => 'Title is required.';

  @override
  String get goal_milestone_due_date_required => 'Select a due date.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Failed to save milestone: $error';
  }

  @override
  String get goal_milestone_deadline_hint => 'Tap to choose deadline';

  @override
  String get goal_milestone_change => 'Change';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'Marked as $status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Failed to update milestone: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Delete Milestone';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Remove this milestone from the goal?';

  @override
  String get goal_milestone_deleted => 'Milestone deleted.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Failed to delete milestone: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Edit details';

  @override
  String get goal_milestone_mark_not_started => 'Mark Not Started';

  @override
  String get goal_milestone_mark_in_progress => 'Mark In Progress';

  @override
  String get goal_milestone_mark_blocked => 'Mark Blocked';

  @override
  String get goal_milestone_mark_completed => 'Mark Completed';

  @override
  String get manager_team_workspace_create_team_goal => 'Create Team Goal';

  @override
  String get manager_team_workspace_view_details => 'View Details';

  @override
  String get manager_team_workspace_manage_team => 'Manage Team';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Create Team Goal';

  @override
  String get database_test_title => 'Database Test';

  @override
  String get database_test_add_goal => 'Add Goal';

  @override
  String get database_test_add_sample_goals => 'Add Sample Goals';

  @override
  String get employee_profile_detail_send_nudge => 'Send Nudge';

  @override
  String get employee_profile_detail_schedule_meeting => 'Schedule Meeting';

  @override
  String get employee_profile_detail_give_recognition => 'Give Recognition';

  @override
  String get employee_profile_detail_assign_goal => 'Assign Goal';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Functionality will be implemented here';

  @override
  String get my_goal_workspace_suggest => 'Suggest';

  @override
  String get my_goal_workspace_generate => 'Generate';

  @override
  String get my_goal_workspace_enter_goal_title => 'Please enter a goal title';

  @override
  String get my_goal_workspace_select_target_date =>
      'Please select a target date';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Error creating goal: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Create Goal';

  @override
  String get team_chats_edit_message => 'Edit message';

  @override
  String get team_chats_delete_message_title => 'Delete message?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'This action cannot be undone.';

  @override
  String get gamification_title => 'Gamification';

  @override
  String get gamification_content => 'Gamification Screen Content';

  @override
  String get my_pdp_ok => 'OK';

  @override
  String get my_pdp_upload_file => 'Upload file (PDF/Word/Image)';

  @override
  String get my_pdp_save_note_link => 'Save note/link';

  @override
  String get my_pdp_change_evidence => 'Change Evidence';

  @override
  String get my_pdp_go_to_settings => 'Go to Settings';

  @override
  String get my_pdp_add_session => '+1 session';

  @override
  String get my_pdp_module_complete => 'Module complete';

  @override
  String get role_access_restricted_title => 'Access restricted';

  @override
  String role_access_restricted_body(Object role) {
    return 'Your role ($role) does not have access to this page.';
  }

  @override
  String get role_go_to_my_portal => 'Go to my portal';

  @override
  String get evidence_sign_in_required =>
      'Please sign in to view your evidence.';

  @override
  String get evidence_sort_by_date => 'Sort by Date';

  @override
  String get evidence_sort_by_title => 'Sort by Title';

  @override
  String get evidence_no_evidence_found => 'No evidence found.';

  @override
  String get evidence_dialog_title => 'Evidence';

  @override
  String get employee_profile_remove_photo => 'Remove Photo';

  @override
  String get employee_profile_login_required_remove_photo =>
      'You must be logged in to remove your photo.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Failed to remove photo: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'You must be logged in to upload a photo.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Failed to upload photo: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'You must be logged in to save your profile.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Failed to save profile: $error';
  }

  @override
  String get employee_drawer_exit => 'Exit';

  @override
  String get nav_dashboard => 'Dashboard';

  @override
  String get nav_goal_workspace => 'Goal Workspace';

  @override
  String get nav_my_profile => 'My Profile';

  @override
  String get nav_my_pdp => 'MyPdp';

  @override
  String get nav_progress_visuals => 'Progress Visuals';

  @override
  String get nav_alerts_nudges => 'Alerts & Nudges';

  @override
  String get nav_badges_points => 'Badges & Points';

  @override
  String get nav_season_challenges => 'Season Challenges';

  @override
  String get nav_leaderboard => 'Leaderboard';

  @override
  String get nav_repository_audit => 'Repository & Audit';

  @override
  String get nav_settings_privacy => 'Settings & Privacy';

  @override
  String get nav_team_challenges => 'Team Challenges';

  @override
  String get nav_team_alerts_nudges => 'Team Alerts & Nudges';

  @override
  String get nav_manager_inbox => 'Inbox';

  @override
  String get nav_review_team => 'Review Team';

  @override
  String get nav_admin_dashboard => 'Admin Dashboard';

  @override
  String get nav_user_management => 'User Management';

  @override
  String get nav_analytics => 'Analytics';

  @override
  String get nav_system_settings => 'System Settings';

  @override
  String get nav_security => 'Security';

  @override
  String get nav_backup_restore => 'Backup & Restore';

  @override
  String get employee_portal_title => 'Employee Portal';

  @override
  String get progress_visuals_error_loading_user_data =>
      'Error loading user data';

  @override
  String get progress_visuals_all_departments => 'All Departments';

  @override
  String get progress_visuals_send_nudge => 'Send Nudge';

  @override
  String get progress_visuals_meet => 'Meet';

  @override
  String get progress_visuals_view_details => 'View Details';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Nudge sent to $employeeName';
  }

  @override
  String get progress_visuals_debug_information => 'Debug Information';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Debug Error: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'AI Insights';

  @override
  String get alerts_nudges_ai_assistant => 'AI Assistant';

  @override
  String get alerts_nudges_refresh => 'Refresh';

  @override
  String get alerts_nudges_create_first_goal => 'Create Your First Goal';

  @override
  String get alerts_nudges_dismiss => 'Dismiss';

  @override
  String get alerts_nudges_copy => 'Copy';

  @override
  String get alerts_nudges_edit => 'Edit';

  @override
  String get manager_alerts_add_reschedule_note => 'Add Reschedule Note';

  @override
  String get manager_alerts_skip => 'Skip';

  @override
  String get manager_alerts_save => 'Save';

  @override
  String get manager_alerts_reject_goal => 'Reject Goal';

  @override
  String get manager_alerts_ai_team_insights => 'AI Team Insights';

  @override
  String get manager_alerts_all_priorities => 'All Priorities';

  @override
  String get manager_alerts_review_goal => 'Review Goal';

  @override
  String get manager_alerts_reschedule => 'Reschedule';

  @override
  String get manager_alerts_extend_deadline => 'Extend Deadline';

  @override
  String get manager_alerts_pause_goal => 'Pause Goal';

  @override
  String get manager_alerts_mark_burnout => 'Mark Burnout';

  @override
  String get manager_alerts_select_goal_hint => 'Select Goal';

  @override
  String get manager_alerts_send_bulk_nudge => 'Send Bulk Nudge';

  @override
  String get manager_alerts_send_to_all => 'Send to All';

  @override
  String get notifications_bell_ok => 'OK';

  @override
  String get landing_app_title => 'Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}
