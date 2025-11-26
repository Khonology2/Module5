// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swati (`ss`).
class AppLocalizationsSs extends AppLocalizations {
  AppLocalizationsSs([String locale = 'ss']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Lulwimi selubuyekeziwe';

  @override
  String get ok => 'Kulungile';

  @override
  String get cancel => 'Khansela';

  @override
  String get close => 'Vala';

  @override
  String get retry => 'Phindza uzame';

  @override
  String get save => 'Londvolota';

  @override
  String get delete => 'Cisha';

  @override
  String get create => 'Dala';

  @override
  String get submit => 'Letfulela';

  @override
  String get view => 'Buka';

  @override
  String get details => 'Imininingwane';

  @override
  String get settings_go_to => 'Yana ku-Settings';

  @override
  String get sign_out => 'Phuma';

  @override
  String get delete_account => 'Cisha i-akhawunti';

  @override
  String get export_my_data => 'Khipha imininingwane yami';

  @override
  String get send_password_reset_email =>
      'Tfumela i-imeyili yekubuyisela iphasiwedi';

  @override
  String get language_english => 'Sengisi';

  @override
  String get language_spanish => 'Spanish';

  @override
  String get language_french => 'French';

  @override
  String get language_german => 'German';

  @override
  String get time_15_minutes => 'emaminitsi langu-15';

  @override
  String get time_30_minutes => 'emaminitsi langu-30';

  @override
  String get time_60_minutes => 'lihora linye';

  @override
  String get time_120_minutes => 'emahora lamabili';

  @override
  String get status_all => 'Tonke timo';

  @override
  String get status_verified => 'Iqinisekisiwe';

  @override
  String get status_pending => 'Iyalindzela';

  @override
  String get status_rejected => 'Yenqatshiwe';

  @override
  String get audit_export_csv => 'Khipha njenge-CSV';

  @override
  String get audit_export_pdf => 'Khipha njenge-PDF';

  @override
  String get audit_submit_for_audit => 'Letfulela ekuhlolweni';

  @override
  String get audit_no_timeline_events_yet => 'Asikaboni ticimbi esikhatsini';

  @override
  String get dashboard_refresh_data => 'Vuselela idatha';

  @override
  String get dashboard_recent_activity => 'Imisebenti yakamuva';

  @override
  String get dashboard_quick_actions => 'Tinyatselo letisheshako';

  @override
  String get dashboard_upcoming_goals => 'Tinhloso letitako';

  @override
  String get dashboard_add_goal => 'Ngeta inhloso';

  @override
  String get dashboard_awaiting_manager_approval =>
      'Ilindze kuvunywa ngumphatsi.';

  @override
  String get employee_create_first_goal => 'Dala inhloso yakho yekucala';

  @override
  String get manager_team_kpis => 'Tinkomba (KPI) temtimba';

  @override
  String get manager_team_health => 'Inkhulakahle yemtimba';

  @override
  String get manager_activity_summary => 'Sitfombe semisebenti';

  @override
  String get manager_top_performers => 'Benti bemphumelelo labaphezulu';

  @override
  String get manager_no_performers_yet => 'Kute benti bemphumelelo njenganyalo';

  @override
  String get manager_quick_actions => 'Tinyatselo letisheshako';

  @override
  String get manager_complete_season => 'Gcina isizini';

  @override
  String manager_team_size(Object teamSize) {
    return 'Inani lemtimba: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Joyina inhloso yemtimba';

  @override
  String get team_goal_join_cancel => 'Khansela';

  @override
  String get team_goal_join_confirm => 'Joyina umtimba';

  @override
  String team_details_error(Object error) {
    return 'Liphutsa: $error';
  }

  @override
  String get team_goal_not_found => 'Inhloso yemtimba ayikatfolakali.';

  @override
  String get manager_inbox_approve => 'Vuma';

  @override
  String get manager_inbox_request_changes => 'Cela kuguqulwa';

  @override
  String get manager_inbox_reject => 'Yenqaba';

  @override
  String get manager_inbox_mark_all_as_read => 'Maka konkhe kufundziwe';

  @override
  String get manager_inbox_view_goal => 'Buka inhloso';

  @override
  String get manager_inbox_view_badges => 'Buka tibheji';

  @override
  String get manager_inbox_all_priorities => 'Tonke tinhloso tekubaluleka';

  @override
  String get manager_review_nudge => 'Khutsata';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Kudvumisa';

  @override
  String get manager_review_activity => 'Umsebenti';

  @override
  String get manager_review_send => 'Tfumela';

  @override
  String get manager_review_schedule => 'Hlela sikhatsi';

  @override
  String get manager_review_send_kudos => 'Tfumela kudvumisa';

  @override
  String get manager_review_close => 'Vala';

  @override
  String get manager_review_check_authentication => 'Hlola kugunyatwa';

  @override
  String get season_management_title => 'Kuphatfwa kwesizini';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Phatsa $seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Yandisa isizini';

  @override
  String get season_management_view_celebration => 'Buka kugubha';

  @override
  String get season_challenge_title => 'Inselelo yesizini';

  @override
  String get team_challenges_create_season => 'Dala isizini';

  @override
  String get team_challenges_view_details => 'Buka imininingwane';

  @override
  String get team_challenges_manage => 'Phatsa';

  @override
  String get team_challenges_celebration => 'Kugubha';

  @override
  String get team_challenges_paused_only => 'Letimisiwe kuphela';

  @override
  String get season_details_not_found => 'Isizini ayikatfolakali';

  @override
  String get season_details_complete_season => 'Gcina isizini';

  @override
  String get season_details_extend_season => 'Yandisa isizini';

  @override
  String get season_details_celebrate => 'Gubha';

  @override
  String get season_details_recompute => 'Balela kabusha';

  @override
  String get season_details_delete_season => 'Cisha isizini';

  @override
  String get season_details_force_complete_title =>
      'Ugcine isizini ngekucindziteleka?';

  @override
  String get season_details_force_complete_confirm => 'Gcina ngekucindziteleka';

  @override
  String get season_details_complete_title => 'Ugcine isizini?';

  @override
  String get season_details_complete_confirm => 'Gcina';

  @override
  String get season_details_delete_title => 'Ucisha isizini?';

  @override
  String get season_details_delete_confirm => 'Cisha';

  @override
  String get season_goal_completion_title => 'Gcina inhloso yesizini';

  @override
  String get season_goal_completion_go_back => 'Buyela emuva';

  @override
  String get season_celebration_share => 'Yabelana ngekugubha';

  @override
  String get season_celebration_create_new => 'Dala isizini lensha';

  @override
  String get season_celebration_shared_success => 'Kugubha sekubelwe ngako!';

  @override
  String get employee_season_join => 'Joyina isizini';

  @override
  String get employee_season_view_details => 'Buka imininingwane';

  @override
  String get employee_season_complete_goals => 'Gcina tinhloso';

  @override
  String get employee_season_update => 'Buyeketa';

  @override
  String get employee_season_view_celebration => 'Buka kugubha';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'Ujoyine ngempumelelo \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Liphutsa ekuyoyineni isizini: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'Kute tinhloso tesizini ta \"$seasonTitle\" njengamanje.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Liphutsa ekokuvuleni imininingwane yenhloso: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'Iletfulelwe kuvunywa ngumphatsi';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Liphutsa ekutfumeleleni kuvunywa: $error';
  }

  @override
  String get goal_delete_title => 'Cisha inhloso';

  @override
  String get goal_deleted => 'Inhloso icishiwe';

  @override
  String goal_delete_error(Object error) {
    return 'Liphutsa ekucisheni inhloso: $error';
  }

  @override
  String get goal_start_success =>
      'Inhloso isiqalile! Utfole emaphuzu langu-20 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Liphutsa ekuqaleni kwenhloso: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Sicela uqale inhloso ungakayigcini.';

  @override
  String get goal_complete_require_100 => 'Beka inqubekelo ku-100% kugcina.';

  @override
  String get goal_complete_success =>
      'Inhloso isetigcine! Utfole emaphuzu langu-100 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Liphutsa ekuyigcineni inhloso: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Inqubekela phambili ibuyeketiwe ku-$progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Liphutsa ekubuyeketenii inqubekela phambili: $error';
  }

