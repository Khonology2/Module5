// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tswana (`tn`).
class AppLocalizationsTn extends AppLocalizations {
  AppLocalizationsTn([String locale = 'tn']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Puo e ntšhwafaditswe';

  @override
  String get ok => 'Go siame';

  @override
  String get cancel => 'Khansela';

  @override
  String get close => 'Tswala';

  @override
  String get retry => 'Leka gape';

  @override
  String get save => 'Boloka';

  @override
  String get delete => 'Phimola';

  @override
  String get create => 'Bopa';

  @override
  String get submit => 'Romela';

  @override
  String get view => 'Leba';

  @override
  String get details => 'Dintlha';

  @override
  String get settings_go_to => 'Tsamaela mo Diiseting';

  @override
  String get sign_out => 'Tswa';

  @override
  String get delete_account => 'Phimola akhaonto';

  @override
  String get export_my_data => 'Romela data ya me';

  @override
  String get send_password_reset_email =>
      'Romela imeile ya go beakanya paswete sesha';

  @override
  String get language_english => 'Seesimane';

  @override
  String get language_spanish => 'Sespain';

  @override
  String get language_french => 'Sefora';

  @override
  String get language_german => 'Sejeremane';

  @override
  String get time_15_minutes => 'metsotso e 15';

  @override
  String get time_30_minutes => 'metsotso e 30';

  @override
  String get time_60_minutes => 'ura e 1';

  @override
  String get time_120_minutes => 'diura di 2';

  @override
  String get status_all => 'Maemo otlhe';

  @override
  String get status_verified => 'Netefaditswe';

  @override
  String get status_pending => 'E emetse';

  @override
  String get status_rejected => 'Gannwe morago';

  @override
  String get audit_export_csv => 'Romela jaaka CSV';

  @override
  String get audit_export_pdf => 'Romela jaaka PDF';

  @override
  String get audit_submit_for_audit => 'Romela go tlhahlobo';

  @override
  String get audit_no_timeline_events_yet =>
      'Ga go ditiragalo mo lenaaneng la nako ga jaana';

  @override
  String get dashboard_refresh_data => 'Ntšhwafatsa data';

  @override
  String get dashboard_recent_activity => 'Ditiro tsa bosheng';

  @override
  String get dashboard_quick_actions => 'Ditiro tse di potlakileng';

  @override
  String get dashboard_upcoming_goals => 'Maikaelelo a a tlang';

  @override
  String get dashboard_add_goal => 'Tsenya maikaelelo';

  @override
  String get dashboard_awaiting_manager_approval =>
      'E emetse tetla ya molaodi.';

  @override
  String get employee_create_first_goal => 'Bopa maikaelelo a gago a ntlha';

  @override
  String get manager_team_kpis => 'KPI tsa sehlopha';

  @override
  String get manager_team_health => 'Botsogo jwa sehlopha';

  @override
  String get manager_activity_summary => 'Kakaretso ya ditiro';

  @override
  String get manager_top_performers => 'Batho ba ba dirang sentle thata';

  @override
  String get manager_no_performers_yet =>
      'Ga go ba dirang sentle thata ga jaana';

  @override
  String get manager_quick_actions => 'Ditiro tse di potlakileng';

  @override
  String get manager_complete_season => 'Feleletsa sešene';

  @override
  String manager_team_size(Object teamSize) {
    return 'Bogolo jwa sehlopha: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Tsena mo maikaelelong a sehlopha';

  @override
  String get team_goal_join_cancel => 'Khansela';

  @override
  String get team_goal_join_confirm => 'Tsena mo sehlopheng';

  @override
  String team_details_error(Object error) {
    return 'Phoso: $error';
  }

  @override
  String get team_goal_not_found => 'Maikaelelo a sehlopha ga a a bonwa.';

  @override
  String get manager_inbox_approve => 'Amohela';

  @override
  String get manager_inbox_request_changes => 'Kopa diphetogo';

  @override
  String get manager_inbox_reject => 'Gana';

  @override
  String get manager_inbox_mark_all_as_read => 'Tshwaya tsotlhe di buisitswe';

  @override
  String get manager_inbox_view_goal => 'Leba maikaelelo';

  @override
  String get manager_inbox_view_badges => 'Leba dibejê';

  @override
  String get manager_inbox_all_priorities => 'Dintlha tsotlhe tsa botlhokwa';

  @override
  String get manager_review_nudge => 'Kgothatsa';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Tebogo';

  @override
  String get manager_review_activity => 'Tiro';

  @override
  String get manager_review_send => 'Romela';

  @override
  String get manager_review_schedule => 'Beakanya nako';

  @override
  String get manager_review_send_kudos => 'Romela tebogo';

  @override
  String get manager_review_close => 'Tswala';

  @override
  String get manager_review_check_authentication => 'Tlhola netefatso';

  @override
  String get season_management_title => 'Taolo ya sešene';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Laola $seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Oketsa sešene';

  @override
  String get season_management_view_celebration => 'Leba moletlo';

  @override
  String get season_challenge_title => 'Tshwetso ya sešene';

  @override
  String get team_challenges_create_season => 'Bopa sešene';

  @override
  String get team_challenges_view_details => 'Leba dintlha';

  @override
  String get team_challenges_manage => 'Laola';

  @override
  String get team_challenges_celebration => 'Moletlo';

  @override
  String get team_challenges_paused_only => 'Tseo di emisitsweng fela';

  @override
  String get season_details_not_found => 'Sešene ga se a bonwa';

  @override
  String get season_details_complete_season => 'Feleletsa sešene';

  @override
  String get season_details_extend_season => 'Oketsa sešene';

  @override
  String get season_details_celebrate => 'Keteka';

  @override
  String get season_details_recompute => 'Balela gape';

  @override
  String get season_details_delete_season => 'Phimola sešene';

  @override
  String get season_details_force_complete_title =>
      'O batla go feleletsa sešene ka kgatelelo?';

  @override
  String get season_details_force_complete_confirm => 'Feleletsa ka kgatelelo';

  @override
  String get season_details_complete_title => 'O batla go feleletsa sešene?';

  @override
  String get season_details_complete_confirm => 'Feleletsa';

  @override
  String get season_details_delete_title => 'O batla go phimola sešene?';

  @override
  String get season_details_delete_confirm => 'Phimola';

  @override
  String get season_goal_completion_title => 'Feleletsa maikaelelo a sešene';

  @override
  String get season_goal_completion_go_back => 'Boela morago';

  @override
  String get season_celebration_share => 'Abelana moletlo';

  @override
  String get season_celebration_create_new => 'Bopa sešene se sesha';

  @override
  String get season_celebration_shared_success =>
      'Moletlo o abetswe ba bangwe!';

  @override
  String get employee_season_join => 'Tsena mo sešeneng';

  @override
  String get employee_season_view_details => 'Leba dintlha';

  @override
  String get employee_season_complete_goals => 'Feleletsa maikaelelo';

  @override
  String get employee_season_update => 'Ntšhwafatsa';

  @override
  String get employee_season_view_celebration => 'Leba moletlo';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'O tsentse sentle mo \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Phoso fa go tseneng mo sešeneng: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'Ga gona maikaelelo a sešene a \"$seasonTitle\" ga jaana.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Phoso fa go buleng dintlha tsa maikaelelo: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'E rometswe go amogelwa ke molaodi';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Phoso fa go romeleng go amogelwa: $error';
  }

  @override
  String get goal_delete_title => 'Phimola maikaelelo';

  @override
  String get goal_deleted => 'Maikaelelo a phimotswe';

  @override
  String goal_delete_error(Object error) {
    return 'Phoso fa go phimoleng maikaelelo: $error';
  }

  @override
  String get goal_start_success =>
      'Maikaelelo a simolotswe! O bone dikala tše 20 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Phoso fa go simololang maikaelelo: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Tsweetswee simolola maikaelelo pele o a feleletsa.';

  @override
  String get goal_complete_require_100 =>
      'Bea tswelopele go 100% go feleletsa.';

  @override
  String get goal_complete_success =>
      'Maikaelelo a feleleditswe! O bone dikala tše 100 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Phoso fa go feleleditsweng maikaelelo: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Tswelopele e ntšhwafaditswe go $progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Phoso fa go ntšhwafatseng tswelopele: $error';
  }

