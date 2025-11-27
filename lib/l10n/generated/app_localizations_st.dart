// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Southern Sotho (`st`).
class AppLocalizationsSt extends AppLocalizations {
  AppLocalizationsSt([String locale = 'st']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Puo e ntjhafaditsoe';

  @override
  String get ok => 'Ho lokile';

  @override
  String get cancel => 'Khansela';

  @override
  String get close => 'Koala';

  @override
  String get retry => 'Leka hape';

  @override
  String get save => 'Boloka';

  @override
  String get delete => 'Phumula';

  @override
  String get create => 'Etsa';

  @override
  String get submit => 'Romela';

  @override
  String get view => 'Sheba';

  @override
  String get details => 'Lintlha';

  @override
  String get settings_go_to => 'Eya ho Di-setting';

  @override
  String get sign_out => 'Tsoa';

  @override
  String get delete_account => 'Phumula akhaonte';

  @override
  String get export_my_data => 'Romela data ya ka kantle';

  @override
  String get send_password_reset_email =>
      'Romela imeile ya ho seta phasewete hape';

  @override
  String get language_english => 'Senyesemane';

  @override
  String get language_spanish => 'Sepanish';

  @override
  String get language_french => 'Sefora';

  @override
  String get language_german => 'Sejeremane';

  @override
  String get time_15_minutes => 'metsotso e 15';

  @override
  String get time_30_minutes => 'metsotso e 30';

  @override
  String get time_60_minutes => 'hora e 1';

  @override
  String get time_120_minutes => 'di-hora tse 2';

  @override
  String get status_all => 'Maemo ohle';

  @override
  String get status_verified => 'Netefaditsweng';

  @override
  String get status_pending => 'E sa ntse e emetse';

  @override
  String get status_rejected => 'Hanne';

  @override
  String get audit_export_csv => 'Romela joalo ka CSV';

  @override
  String get audit_export_pdf => 'Romela joalo ka PDF';

  @override
  String get audit_submit_for_audit => 'Romela bakeng sa tlhahlobo';

  @override
  String get audit_no_timeline_events_yet =>
      'Ha ho diketsahalo lenaneng la nako hajoale';

  @override
  String get dashboard_refresh_data => 'Nchafatsa data';

  @override
  String get dashboard_recent_activity => 'Mesebetsi ya morao tjena';

  @override
  String get dashboard_quick_actions => 'Diketso tse potlakileng';

  @override
  String get dashboard_upcoming_goals => 'Dikgomo tse tlang';

  @override
  String get dashboard_add_goal => 'Eketsa sepheo';

  @override
  String get dashboard_awaiting_manager_approval =>
      'E emetse tumello ya mookamedi.';

  @override
  String get employee_create_first_goal => 'Theha sepheo sa hao sa pele';

  @override
  String get manager_team_kpis => 'Dikgomo tsa KPI tsa sehlopha';

  @override
  String get manager_team_health => 'Bophelo ba sehlopha';

  @override
  String get manager_activity_summary => 'Kakaretso ya mesebetsi';

  @override
  String get manager_top_performers =>
      'Batho ba sebetsang hantle ka ho fetisisa';

  @override
  String get manager_no_performers_yet =>
      'Ha ho bashebetsi ba hlollang hajoale';

  @override
  String get manager_quick_actions => 'Diketso tse potlakileng';

  @override
  String get manager_complete_season => 'Qeta sehla';

  @override
  String manager_team_size(Object teamSize) {
    return 'Boholo ba sehlopha: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Kena sepheong sa sehlopha';

  @override
  String get team_goal_join_cancel => 'Khansela';

  @override
  String get team_goal_join_confirm => 'Kena sehlopheng';

  @override
  String team_details_error(Object error) {
    return 'Phoso: $error';
  }

  @override
  String get team_goal_not_found => 'Sepheo sa sehlopha ha se a fumanoa.';

  @override
  String get manager_inbox_approve => 'Amohela';

  @override
  String get manager_inbox_request_changes => 'Kopa diphetoho';

  @override
  String get manager_inbox_reject => 'Hana';

  @override
  String get manager_inbox_mark_all_as_read => 'Marka tsohle di badilwe';

  @override
  String get manager_inbox_view_goal => 'Sheba sepheo';

  @override
  String get manager_inbox_view_badges => 'Sheba dibetji';

  @override
  String get manager_inbox_all_priorities => 'Dibakeng tsohle tsa bohlokwa';

  @override
  String get manager_review_nudge => 'Kgothatsa';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Teboho';

  @override
  String get manager_review_activity => 'Mosebetsi';

  @override
  String get manager_review_send => 'Romela';

  @override
  String get manager_review_schedule => 'Beakanya nako';

  @override
  String get manager_review_send_kudos => 'Romela teboho';

  @override
  String get manager_review_close => 'Koala';

  @override
  String get manager_review_check_authentication => 'Hlahloba netefatso';

  @override
  String get season_management_title => 'Taolo ya sehla';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Laola $seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Atolosa sehla';

  @override
  String get season_management_view_celebration => 'Sheba mokete';

  @override
  String get season_challenge_title => 'Tshitiso ya sehla';

  @override
  String get team_challenges_create_season => 'Theha sehla';

  @override
  String get team_challenges_view_details => 'Sheba lintlha';

  @override
  String get team_challenges_manage => 'Laola';

  @override
  String get team_challenges_celebration => 'Mokete';

  @override
  String get team_challenges_paused_only => 'Tse emisitsweng feela';

  @override
  String get season_details_not_found => 'Sehla ha sea fumaneha';

  @override
  String get season_details_complete_season => 'Qeta sehla';

  @override
  String get season_details_extend_season => 'Atolosa sehla';

  @override
  String get season_details_celebrate => 'Keteka';

  @override
  String get season_details_recompute => 'Bala hape';

  @override
  String get season_details_delete_season => 'Phumula sehla';

  @override
  String get season_details_force_complete_title =>
      'Na o batla ho qeta sehla ka qobello?';

  @override
  String get season_details_force_complete_confirm => 'Qeta ka qobello';

  @override
  String get season_details_complete_title => 'Na o batla ho qeta sehla?';

  @override
  String get season_details_complete_confirm => 'Qeta';

  @override
  String get season_details_delete_title => 'Na o batla ho phumula sehla?';

  @override
  String get season_details_delete_confirm => 'Phumula';

  @override
  String get season_goal_completion_title => 'Qeta sepheo sa sehla';

  @override
  String get season_goal_completion_go_back => 'Kgutlela morao';

  @override
  String get season_celebration_share => 'Arolelana mokete';

  @override
  String get season_celebration_create_new => 'Theha sehla se setjha';

  @override
  String get season_celebration_shared_success =>
      'Mokete o arolelane ka katleho!';

  @override
  String get employee_season_join => 'Kena sehleng';

  @override
  String get employee_season_view_details => 'Sheba lintlha';

  @override
  String get employee_season_complete_goals => 'Qeta dikgomo';

  @override
  String get employee_season_update => 'Ntjhafatsa';

  @override
  String get employee_season_view_celebration => 'Sheba mokete';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'O kene ka katleho ho \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Phoso ha o kena sehleng: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'Ha ho dikgomo tsa sehla tsa \"$seasonTitle\" bakeng sa jwale.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Phoso ha ho bulwa lintlha tsa sepheo: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'E rometswe hore e amohelwe ke mookamedi';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Phoso ha ho romelwa tumello: $error';
  }

  @override
  String get goal_delete_title => 'Phumula sepheo';

  @override
  String get goal_deleted => 'Sepheo se phumutswe';

  @override
  String goal_delete_error(Object error) {
    return 'Phoso ha ho phumulwa sepheo: $error';
  }

  @override
  String get goal_start_success => 'Sepheo se qalile! O fumane maponto a 20 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Phoso ha ho qalwa sepheo: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Ka kopo qala sepheo pele o se qeta.';

  @override
  String get goal_complete_require_100 => 'Beha tswelopele ho 100% ho qeta.';

  @override
  String get goal_complete_success =>
      'Sepheo se qetilwe! O fumane maponto a 100 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Phoso ha ho qetwa sepheo: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Tswelopele e ntjhafaditswe ho $progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Phoso ha ho ntjhafatswa tswelopele: $error';
  }

