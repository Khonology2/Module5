import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';
import 'app_localizations_en.dart';
import 'app_localizations_nr.dart';
import 'app_localizations_nso.dart';
import 'app_localizations_ss.dart';
import 'app_localizations_st.dart';
import 'app_localizations_tn.dart';
import 'app_localizations_ts.dart';
import 'app_localizations_ve.dart';
import 'app_localizations_xh.dart';
import 'app_localizations_zu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('af'),
    Locale('en'),
    Locale('en', 'ZA'),
    Locale('nr'),
    Locale('nso'),
    Locale('ss'),
    Locale('st'),
    Locale('tn'),
    Locale('ts'),
    Locale('ve'),
    Locale('xh'),
    Locale('zu'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Personal Development Hub'**
  String get app_title;

  /// No description provided for @language_updated.
  ///
  /// In en_ZA, this message translates to:
  /// **'Language setting has been updated'**
  String get language_updated;

  /// No description provided for @ok.
  ///
  /// In en_ZA, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en_ZA, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en_ZA, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en_ZA, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en_ZA, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en_ZA, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @create.
  ///
  /// In en_ZA, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @submit.
  ///
  /// In en_ZA, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @view.
  ///
  /// In en_ZA, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @details.
  ///
  /// In en_ZA, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @settings_go_to.
  ///
  /// In en_ZA, this message translates to:
  /// **'Go to Settings'**
  String get settings_go_to;

  /// No description provided for @sign_out.
  ///
  /// In en_ZA, this message translates to:
  /// **'Sign Out'**
  String get sign_out;

  /// No description provided for @delete_account.
  ///
  /// In en_ZA, this message translates to:
  /// **'Delete Account'**
  String get delete_account;

  /// No description provided for @export_my_data.
  ///
  /// In en_ZA, this message translates to:
  /// **'Export My Data'**
  String get export_my_data;

  /// No description provided for @send_password_reset_email.
  ///
  /// In en_ZA, this message translates to:
  /// **'Send Password Reset Email'**
  String get send_password_reset_email;

  /// No description provided for @language_english.
  ///
  /// In en_ZA, this message translates to:
  /// **'English'**
  String get language_english;

  /// No description provided for @language_spanish.
  ///
  /// In en_ZA, this message translates to:
  /// **'Spanish'**
  String get language_spanish;

  /// No description provided for @language_french.
  ///
  /// In en_ZA, this message translates to:
  /// **'French'**
  String get language_french;

  /// No description provided for @language_german.
  ///
  /// In en_ZA, this message translates to:
  /// **'German'**
  String get language_german;

  /// No description provided for @time_15_minutes.
  ///
  /// In en_ZA, this message translates to:
  /// **'15 minutes'**
  String get time_15_minutes;

  /// No description provided for @time_30_minutes.
  ///
  /// In en_ZA, this message translates to:
  /// **'30 minutes'**
  String get time_30_minutes;

  /// No description provided for @time_60_minutes.
  ///
  /// In en_ZA, this message translates to:
  /// **'1 hour'**
  String get time_60_minutes;

  /// No description provided for @time_120_minutes.
  ///
  /// In en_ZA, this message translates to:
  /// **'2 hours'**
  String get time_120_minutes;

  /// No description provided for @status_all.
  ///
  /// In en_ZA, this message translates to:
  /// **'All Statuses'**
  String get status_all;

  /// No description provided for @status_verified.
  ///
  /// In en_ZA, this message translates to:
  /// **'Verified'**
  String get status_verified;

  /// No description provided for @status_pending.
  ///
  /// In en_ZA, this message translates to:
  /// **'Pending'**
  String get status_pending;

  /// No description provided for @status_rejected.
  ///
  /// In en_ZA, this message translates to:
  /// **'Rejected'**
  String get status_rejected;

  /// No description provided for @audit_export_csv.
  ///
  /// In en_ZA, this message translates to:
  /// **'Export as CSV'**
  String get audit_export_csv;

  /// No description provided for @audit_export_pdf.
  ///
  /// In en_ZA, this message translates to:
  /// **'Export as PDF'**
  String get audit_export_pdf;

  /// No description provided for @audit_submit_for_audit.
  ///
  /// In en_ZA, this message translates to:
  /// **'Submit for Audit'**
  String get audit_submit_for_audit;

  /// No description provided for @audit_no_timeline_events_yet.
  ///
  /// In en_ZA, this message translates to:
  /// **'No timeline events yet'**
  String get audit_no_timeline_events_yet;

  /// No description provided for @dashboard_refresh_data.
  ///
  /// In en_ZA, this message translates to:
  /// **'Refresh Data'**
  String get dashboard_refresh_data;

  /// No description provided for @dashboard_recent_activity.
  ///
  /// In en_ZA, this message translates to:
  /// **'Recent Activity'**
  String get dashboard_recent_activity;

  /// No description provided for @dashboard_quick_actions.
  ///
  /// In en_ZA, this message translates to:
  /// **'Quick Actions'**
  String get dashboard_quick_actions;

  /// No description provided for @dashboard_upcoming_goals.
  ///
  /// In en_ZA, this message translates to:
  /// **'Upcoming Goals'**
  String get dashboard_upcoming_goals;

  /// No description provided for @dashboard_add_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Add Goal'**
  String get dashboard_add_goal;

  /// No description provided for @dashboard_awaiting_manager_approval.
  ///
  /// In en_ZA, this message translates to:
  /// **'Awaiting manager approval.'**
  String get dashboard_awaiting_manager_approval;

  /// No description provided for @employee_create_first_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Create Your First Goal'**
  String get employee_create_first_goal;

  /// No description provided for @manager_team_kpis.
  ///
  /// In en_ZA, this message translates to:
  /// **'Team KPIs'**
  String get manager_team_kpis;

  /// No description provided for @manager_team_health.
  ///
  /// In en_ZA, this message translates to:
  /// **'Team Health'**
  String get manager_team_health;

  /// No description provided for @manager_activity_summary.
  ///
  /// In en_ZA, this message translates to:
  /// **'Activity Summary'**
  String get manager_activity_summary;

  /// No description provided for @manager_top_performers.
  ///
  /// In en_ZA, this message translates to:
  /// **'Top Performers'**
  String get manager_top_performers;

  /// No description provided for @manager_no_performers_yet.
  ///
  /// In en_ZA, this message translates to:
  /// **'No performers yet'**
  String get manager_no_performers_yet;

  /// No description provided for @manager_quick_actions.
  ///
  /// In en_ZA, this message translates to:
  /// **'Quick Actions'**
  String get manager_quick_actions;

  /// No description provided for @manager_complete_season.
  ///
  /// In en_ZA, this message translates to:
  /// **'Complete Season'**
  String get manager_complete_season;

  /// Shows current team size.
  ///
  /// In en_ZA, this message translates to:
  /// **'Team size: {teamSize}'**
  String manager_team_size(Object teamSize);

  /// No description provided for @team_goal_join_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Join Team Goal'**
  String get team_goal_join_title;

  /// No description provided for @team_goal_join_cancel.
  ///
  /// In en_ZA, this message translates to:
  /// **'Cancel'**
  String get team_goal_join_cancel;

  /// No description provided for @team_goal_join_confirm.
  ///
  /// In en_ZA, this message translates to:
  /// **'Join Team'**
  String get team_goal_join_confirm;

  /// No description provided for @team_details_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Error: {error}'**
  String team_details_error(Object error);

  /// No description provided for @team_goal_not_found.
  ///
  /// In en_ZA, this message translates to:
  /// **'Team goal not found.'**
  String get team_goal_not_found;

  /// No description provided for @manager_inbox_approve.
  ///
  /// In en_ZA, this message translates to:
  /// **'Approve'**
  String get manager_inbox_approve;

  /// No description provided for @manager_inbox_request_changes.
  ///
  /// In en_ZA, this message translates to:
  /// **'Request changes'**
  String get manager_inbox_request_changes;

  /// No description provided for @manager_inbox_reject.
  ///
  /// In en_ZA, this message translates to:
  /// **'Reject'**
  String get manager_inbox_reject;

  /// No description provided for @manager_inbox_mark_all_as_read.
  ///
  /// In en_ZA, this message translates to:
  /// **'Mark all as read'**
  String get manager_inbox_mark_all_as_read;

  /// No description provided for @manager_inbox_view_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'View Goal'**
  String get manager_inbox_view_goal;

  /// No description provided for @manager_inbox_view_badges.
  ///
  /// In en_ZA, this message translates to:
  /// **'View Badges'**
  String get manager_inbox_view_badges;

  /// No description provided for @manager_inbox_all_priorities.
  ///
  /// In en_ZA, this message translates to:
  /// **'All Priorities'**
  String get manager_inbox_all_priorities;

  /// No description provided for @manager_review_nudge.
  ///
  /// In en_ZA, this message translates to:
  /// **'Nudge'**
  String get manager_review_nudge;

  /// No description provided for @manager_review_1_1.
  ///
  /// In en_ZA, this message translates to:
  /// **'1:1'**
  String get manager_review_1_1;

  /// No description provided for @manager_review_kudos.
  ///
  /// In en_ZA, this message translates to:
  /// **'Kudos'**
  String get manager_review_kudos;

  /// No description provided for @manager_review_activity.
  ///
  /// In en_ZA, this message translates to:
  /// **'Activity'**
  String get manager_review_activity;

  /// No description provided for @manager_review_send.
  ///
  /// In en_ZA, this message translates to:
  /// **'Send'**
  String get manager_review_send;

  /// No description provided for @manager_review_schedule.
  ///
  /// In en_ZA, this message translates to:
  /// **'Schedule'**
  String get manager_review_schedule;

  /// No description provided for @manager_review_send_kudos.
  ///
  /// In en_ZA, this message translates to:
  /// **'Send Kudos'**
  String get manager_review_send_kudos;

  /// No description provided for @manager_review_close.
  ///
  /// In en_ZA, this message translates to:
  /// **'Close'**
  String get manager_review_close;

  /// No description provided for @manager_review_check_authentication.
  ///
  /// In en_ZA, this message translates to:
  /// **'Check Authentication'**
  String get manager_review_check_authentication;

  /// No description provided for @season_management_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Season Management'**
  String get season_management_title;

  /// No description provided for @season_management_manage_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Manage {seasonTitle}'**
  String season_management_manage_title(Object seasonTitle);

  /// No description provided for @season_management_extend_season.
  ///
  /// In en_ZA, this message translates to:
  /// **'Extend Season'**
  String get season_management_extend_season;

  /// No description provided for @season_management_view_celebration.
  ///
  /// In en_ZA, this message translates to:
  /// **'View Celebration'**
  String get season_management_view_celebration;

  /// No description provided for @season_challenge_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Season Challenge'**
  String get season_challenge_title;

  /// No description provided for @team_challenges_create_season.
  ///
  /// In en_ZA, this message translates to:
  /// **'Create Season'**
  String get team_challenges_create_season;

  /// No description provided for @team_challenges_view_details.
  ///
  /// In en_ZA, this message translates to:
  /// **'View Details'**
  String get team_challenges_view_details;

  /// No description provided for @team_challenges_manage.
  ///
  /// In en_ZA, this message translates to:
  /// **'Manage'**
  String get team_challenges_manage;

  /// No description provided for @team_challenges_celebration.
  ///
  /// In en_ZA, this message translates to:
  /// **'Celebration'**
  String get team_challenges_celebration;

  /// No description provided for @team_challenges_paused_only.
  ///
  /// In en_ZA, this message translates to:
  /// **'Paused only'**
  String get team_challenges_paused_only;

  /// No description provided for @season_details_not_found.
  ///
  /// In en_ZA, this message translates to:
  /// **'Season not found'**
  String get season_details_not_found;

  /// No description provided for @season_details_complete_season.
  ///
  /// In en_ZA, this message translates to:
  /// **'Complete Season'**
  String get season_details_complete_season;

  /// No description provided for @season_details_extend_season.
  ///
  /// In en_ZA, this message translates to:
  /// **'Extend Season'**
  String get season_details_extend_season;

  /// No description provided for @season_details_celebrate.
  ///
  /// In en_ZA, this message translates to:
  /// **'Celebrate'**
  String get season_details_celebrate;

  /// No description provided for @season_details_recompute.
  ///
  /// In en_ZA, this message translates to:
  /// **'Recompute'**
  String get season_details_recompute;

  /// No description provided for @season_details_delete_season.
  ///
  /// In en_ZA, this message translates to:
  /// **'Delete Season'**
  String get season_details_delete_season;

  /// No description provided for @season_details_force_complete_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Force Complete Season?'**
  String get season_details_force_complete_title;

  /// No description provided for @season_details_force_complete_confirm.
  ///
  /// In en_ZA, this message translates to:
  /// **'Force Complete'**
  String get season_details_force_complete_confirm;

  /// No description provided for @season_details_complete_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Complete Season?'**
  String get season_details_complete_title;

  /// No description provided for @season_details_complete_confirm.
  ///
  /// In en_ZA, this message translates to:
  /// **'Complete'**
  String get season_details_complete_confirm;

  /// No description provided for @season_details_delete_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Delete Season?'**
  String get season_details_delete_title;

  /// No description provided for @season_details_delete_confirm.
  ///
  /// In en_ZA, this message translates to:
  /// **'Delete'**
  String get season_details_delete_confirm;

  /// No description provided for @season_goal_completion_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Complete Season Goal'**
  String get season_goal_completion_title;

  /// No description provided for @season_goal_completion_go_back.
  ///
  /// In en_ZA, this message translates to:
  /// **'Go Back'**
  String get season_goal_completion_go_back;

  /// No description provided for @season_celebration_share.
  ///
  /// In en_ZA, this message translates to:
  /// **'Share Celebration'**
  String get season_celebration_share;

  /// No description provided for @season_celebration_create_new.
  ///
  /// In en_ZA, this message translates to:
  /// **'Create New Season'**
  String get season_celebration_create_new;

  /// No description provided for @season_celebration_shared_success.
  ///
  /// In en_ZA, this message translates to:
  /// **'Celebration shared!'**
  String get season_celebration_shared_success;

  /// No description provided for @employee_season_join.
  ///
  /// In en_ZA, this message translates to:
  /// **'Join Season'**
  String get employee_season_join;

  /// No description provided for @employee_season_view_details.
  ///
  /// In en_ZA, this message translates to:
  /// **'View Details'**
  String get employee_season_view_details;

  /// No description provided for @employee_season_complete_goals.
  ///
  /// In en_ZA, this message translates to:
  /// **'Complete Goals'**
  String get employee_season_complete_goals;

  /// No description provided for @employee_season_update.
  ///
  /// In en_ZA, this message translates to:
  /// **'Update'**
  String get employee_season_update;

  /// No description provided for @employee_season_view_celebration.
  ///
  /// In en_ZA, this message translates to:
  /// **'View Celebration'**
  String get employee_season_view_celebration;

  /// No description provided for @employee_season_joined_success.
  ///
  /// In en_ZA, this message translates to:
  /// **'Successfully joined \"{seasonTitle}\"!'**
  String employee_season_joined_success(Object seasonTitle);

  /// No description provided for @employee_season_join_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Error joining season: {error}'**
  String employee_season_join_error(Object error);

  /// No description provided for @employee_season_no_goals.
  ///
  /// In en_ZA, this message translates to:
  /// **'No season goals found for \"{seasonTitle}\" yet.'**
  String employee_season_no_goals(Object seasonTitle);

  /// No description provided for @employee_season_open_details_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to open goal details: {error}'**
  String employee_season_open_details_error(Object error);

  /// No description provided for @goal_submit_for_approval_snackbar.
  ///
  /// In en_ZA, this message translates to:
  /// **'Submitted for manager approval'**
  String get goal_submit_for_approval_snackbar;

  /// No description provided for @goal_submit_for_approval_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to submit for approval: {error}'**
  String goal_submit_for_approval_error(Object error);

  /// No description provided for @goal_delete_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Delete Goal'**
  String get goal_delete_title;

  /// No description provided for @goal_deleted.
  ///
  /// In en_ZA, this message translates to:
  /// **'Goal deleted'**
  String get goal_deleted;

  /// No description provided for @goal_delete_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to delete goal: {error}'**
  String goal_delete_error(Object error);

  /// No description provided for @goal_start_success.
  ///
  /// In en_ZA, this message translates to:
  /// **'Goal started! +20 points earned 🎉'**
  String get goal_start_success;

  /// No description provided for @goal_start_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Error starting goal: {error}'**
  String goal_start_error(Object error);

  /// No description provided for @goal_complete_require_start.
  ///
  /// In en_ZA, this message translates to:
  /// **'Please start the goal before completing it.'**
  String get goal_complete_require_start;

  /// No description provided for @goal_complete_require_100.
  ///
  /// In en_ZA, this message translates to:
  /// **'Set progress to 100% to complete.'**
  String get goal_complete_require_100;

  /// No description provided for @goal_complete_success.
  ///
  /// In en_ZA, this message translates to:
  /// **'Goal completed! +100 points earned 🏆'**
  String get goal_complete_success;

  /// No description provided for @goal_complete_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Error completing goal: {error}'**
  String goal_complete_error(Object error);

  /// No description provided for @goal_progress_updated.
  ///
  /// In en_ZA, this message translates to:
  /// **'Progress updated to {progress}%'**
  String goal_progress_updated(Object progress);

  /// No description provided for @goal_progress_update_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Error updating progress: {error}'**
  String goal_progress_update_error(Object error);

  /// No description provided for @goal_set_to_100.
  ///
  /// In en_ZA, this message translates to:
  /// **'Set to 100%'**
  String get goal_set_to_100;

  /// No description provided for @goal_submit_for_approval_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Submit for Approval'**
  String get goal_submit_for_approval_title;

  /// No description provided for @goal_add_milestone.
  ///
  /// In en_ZA, this message translates to:
  /// **'Add Milestone'**
  String get goal_add_milestone;

  /// No description provided for @goal_milestone_requires_sign_in.
  ///
  /// In en_ZA, this message translates to:
  /// **'You must be signed in to manage milestones.'**
  String get goal_milestone_requires_sign_in;

  /// No description provided for @goal_milestone_no_new_on_completed.
  ///
  /// In en_ZA, this message translates to:
  /// **'Completed goals can no longer accept new milestones.'**
  String get goal_milestone_no_new_on_completed;

  /// No description provided for @goal_milestone_title_required.
  ///
  /// In en_ZA, this message translates to:
  /// **'Title is required.'**
  String get goal_milestone_title_required;

  /// No description provided for @goal_milestone_due_date_required.
  ///
  /// In en_ZA, this message translates to:
  /// **'Select a due date.'**
  String get goal_milestone_due_date_required;

  /// No description provided for @goal_milestone_save_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to save milestone: {error}'**
  String goal_milestone_save_error(Object error);

  /// No description provided for @goal_milestone_deadline_hint.
  ///
  /// In en_ZA, this message translates to:
  /// **'Tap to choose deadline'**
  String get goal_milestone_deadline_hint;

  /// No description provided for @goal_milestone_change.
  ///
  /// In en_ZA, this message translates to:
  /// **'Change'**
  String get goal_milestone_change;

  /// No description provided for @goal_milestone_marked_as.
  ///
  /// In en_ZA, this message translates to:
  /// **'Marked as {status}.'**
  String goal_milestone_marked_as(Object status);

  /// No description provided for @goal_milestone_update_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to update milestone: {error}'**
  String goal_milestone_update_error(Object error);

  /// No description provided for @goal_milestone_delete_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Delete Milestone'**
  String get goal_milestone_delete_title;

  /// No description provided for @goal_milestone_delete_confirm_text.
  ///
  /// In en_ZA, this message translates to:
  /// **'Remove this milestone from the goal?'**
  String get goal_milestone_delete_confirm_text;

  /// No description provided for @goal_milestone_deleted.
  ///
  /// In en_ZA, this message translates to:
  /// **'Milestone deleted.'**
  String get goal_milestone_deleted;

  /// No description provided for @goal_milestone_delete_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to delete milestone: {error}'**
  String goal_milestone_delete_error(Object error);

  /// No description provided for @goal_milestone_edit_details.
  ///
  /// In en_ZA, this message translates to:
  /// **'Edit details'**
  String get goal_milestone_edit_details;

  /// No description provided for @goal_milestone_mark_not_started.
  ///
  /// In en_ZA, this message translates to:
  /// **'Mark Not Started'**
  String get goal_milestone_mark_not_started;

  /// No description provided for @goal_milestone_mark_in_progress.
  ///
  /// In en_ZA, this message translates to:
  /// **'Mark In Progress'**
  String get goal_milestone_mark_in_progress;

  /// No description provided for @goal_milestone_mark_blocked.
  ///
  /// In en_ZA, this message translates to:
  /// **'Mark Blocked'**
  String get goal_milestone_mark_blocked;

  /// No description provided for @goal_milestone_mark_completed.
  ///
  /// In en_ZA, this message translates to:
  /// **'Mark Completed'**
  String get goal_milestone_mark_completed;

  /// No description provided for @manager_team_workspace_create_team_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Create Team Goal'**
  String get manager_team_workspace_create_team_goal;

  /// No description provided for @manager_team_workspace_view_details.
  ///
  /// In en_ZA, this message translates to:
  /// **'View Details'**
  String get manager_team_workspace_view_details;

  /// No description provided for @manager_team_workspace_manage_team.
  ///
  /// In en_ZA, this message translates to:
  /// **'Manage Team'**
  String get manager_team_workspace_manage_team;

  /// No description provided for @manager_team_workspace_dialog_create_team_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Create Team Goal'**
  String get manager_team_workspace_dialog_create_team_goal;

  /// No description provided for @database_test_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Database Test'**
  String get database_test_title;

  /// No description provided for @database_test_add_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Add Goal'**
  String get database_test_add_goal;

  /// No description provided for @database_test_add_sample_goals.
  ///
  /// In en_ZA, this message translates to:
  /// **'Add Sample Goals'**
  String get database_test_add_sample_goals;

  /// No description provided for @employee_profile_detail_send_nudge.
  ///
  /// In en_ZA, this message translates to:
  /// **'Send Nudge'**
  String get employee_profile_detail_send_nudge;

  /// No description provided for @employee_profile_detail_schedule_meeting.
  ///
  /// In en_ZA, this message translates to:
  /// **'Schedule Meeting'**
  String get employee_profile_detail_schedule_meeting;

  /// No description provided for @employee_profile_detail_give_recognition.
  ///
  /// In en_ZA, this message translates to:
  /// **'Give Recognition'**
  String get employee_profile_detail_give_recognition;

  /// No description provided for @employee_profile_detail_assign_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Assign Goal'**
  String get employee_profile_detail_assign_goal;

  /// No description provided for @employee_profile_detail_dialog_placeholder.
  ///
  /// In en_ZA, this message translates to:
  /// **'Functionality will be implemented here'**
  String get employee_profile_detail_dialog_placeholder;

  /// No description provided for @my_goal_workspace_suggest.
  ///
  /// In en_ZA, this message translates to:
  /// **'Suggest'**
  String get my_goal_workspace_suggest;

  /// No description provided for @my_goal_workspace_generate.
  ///
  /// In en_ZA, this message translates to:
  /// **'Generate'**
  String get my_goal_workspace_generate;

  /// No description provided for @my_goal_workspace_enter_goal_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Please enter a goal title'**
  String get my_goal_workspace_enter_goal_title;

  /// No description provided for @my_goal_workspace_select_target_date.
  ///
  /// In en_ZA, this message translates to:
  /// **'Please select a target date'**
  String get my_goal_workspace_select_target_date;

  /// No description provided for @my_goal_workspace_create_goal_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Error creating goal: {error}'**
  String my_goal_workspace_create_goal_error(Object error);

  /// No description provided for @my_goal_workspace_create_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Create Goal'**
  String get my_goal_workspace_create_goal;

  /// No description provided for @team_chats_edit_message.
  ///
  /// In en_ZA, this message translates to:
  /// **'Edit message'**
  String get team_chats_edit_message;

  /// No description provided for @team_chats_delete_message_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Delete message?'**
  String get team_chats_delete_message_title;

  /// No description provided for @team_chats_delete_message_confirm_text.
  ///
  /// In en_ZA, this message translates to:
  /// **'This action cannot be undone.'**
  String get team_chats_delete_message_confirm_text;

  /// No description provided for @gamification_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Gamification'**
  String get gamification_title;

  /// No description provided for @gamification_content.
  ///
  /// In en_ZA, this message translates to:
  /// **'Gamification Screen Content'**
  String get gamification_content;

  /// No description provided for @my_pdp_ok.
  ///
  /// In en_ZA, this message translates to:
  /// **'OK'**
  String get my_pdp_ok;

  /// No description provided for @my_pdp_upload_file.
  ///
  /// In en_ZA, this message translates to:
  /// **'Upload file (PDF/Word/Image)'**
  String get my_pdp_upload_file;

  /// No description provided for @my_pdp_save_note_link.
  ///
  /// In en_ZA, this message translates to:
  /// **'Save note/link'**
  String get my_pdp_save_note_link;

  /// No description provided for @my_pdp_change_evidence.
  ///
  /// In en_ZA, this message translates to:
  /// **'Change Evidence'**
  String get my_pdp_change_evidence;

  /// No description provided for @my_pdp_go_to_settings.
  ///
  /// In en_ZA, this message translates to:
  /// **'Go to Settings'**
  String get my_pdp_go_to_settings;

  /// No description provided for @my_pdp_add_session.
  ///
  /// In en_ZA, this message translates to:
  /// **'+1 session'**
  String get my_pdp_add_session;

  /// No description provided for @my_pdp_module_complete.
  ///
  /// In en_ZA, this message translates to:
  /// **'Module complete'**
  String get my_pdp_module_complete;

  /// No description provided for @role_access_restricted_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Access restricted'**
  String get role_access_restricted_title;

  /// No description provided for @role_access_restricted_body.
  ///
  /// In en_ZA, this message translates to:
  /// **'Your role ({role}) does not have access to this page.'**
  String role_access_restricted_body(Object role);

  /// No description provided for @role_go_to_my_portal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Go to my portal'**
  String get role_go_to_my_portal;

  /// No description provided for @evidence_sign_in_required.
  ///
  /// In en_ZA, this message translates to:
  /// **'Please sign in to view your evidence.'**
  String get evidence_sign_in_required;

  /// No description provided for @evidence_sort_by_date.
  ///
  /// In en_ZA, this message translates to:
  /// **'Sort by Date'**
  String get evidence_sort_by_date;

  /// No description provided for @evidence_sort_by_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Sort by Title'**
  String get evidence_sort_by_title;

  /// No description provided for @evidence_no_evidence_found.
  ///
  /// In en_ZA, this message translates to:
  /// **'No evidence found.'**
  String get evidence_no_evidence_found;

  /// No description provided for @evidence_dialog_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Evidence'**
  String get evidence_dialog_title;

  /// No description provided for @employee_profile_remove_photo.
  ///
  /// In en_ZA, this message translates to:
  /// **'Remove Photo'**
  String get employee_profile_remove_photo;

  /// No description provided for @employee_profile_login_required_remove_photo.
  ///
  /// In en_ZA, this message translates to:
  /// **'You must be logged in to remove your photo.'**
  String get employee_profile_login_required_remove_photo;

  /// No description provided for @employee_profile_remove_photo_fail.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to remove photo: {error}'**
  String employee_profile_remove_photo_fail(Object error);

  /// No description provided for @employee_profile_login_required_upload_photo.
  ///
  /// In en_ZA, this message translates to:
  /// **'You must be logged in to upload a photo.'**
  String get employee_profile_login_required_upload_photo;

  /// No description provided for @employee_profile_upload_photo_fail.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to upload photo: {error}'**
  String employee_profile_upload_photo_fail(Object error);

  /// No description provided for @employee_profile_login_required_save_profile.
  ///
  /// In en_ZA, this message translates to:
  /// **'You must be logged in to save your profile.'**
  String get employee_profile_login_required_save_profile;

  /// No description provided for @employee_profile_save_profile_fail.
  ///
  /// In en_ZA, this message translates to:
  /// **'Failed to save profile: {error}'**
  String employee_profile_save_profile_fail(Object error);

  /// No description provided for @employee_drawer_exit.
  ///
  /// In en_ZA, this message translates to:
  /// **'Exit'**
  String get employee_drawer_exit;

  /// No description provided for @nav_dashboard.
  ///
  /// In en_ZA, this message translates to:
  /// **'Dashboard'**
  String get nav_dashboard;

  /// No description provided for @nav_goal_workspace.
  ///
  /// In en_ZA, this message translates to:
  /// **'Goal Workspace'**
  String get nav_goal_workspace;

  /// No description provided for @nav_my_profile.
  ///
  /// In en_ZA, this message translates to:
  /// **'My Profile'**
  String get nav_my_profile;

  /// No description provided for @nav_my_pdp.
  ///
  /// In en_ZA, this message translates to:
  /// **'My PDP'**
  String get nav_my_pdp;

  /// No description provided for @nav_progress_visuals.
  ///
  /// In en_ZA, this message translates to:
  /// **'Progress Visuals'**
  String get nav_progress_visuals;

  /// No description provided for @nav_alerts_nudges.
  ///
  /// In en_ZA, this message translates to:
  /// **'Alerts & Nudges'**
  String get nav_alerts_nudges;

  /// No description provided for @nav_badges_points.
  ///
  /// In en_ZA, this message translates to:
  /// **'Badges & Points'**
  String get nav_badges_points;

  /// No description provided for @nav_season_challenges.
  ///
  /// In en_ZA, this message translates to:
  /// **'Season Challenges'**
  String get nav_season_challenges;

  /// No description provided for @nav_leaderboard.
  ///
  /// In en_ZA, this message translates to:
  /// **'Leaderboard'**
  String get nav_leaderboard;

  /// No description provided for @nav_repository_audit.
  ///
  /// In en_ZA, this message translates to:
  /// **'Repository & Audit'**
  String get nav_repository_audit;

  /// No description provided for @nav_settings_privacy.
  ///
  /// In en_ZA, this message translates to:
  /// **'Settings & Privacy'**
  String get nav_settings_privacy;

  /// No description provided for @nav_team_challenges.
  ///
  /// In en_ZA, this message translates to:
  /// **'Team Challenges'**
  String get nav_team_challenges;

  /// No description provided for @nav_team_alerts_nudges.
  ///
  /// In en_ZA, this message translates to:
  /// **'Team Alerts & Nudges'**
  String get nav_team_alerts_nudges;

  /// No description provided for @nav_manager_inbox.
  ///
  /// In en_ZA, this message translates to:
  /// **'Inbox'**
  String get nav_manager_inbox;

  /// No description provided for @nav_review_team.
  ///
  /// In en_ZA, this message translates to:
  /// **'Review Team'**
  String get nav_review_team;

  /// No description provided for @nav_admin_dashboard.
  ///
  /// In en_ZA, this message translates to:
  /// **'Admin Dashboard'**
  String get nav_admin_dashboard;

  /// No description provided for @nav_user_management.
  ///
  /// In en_ZA, this message translates to:
  /// **'User Management'**
  String get nav_user_management;

  /// No description provided for @nav_analytics.
  ///
  /// In en_ZA, this message translates to:
  /// **'Analytics'**
  String get nav_analytics;

  /// No description provided for @nav_system_settings.
  ///
  /// In en_ZA, this message translates to:
  /// **'System Settings'**
  String get nav_system_settings;

  /// No description provided for @nav_security.
  ///
  /// In en_ZA, this message translates to:
  /// **'Security'**
  String get nav_security;

  /// No description provided for @nav_backup_restore.
  ///
  /// In en_ZA, this message translates to:
  /// **'Backup & Restore'**
  String get nav_backup_restore;

  /// No description provided for @employee_portal_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Employee Portal'**
  String get employee_portal_title;

  /// No description provided for @progress_visuals_error_loading_user_data.
  ///
  /// In en_ZA, this message translates to:
  /// **'Error loading user data'**
  String get progress_visuals_error_loading_user_data;

  /// No description provided for @progress_visuals_all_departments.
  ///
  /// In en_ZA, this message translates to:
  /// **'All Departments'**
  String get progress_visuals_all_departments;

  /// No description provided for @progress_visuals_send_nudge.
  ///
  /// In en_ZA, this message translates to:
  /// **'Send Nudge'**
  String get progress_visuals_send_nudge;

  /// No description provided for @progress_visuals_meet.
  ///
  /// In en_ZA, this message translates to:
  /// **'Meet'**
  String get progress_visuals_meet;

  /// No description provided for @progress_visuals_view_details.
  ///
  /// In en_ZA, this message translates to:
  /// **'View Details'**
  String get progress_visuals_view_details;

  /// No description provided for @progress_visuals_nudge_sent.
  ///
  /// In en_ZA, this message translates to:
  /// **'Nudge sent to {employeeName}'**
  String progress_visuals_nudge_sent(Object employeeName);

  /// No description provided for @progress_visuals_debug_information.
  ///
  /// In en_ZA, this message translates to:
  /// **'Debug Information'**
  String get progress_visuals_debug_information;

  /// No description provided for @progress_visuals_debug_error.
  ///
  /// In en_ZA, this message translates to:
  /// **'Debug Error: {error}'**
  String progress_visuals_debug_error(Object error);

  /// No description provided for @progress_visuals_ai_insights.
  ///
  /// In en_ZA, this message translates to:
  /// **'AI Insights'**
  String get progress_visuals_ai_insights;

  /// No description provided for @alerts_nudges_ai_assistant.
  ///
  /// In en_ZA, this message translates to:
  /// **'AI Assistant'**
  String get alerts_nudges_ai_assistant;

  /// No description provided for @alerts_nudges_refresh.
  ///
  /// In en_ZA, this message translates to:
  /// **'Refresh'**
  String get alerts_nudges_refresh;

  /// No description provided for @alerts_nudges_create_first_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Create Your First Goal'**
  String get alerts_nudges_create_first_goal;

  /// No description provided for @alerts_nudges_dismiss.
  ///
  /// In en_ZA, this message translates to:
  /// **'Dismiss'**
  String get alerts_nudges_dismiss;

  /// No description provided for @alerts_nudges_copy.
  ///
  /// In en_ZA, this message translates to:
  /// **'Copy'**
  String get alerts_nudges_copy;

  /// No description provided for @alerts_nudges_edit.
  ///
  /// In en_ZA, this message translates to:
  /// **'Edit'**
  String get alerts_nudges_edit;

  /// No description provided for @manager_alerts_add_reschedule_note.
  ///
  /// In en_ZA, this message translates to:
  /// **'Add Reschedule Note'**
  String get manager_alerts_add_reschedule_note;

  /// No description provided for @manager_alerts_skip.
  ///
  /// In en_ZA, this message translates to:
  /// **'Skip'**
  String get manager_alerts_skip;

  /// No description provided for @manager_alerts_save.
  ///
  /// In en_ZA, this message translates to:
  /// **'Save'**
  String get manager_alerts_save;

  /// No description provided for @manager_alerts_reject_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Reject Goal'**
  String get manager_alerts_reject_goal;

  /// No description provided for @manager_alerts_ai_team_insights.
  ///
  /// In en_ZA, this message translates to:
  /// **'AI Team Insights'**
  String get manager_alerts_ai_team_insights;

  /// No description provided for @manager_alerts_all_priorities.
  ///
  /// In en_ZA, this message translates to:
  /// **'All Priorities'**
  String get manager_alerts_all_priorities;

  /// No description provided for @manager_alerts_review_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Review Goal'**
  String get manager_alerts_review_goal;

  /// No description provided for @manager_alerts_reschedule.
  ///
  /// In en_ZA, this message translates to:
  /// **'Reschedule'**
  String get manager_alerts_reschedule;

  /// No description provided for @manager_alerts_extend_deadline.
  ///
  /// In en_ZA, this message translates to:
  /// **'Extend Deadline'**
  String get manager_alerts_extend_deadline;

  /// No description provided for @manager_alerts_pause_goal.
  ///
  /// In en_ZA, this message translates to:
  /// **'Pause Goal'**
  String get manager_alerts_pause_goal;

  /// No description provided for @manager_alerts_mark_burnout.
  ///
  /// In en_ZA, this message translates to:
  /// **'Mark Burnout'**
  String get manager_alerts_mark_burnout;

  /// No description provided for @manager_alerts_select_goal_hint.
  ///
  /// In en_ZA, this message translates to:
  /// **'Select Goal'**
  String get manager_alerts_select_goal_hint;

  /// No description provided for @manager_alerts_send_bulk_nudge.
  ///
  /// In en_ZA, this message translates to:
  /// **'Send Bulk Nudge'**
  String get manager_alerts_send_bulk_nudge;

  /// No description provided for @manager_alerts_send_to_all.
  ///
  /// In en_ZA, this message translates to:
  /// **'Send to All'**
  String get manager_alerts_send_to_all;

  /// No description provided for @notifications_bell_ok.
  ///
  /// In en_ZA, this message translates to:
  /// **'OK'**
  String get notifications_bell_ok;

  /// No description provided for @landing_app_title.
  ///
  /// In en_ZA, this message translates to:
  /// **'Personal Development Hub'**
  String get landing_app_title;

  /// Greeting on employee dashboard
  ///
  /// In en_ZA, this message translates to:
  /// **'{greeting}, {userName}!'**
  String greeting_user(Object greeting, Object userName);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'af',
    'en',
    'nr',
    'nso',
    'ss',
    'st',
    'tn',
    'ts',
    've',
    'xh',
    'zu',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'ZA':
            return AppLocalizationsEnZa();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return AppLocalizationsAf();
    case 'en':
      return AppLocalizationsEn();
    case 'nr':
      return AppLocalizationsNr();
    case 'nso':
      return AppLocalizationsNso();
    case 'ss':
      return AppLocalizationsSs();
    case 'st':
      return AppLocalizationsSt();
    case 'tn':
      return AppLocalizationsTn();
    case 'ts':
      return AppLocalizationsTs();
    case 've':
      return AppLocalizationsVe();
    case 'xh':
      return AppLocalizationsXh();
    case 'zu':
      return AppLocalizationsZu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