  @override
  String get goal_set_to_100 => 'Beka ku-100%';

  @override
  String get goal_submit_for_approval_title => 'Letfulela kuvunywa';

  @override
  String get goal_add_milestone => 'Ngeta i-milestone';

  @override
  String get goal_milestone_requires_sign_in =>
      'Kumele ungene (sign in) ku phatsa ema-milestone.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Tinhloso letigcineko atisemukeli ema-milestone lamasha.';

  @override
  String get goal_milestone_title_required => 'Sihloko siyafuneka.';

  @override
  String get goal_milestone_due_date_required => 'Khetsa lilanga lekuphela.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Liphutsa ekulondvoloteni i-milestone: $error';
  }

  @override
  String get goal_milestone_deadline_hint =>
      'Cindzetela ukhetsa lilanga lekuphela';

  @override
  String get goal_milestone_change => 'Gucula';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'Imakwe njenge-$status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Liphutsa ekubuyeketenii i-milestone: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Cisha i-milestone';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Uyafuna kucisha le milestone kulesi sinhloso?';

  @override
  String get goal_milestone_deleted => 'I-milestone icishiwe.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Liphutsa ekucisheni i-milestone: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Hlela imininingwane';

  @override
  String get goal_milestone_mark_not_started => 'Maka njengalokungakasiqali';

  @override
  String get goal_milestone_mark_in_progress => 'Maka njengalokusese kuqhubeka';

  @override
  String get goal_milestone_mark_blocked => 'Maka njengalokuvinjwa';

  @override
  String get goal_milestone_mark_completed => 'Maka njengalokugcinekile';

  @override
  String get manager_team_workspace_create_team_goal => 'Dala inhloso yemtimba';

  @override
  String get manager_team_workspace_view_details => 'Buka imininingwane';

  @override
  String get manager_team_workspace_manage_team => 'Phatsa umtimba';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Dala inhloso yemtimba';

  @override
  String get database_test_title => 'Kuhlola i-database';

  @override
  String get database_test_add_goal => 'Ngeta inhloso';

  @override
  String get database_test_add_sample_goals => 'Ngeta tinhloso tesibonelo';

  @override
  String get employee_profile_detail_send_nudge => 'Tfumela khutsato';

  @override
  String get employee_profile_detail_schedule_meeting => 'Hlela umhlangano';

  @override
  String get employee_profile_detail_give_recognition => 'Nika kudvumisa';

  @override
  String get employee_profile_detail_assign_goal => 'abela inhloso';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Umsebenti utawulandzelwa lapha';

  @override
  String get my_goal_workspace_suggest => 'Phakamisa';

  @override
  String get my_goal_workspace_generate => 'Khiqiza';

  @override
  String get my_goal_workspace_enter_goal_title =>
      'Sicela ufake sihloko senhloso';

  @override
  String get my_goal_workspace_select_target_date =>
      'Sicela ukhetsa lilanga lekuhloswe ngalo';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Liphutsa ekudaleni inhloso: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Dala inhloso';

  @override
  String get team_chats_edit_message => 'Hlela umlayeto';

  @override
  String get team_chats_delete_message_title => 'Cisha umlayeto?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'Lelinyatselo alikwati kubuyiselwa emuva.';

  @override
  String get gamification_title => 'Gamification';

  @override
  String get gamification_content => 'Lokukhona esikrinini se-Gamification';

  @override
  String get my_pdp_ok => 'Kulungile';

  @override
  String get my_pdp_upload_file => 'Layisha ifayela (PDF/Word/Isithombe)';

  @override
  String get my_pdp_save_note_link => 'Londvolota inothi/likhonkhethi';

  @override
  String get my_pdp_change_evidence => 'Gucula bufakazi';

  @override
  String get my_pdp_go_to_settings => 'Yana ku-Settings';

  @override
  String get my_pdp_add_session => '+1 seshini';

  @override
  String get my_pdp_module_complete => 'Module seyigcinekile';

  @override
  String get role_access_restricted_title => 'Kungena kuvinjiwe';

  @override
  String role_access_restricted_body(Object role) {
    return 'Indzima yakho ($role) ayivunyelwe kulelipheji.';
  }

  @override
  String get role_go_to_my_portal => 'Yana ku-portal yami';

  @override
  String get evidence_sign_in_required =>
      'Sicela ungene kuze ubone bufakazi bakho.';

  @override
  String get evidence_sort_by_date => 'Hlela ngelilanga';

  @override
  String get evidence_sort_by_title => 'Hlela ngesihloko';

  @override
  String get evidence_no_evidence_found => 'Kute bufakazi lobutfolakale.';

  @override
  String get evidence_dialog_title => 'Bufakazi';

  @override
  String get employee_profile_remove_photo => 'Susa sitfombe';

  @override
  String get employee_profile_login_required_remove_photo =>
      'Kumele ungene kuze ususe sitfombe sakho.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Liphutsa ekususeni sitfombe: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'Kumele ungene kuze ulayishe sitfombe.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Liphutsa ekulayisheni sitfombe: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'Kumele ungene kuze ulondvolote iprofayili yakho.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Liphutsa ekulondvoloteni iprofayili: $error';
  }

  @override
  String get employee_drawer_exit => 'Phuma';

  @override
  String get progress_visuals_error_loading_user_data =>
      'Liphutsa ekulayisheni idatha yemsebenzisi';

  @override
  String get progress_visuals_all_departments => 'Tisebenti tonkhe';

  @override
  String get progress_visuals_send_nudge => 'Tfumela khutsato';

  @override
  String get progress_visuals_meet => 'Hlangana';

  @override
  String get progress_visuals_view_details => 'Buka imininingwane';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Khutsato itfunyelwe ku-$employeeName';
  }

  @override
  String get progress_visuals_debug_information =>
      'Imininingwane yekulungisa liphutsa';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Liphutsa le-debug: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'Imibono ye-AI';

  @override
  String get alerts_nudges_ai_assistant => 'Umsiti we-AI';

  @override
  String get alerts_nudges_refresh => 'Vuselela';

  @override
  String get alerts_nudges_create_first_goal => 'Dala inhloso yakho yekucala';

  @override
  String get alerts_nudges_dismiss => 'Cisha';

  @override
  String get alerts_nudges_copy => 'Kopisha';

  @override
  String get alerts_nudges_edit => 'Hlela';

  @override
  String get manager_alerts_add_reschedule_note =>
      'Ngeta inothi yekuhlela kabusha';

  @override
  String get manager_alerts_skip => 'Yekela';

  @override
  String get manager_alerts_save => 'Londvolota';

  @override
  String get manager_alerts_reject_goal => 'Yenqaba inhloso';

  @override
  String get manager_alerts_ai_team_insights => 'Imibono yemtimba ye-AI';

  @override
  String get manager_alerts_all_priorities => 'Tonke tifisho tekubaluleka';

  @override
  String get manager_alerts_review_goal => 'Bukeza inhloso';

  @override
  String get manager_alerts_reschedule => 'Hlela kabusha';

  @override
  String get manager_alerts_extend_deadline => 'Yandisa lilanga lekuphela';

  @override
  String get manager_alerts_pause_goal => 'Misa inhloso sikhatsi sincinane';

  @override
  String get manager_alerts_mark_burnout => 'Maka kudzinya';

  @override
  String get manager_alerts_select_goal_hint => 'Khetsa inhloso';

  @override
  String get manager_alerts_send_bulk_nudge =>
      'Tfumela tikhutsato letinyenti kanye';

  @override
  String get manager_alerts_send_to_all => 'Tfumela kubo bonkhe';

  @override
  String get notifications_bell_ok => 'Kulungile';

  @override
  String get landing_app_title => 'Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}