  @override
  String get goal_set_to_100 => 'Beha ho 100%';

  @override
  String get goal_submit_for_approval_title => 'Romela bakeng sa tumello';

  @override
  String get goal_add_milestone => 'Eketsa milestone';

  @override
  String get goal_milestone_requires_sign_in =>
      'O lokela ho kena (sign in) ho laola di-milestone.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Dikgomo tse qetilweng ha di sa amohela di-milestone tse ntjha.';

  @override
  String get goal_milestone_title_required => 'Sehlooho sea hlokahala.';

  @override
  String get goal_milestone_due_date_required =>
      'Kgetha letsatsi la ho qetela.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Phoso ha ho bolokwa milestone: $error';
  }

  @override
  String get goal_milestone_deadline_hint =>
      'Tobetsa ho kgetha letsatsi la ho qetela';

  @override
  String get goal_milestone_change => 'Fetola';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'E markilwe jwalo ka $status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Phoso ha ho ntjhafatswa milestone: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Phumula milestone';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Na o batla ho tlosa milestone ena sepheong?';

  @override
  String get goal_milestone_deleted => 'Milestone e phumutswe.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Phoso ha ho phumulwa milestone: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Hlophisa lintlha';

  @override
  String get goal_milestone_mark_not_started => 'Marka hore ha e eso qale';

  @override
  String get goal_milestone_mark_in_progress => 'Marka hore e tswela pele';

  @override
  String get goal_milestone_mark_blocked => 'Marka hore e thibetswe';

  @override
  String get goal_milestone_mark_completed => 'Marka hore e qetilwe';

  @override
  String get manager_team_workspace_create_team_goal =>
      'Theha sepheo sa sehlopha';

  @override
  String get manager_team_workspace_view_details => 'Sheba lintlha';

  @override
  String get manager_team_workspace_manage_team => 'Laola sehlopha';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Theha sepheo sa sehlopha';

  @override
  String get database_test_title => 'Teko ya database';

  @override
  String get database_test_add_goal => 'Eketsa sepheo';

  @override
  String get database_test_add_sample_goals => 'Eketsa mehlala ya dikgomo';

  @override
  String get employee_profile_detail_send_nudge => 'Romela kgothatso';

  @override
  String get employee_profile_detail_schedule_meeting => 'Beakanya kopano';

  @override
  String get employee_profile_detail_give_recognition => 'Neha tlotla';

  @override
  String get employee_profile_detail_assign_goal => 'abela sepheo';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Mosebetsi o tla etswa mona hamorao';

  @override
  String get my_goal_workspace_suggest => 'Sisinyetsa';

  @override
  String get my_goal_workspace_generate => 'Etsa';

  @override
  String get my_goal_workspace_enter_goal_title =>
      'Ka kopo kenya sehlooho sa sepheo';

  @override
  String get my_goal_workspace_select_target_date =>
      'Ka kopo kgetha letsatsi leo o lebellang lona';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Phoso ha ho thehwa sepheo: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Theha sepheo';

  @override
  String get team_chats_edit_message => 'Hlophisa molaetsa';

  @override
  String get team_chats_delete_message_title => 'Phumula molaetsa?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'Ketso ena e ke ke ya kgutlisetswa morao.';

  @override
  String get gamification_title => 'Gamification';

  @override
  String get gamification_content => 'Dikahare tsa skrine sa Gamification';

  @override
  String get my_pdp_ok => 'Ho lokile';

  @override
  String get my_pdp_upload_file => 'Kenya faele (PDF/Word/Seterata)';

  @override
  String get my_pdp_save_note_link => 'Boloka ntlha/sekahare';

  @override
  String get my_pdp_change_evidence => 'Fetola bopaki';

  @override
  String get my_pdp_go_to_settings => 'Eya ho Di-setting';

  @override
  String get my_pdp_add_session => '+1 session';

  @override
  String get my_pdp_module_complete => 'Module e qetilwe';

  @override
  String get role_access_restricted_title => 'Ho kena ho thibetswe';

  @override
  String role_access_restricted_body(Object role) {
    return 'Karolo ya hao ($role) ha e na tulo leqepheng lena.';
  }

  @override
  String get role_go_to_my_portal => 'Eya portal ya ka';

  @override
  String get evidence_sign_in_required => 'Ka kopo kena ho bona bopaki ba hao.';

  @override
  String get evidence_sort_by_date => 'Hlophisa ka letsatsi';

  @override
  String get evidence_sort_by_title => 'Hlophisa ka sehlooho';

  @override
  String get evidence_no_evidence_found => 'Ha ho bopaki bo fumanweng.';

  @override
  String get evidence_dialog_title => 'Bopaki';

  @override
  String get employee_profile_remove_photo => 'Tlosa foto';

  @override
  String get employee_profile_login_required_remove_photo =>
      'O lokela ho kena ho tlosa foto ya hao.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Phoso ha ho tloswa foto: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'O lokela ho kena ho kenya foto.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Phoso ha ho kenngwa foto: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'O lokela ho kena ho boloka profaele ya hao.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Phoso ha ho bolokwa profaele: $error';
  }

  @override
  String get employee_drawer_exit => 'Tsoa';

  @override
  String get nav_dashboard => 'Desheboto';

  @override
  String get nav_goal_workspace => 'Sebaka sa mesebetsi ya sepheo';

  @override
  String get nav_my_profile => 'Profaele ya ka';

  @override
  String get nav_my_pdp => 'MyPdp';

  @override
  String get nav_progress_visuals => 'Diponahatso tsa tswelopele';

  @override
  String get nav_alerts_nudges => 'Ditsiboso & Dikgothatso';

  @override
  String get nav_badges_points => 'Dibejana & Dintlha';

  @override
  String get nav_season_challenges => 'Diphephetso tsa sehla';

  @override
  String get nav_leaderboard => 'Lenane la ba etellang pele';

  @override
  String get nav_repository_audit => 'Polokelo & Tlhahlobo';

  @override
  String get nav_settings_privacy => 'Diseting & Lekunutu';

  @override
  String get nav_team_challenges => 'Diphephetso tsa sehlopha';

  @override
  String get nav_team_alerts_nudges => 'Ditsiboso tsa sehlopha & Dikgothatso';

  @override
  String get nav_manager_inbox => 'Lebokose la melaetsa';

  @override
  String get nav_review_team => 'Sheba sehlopha';

  @override
  String get nav_admin_dashboard => 'Desheboto ya molaodi';

  @override
  String get nav_user_management => 'Taolo ya basebedisi';

  @override
  String get nav_analytics => 'Dihlahlobo';

  @override
  String get nav_system_settings => 'Diseting tsa tsamaiso';

  @override
  String get nav_security => 'Tshireletso';

  @override
  String get nav_backup_restore => 'Bekapo & Ho kgutlisa';

  @override
  String get employee_portal_title => 'Portale ya mosebedi';

  @override
  String get progress_visuals_error_loading_user_data =>
      'Phoso ha ho jariswa data ya mosebedisi';

  @override
  String get progress_visuals_all_departments => 'Dikgaolo tsohle';

  @override
  String get progress_visuals_send_nudge => 'Romela kgothatso';

  @override
  String get progress_visuals_meet => 'Kopano';

  @override
  String get progress_visuals_view_details => 'Sheba lintlha';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Kgothatso e rometswe ho $employeeName';
  }

  @override
  String get progress_visuals_debug_information =>
      'Boitsebiso ba ho lokisa diphoso';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Phoso ya debug: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'Dikakanyo tsa AI';

  @override
  String get alerts_nudges_ai_assistant => 'Mothusi wa AI';

  @override
  String get alerts_nudges_refresh => 'Nchafatsa';

  @override
  String get alerts_nudges_create_first_goal => 'Theha sepheo sa hao sa pele';

  @override
  String get alerts_nudges_dismiss => 'Tlohela';

  @override
  String get alerts_nudges_copy => 'Kopitsa';

  @override
  String get alerts_nudges_edit => 'Hlophisa';

  @override
  String get manager_alerts_add_reschedule_note =>
      'Eketsa tlhaloso ya ho rulaganya hape';

  @override
  String get manager_alerts_skip => 'Tlohela';

  @override
  String get manager_alerts_save => 'Boloka';

  @override
  String get manager_alerts_reject_goal => 'Hana sepheo';

  @override
  String get manager_alerts_ai_team_insights => 'Dikakanyo tsa sehlopha tsa AI';

  @override
  String get manager_alerts_all_priorities => 'Dibakeng tsohle tsa bohlokwa';

  @override
  String get manager_alerts_review_goal => 'Hlahloba sepheo';

  @override
  String get manager_alerts_reschedule => 'Rulaganya nako hape';

  @override
  String get manager_alerts_extend_deadline => 'Atolosa letsatsi la ho qetela';

  @override
  String get manager_alerts_pause_goal => 'Emisa sepheo ka nakwana';

  @override
  String get manager_alerts_mark_burnout => 'Marka ho kgaleheloa ke matla';

  @override
  String get manager_alerts_select_goal_hint => 'Kgetha sepheo';

  @override
  String get manager_alerts_send_bulk_nudge => 'Romela dikgothatso tse ngata';

  @override
  String get manager_alerts_send_to_all => 'Romela bohle';

  @override
  String get notifications_bell_ok => 'Ho lokile';

  @override
  String get landing_app_title => 'Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}