  @override
  String get goal_set_to_100 => 'Bea go 100%';

  @override
  String get goal_submit_for_approval_title => 'Romela go amogelwa';

  @override
  String get goal_add_milestone => 'Tsenya ntlha ya boemo (milestone)';

  @override
  String get goal_milestone_requires_sign_in =>
      'O tshwanetse go tsena (sign in) go laola dimilestone.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Maikaelelo a a feleleditsweng ga a amogele dimilestone tse dintšha.';

  @override
  String get goal_milestone_title_required => 'Setlhogo se a tlhokega.';

  @override
  String get goal_milestone_due_date_required => 'Kgetha letlha la go fetsa.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Phoso fa go bolokang milestone: $error';
  }

  @override
  String get goal_milestone_deadline_hint =>
      'Tobetsa go kgetha letlha la bokgwetha';

  @override
  String get goal_milestone_change => 'Fetola';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'E tshwayilwe jaaka $status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Phoso fa go ntšhwafatseng milestone: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Phimola milestone';

  @override
  String get goal_milestone_delete_confirm_text =>
      'A o batla go tlosa milestone e mo maikaelelong?';

  @override
  String get goal_milestone_deleted => 'Milestone e phimotswe.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Phoso fa go phimoleng milestone: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Rulaganya dintlha';

  @override
  String get goal_milestone_mark_not_started => 'Tshwaya jaaka ga e a simologa';

  @override
  String get goal_milestone_mark_in_progress => 'Tshwaya jaaka e tswelela';

  @override
  String get goal_milestone_mark_blocked => 'Tshwaya jaaka e thibetswe';

  @override
  String get goal_milestone_mark_completed => 'Tshwaya jaaka e feleleditswe';

  @override
  String get manager_team_workspace_create_team_goal =>
      'Bopa maikaelelo a sehlopha';

  @override
  String get manager_team_workspace_view_details => 'Leba dintlha';

  @override
  String get manager_team_workspace_manage_team => 'Laola sehlopha';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Bopa maikaelelo a sehlopha';

  @override
  String get database_test_title => 'Teko ya database';

  @override
  String get database_test_add_goal => 'Tsaya maikaelelo';

  @override
  String get database_test_add_sample_goals => 'Tsaya mehlala ya maikaelelo';

  @override
  String get employee_profile_detail_send_nudge => 'Romela kgothatso';

  @override
  String get employee_profile_detail_schedule_meeting => 'Beakanya kopano';

  @override
  String get employee_profile_detail_give_recognition => 'Neela tlotlo';

  @override
  String get employee_profile_detail_assign_goal => 'Abela maikaelelo';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Mosebetsi o tla dirwa fano mo nakong e e tlang';

  @override
  String get my_goal_workspace_suggest => 'Tshwaya (Suggest)';

  @override
  String get my_goal_workspace_generate => 'Tlhama';

  @override
  String get my_goal_workspace_enter_goal_title =>
      'Tsweetswee tsenya setlhogo sa maikaelelo';

  @override
  String get my_goal_workspace_select_target_date =>
      'Tsweetswee kgetha letlha la go fitlhelela';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Phoso fa go bopeng maikaelelo: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Bopa maikaelelo';

  @override
  String get team_chats_edit_message => 'Rulaganya molaetsa';

  @override
  String get team_chats_delete_message_title => 'Phimola molaetsa?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'Tiro eno ga e kgonege go boelwa morago.';

  @override
  String get gamification_title => 'Gamification';

  @override
  String get gamification_content => 'Dikgathego tsa skrini sa Gamification';

  @override
  String get my_pdp_ok => 'Go siame';

  @override
  String get my_pdp_upload_file => 'Tsenya faele (PDF/Word/Seterata)';

  @override
  String get my_pdp_save_note_link => 'Boloka ntlha/sekamano';

  @override
  String get my_pdp_change_evidence => 'Fetola bosupi';

  @override
  String get my_pdp_go_to_settings => 'Tsamaela mo Diiseting';

  @override
  String get my_pdp_add_session => '+1 setšhene';

  @override
  String get my_pdp_module_complete => 'Mojulo o feleleditswe';

  @override
  String get role_access_restricted_title => 'Go tsena go thibetswe';

  @override
  String role_access_restricted_body(Object role) {
    return 'Maikarabelo a gago ($role) ga a letle go tsena mo tsebeng eno.';
  }

  @override
  String get role_go_to_my_portal => 'Tsamaela mo portal ya me';

  @override
  String get evidence_sign_in_required =>
      'Tsweetswee tsena go bona bosupi jwa gago.';

  @override
  String get evidence_sort_by_date => 'Rulaganya ka letlha';

  @override
  String get evidence_sort_by_title => 'Rulaganya ka setlhogo';

  @override
  String get evidence_no_evidence_found => 'Ga go a bonwa bosupi.';

  @override
  String get evidence_dialog_title => 'Bosupi';

  @override
  String get employee_profile_remove_photo => 'Tlosa setshwantsho';

  @override
  String get employee_profile_login_required_remove_photo =>
      'O tshwanetse go tsena go tlosa setshwantsho sa gago.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Phoso fa go tloseng setshwantsho: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'O tshwanetse go tsena go tsenya setshwantsho.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Phoso fa go tsenyeng setshwantsho: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'O tshwanetse go tsena go boloka profaele ya gago.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Phoso fa go bolokeng profaele: $error';
  }

  @override
  String get employee_drawer_exit => 'Tswa';

  @override
  String get progress_visuals_error_loading_user_data =>
      'Phoso fa go laaiseng data ya modirisi';

  @override
  String get progress_visuals_all_departments => 'Dikgaolo tsotlhe';

  @override
  String get progress_visuals_send_nudge => 'Romela kgothatso';

  @override
  String get progress_visuals_meet => 'Kopano';

  @override
  String get progress_visuals_view_details => 'Leba dintlha';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Kgothatso e rometswe go $employeeName';
  }

  @override
  String get progress_visuals_debug_information =>
      'Tshedimosetso ya go lokisa diphoso';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Phoso ya debug: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'Dikakanyo tsa AI';

  @override
  String get alerts_nudges_ai_assistant => 'Mothusi wa AI';

  @override
  String get alerts_nudges_refresh => 'Ntšhwafatsa';

  @override
  String get alerts_nudges_create_first_goal =>
      'Bopa maikaelelo a gago a ntlha';

  @override
  String get alerts_nudges_dismiss => 'Tlogela';

  @override
  String get alerts_nudges_copy => 'Kopa';

  @override
  String get alerts_nudges_edit => 'Rulaganya';

  @override
  String get manager_alerts_add_reschedule_note =>
      'Tsenya ntlha ya go beakanya sesha';

  @override
  String get manager_alerts_skip => 'Tlola';

  @override
  String get manager_alerts_save => 'Boloka';

  @override
  String get manager_alerts_reject_goal => 'Gana maikaelelo';

  @override
  String get manager_alerts_ai_team_insights => 'Dikakanyo tsa sehlopha tsa AI';

  @override
  String get manager_alerts_all_priorities => 'Dintlha tsotlhe tsa botlhokwa';

  @override
  String get manager_alerts_review_goal => 'Sekaseka maikaelelo';

  @override
  String get manager_alerts_reschedule => 'Beakanya nako sesha';

  @override
  String get manager_alerts_extend_deadline => 'Oketsa letlha la bokgwetha';

  @override
  String get manager_alerts_pause_goal => 'Emisa maikaelelo ka nakwana';

  @override
  String get manager_alerts_mark_burnout => 'Tshwaya mokgathalo o feteletseng';

  @override
  String get manager_alerts_select_goal_hint => 'Kgetha maikaelelo';

  @override
  String get manager_alerts_send_bulk_nudge => 'Romela dikgothatso tse dintsi';

  @override
  String get manager_alerts_send_to_all => 'Romela botlhe';

  @override
  String get notifications_bell_ok => 'Go siame';

  @override
  String get landing_app_title => 'Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}
