// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for South Ndebele (`nr`).
class AppLocalizationsNr extends AppLocalizations {
  AppLocalizationsNr([String locale = 'nr']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Ilimi selivuselelwe';

  @override
  String get ok => 'Kulungile';

  @override
  String get cancel => 'Khansela';

  @override
  String get close => 'Vala';

  @override
  String get retry => 'Zama futhi';

  @override
  String get save => 'Gcina';

  @override
  String get delete => 'Cima';

  @override
  String get create => 'Dala';

  @override
  String get submit => 'Thumela';

  @override
  String get view => 'Bona';

  @override
  String get details => 'Imininingwane';

  @override
  String get settings_go_to => 'Iya Ezilungiseleleni';

  @override
  String get sign_out => 'Phuma';

  @override
  String get delete_account => 'Cima i-akhawunti';

  @override
  String get export_my_data => 'Khipha idatha yami';

  @override
  String get send_password_reset_email =>
      'Thumela i-imeyili yokubuyisela iphasiwedi';

  @override
  String get language_english => 'IsiNgisi';

  @override
  String get language_spanish => 'iSpanish';

  @override
  String get language_french => 'iFrench';

  @override
  String get language_german => 'iGerman';

  @override
  String get time_15_minutes => 'imizuzu eli-15';

  @override
  String get time_30_minutes => 'imizuzu engama-30';

  @override
  String get time_60_minutes => 'ihora elilodwa';

  @override
  String get time_120_minutes => 'amahora amabili';

  @override
  String get status_all => 'Zonke izimo';

  @override
  String get status_verified => 'Iqinisekisiwe';

  @override
  String get status_pending => 'Ilindile';

  @override
  String get status_rejected => 'Iyenqatshelwe';

  @override
  String get audit_export_csv => 'Khipha njenge-CSV';

  @override
  String get audit_export_pdf => 'Khipha njenge-PDF';

  @override
  String get audit_submit_for_audit => 'Thumela ukuze kuhlolwe';

  @override
  String get audit_no_timeline_events_yet =>
      'Akasabikho izehlakalo zesikhathi okwamanje';

  @override
  String get dashboard_refresh_data => 'Vuselela idatha';

  @override
  String get dashboard_recent_activity => 'Umsebenzi wakamuva';

  @override
  String get dashboard_quick_actions => 'Izenzo ezisheshayo';

  @override
  String get dashboard_upcoming_goals => 'Izinhloso ezizayo';

  @override
  String get dashboard_add_goal => 'Engeza inhloso';

  @override
  String get dashboard_awaiting_manager_approval =>
      'Ilindele ukugunyazwa ngumphathi.';

  @override
  String get employee_create_first_goal => 'Dala inhloso yakho yokuqala';

  @override
  String get manager_team_kpis => 'Ama-KPI eqembu';

  @override
  String get manager_team_health => 'Impilo yeqembu';

  @override
  String get manager_activity_summary => 'Isifinyezo somsebenzi';

  @override
  String get manager_top_performers => 'Abenza kahle kakhulu';

  @override
  String get manager_no_performers_yet => 'Akasabikho abenza kahle okwamanje';

  @override
  String get manager_quick_actions => 'Izenzo ezisheshayo';

  @override
  String get manager_complete_season => 'Qeda isizini';

  @override
  String manager_team_size(Object teamSize) {
    return 'Usayizi weqembu: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Joyina inhloso yeqembu';

  @override
  String get team_goal_join_cancel => 'Khansela';

  @override
  String get team_goal_join_confirm => 'Joyina iqembu';

  @override
  String team_details_error(Object error) {
    return 'Iphutha: $error';
  }

  @override
  String get team_goal_not_found => 'Inhloso yeqembu ayitholakali.';

  @override
  String get manager_inbox_approve => 'Vuma';

  @override
  String get manager_inbox_request_changes => 'Cela izinguquko';

  @override
  String get manager_inbox_reject => 'Nqaba';

  @override
  String get manager_inbox_mark_all_as_read => 'Maka konke kufundiwe';

  @override
  String get manager_inbox_view_goal => 'Bona inhloso';

  @override
  String get manager_inbox_view_badges => 'Bona amabheji';

  @override
  String get manager_inbox_all_priorities => 'Zonke izinga lokubaluleka';

  @override
  String get manager_review_nudge => 'Khuthaza';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Ukuhalalisela';

  @override
  String get manager_review_activity => 'Umsebenzi';

  @override
  String get manager_review_send => 'Thumela';

  @override
  String get manager_review_schedule => 'Hlela';

  @override
  String get manager_review_send_kudos => 'Thumela ukuhalalisela';

  @override
  String get manager_review_close => 'Vala';

  @override
  String get manager_review_check_authentication => 'Hlola ukuqinisekiswa';

  @override
  String get season_management_title => 'Ukuphathwa kwesizini';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Phatha u-$seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Nweba isizini';

  @override
  String get season_management_view_celebration => 'Bona umkhosi';

  @override
  String get season_challenge_title => 'Inselelo yesizini';

  @override
  String get team_challenges_create_season => 'Dala isizini';

  @override
  String get team_challenges_view_details => 'Bona imininingwane';

  @override
  String get team_challenges_manage => 'Phatha';

  @override
  String get team_challenges_celebration => 'Umkhosi';

  @override
  String get team_challenges_paused_only => 'Okumisiwe kuphela';

  @override
  String get season_details_not_found => 'Isizini ayitholakali';

  @override
  String get season_details_complete_season => 'Qeda isizini';

  @override
  String get season_details_extend_season => 'Nweba isizini';

  @override
  String get season_details_celebrate => 'Gubha';

  @override
  String get season_details_recompute => 'Bala futhi';

  @override
  String get season_details_delete_season => 'Cima isizini';

  @override
  String get season_details_force_complete_title =>
      'Ufuna ukuqeda isizini ngamandla?';

  @override
  String get season_details_force_complete_confirm => 'Qeda ngamandla';

  @override
  String get season_details_complete_title => 'Ufuna ukuqeda isizini?';

  @override
  String get season_details_complete_confirm => 'Qeda';

  @override
  String get season_details_delete_title => 'Ufuna ukucima isizini?';

  @override
  String get season_details_delete_confirm => 'Cima';

  @override
  String get season_goal_completion_title => 'Qeda inhloso yesizini';

  @override
  String get season_goal_completion_go_back => 'Buyela emuva';

  @override
  String get season_celebration_share => 'Yabelana ngomkhosi';

  @override
  String get season_celebration_create_new => 'Dala isizini entsha';

  @override
  String get season_celebration_shared_success => 'Umkhosi usabelwe!';

  @override
  String get employee_season_join => 'Joyina isizini';

  @override
  String get employee_season_view_details => 'Bona imininingwane';

  @override
  String get employee_season_complete_goals => 'Qeda izinhloso';

  @override
  String get employee_season_update => 'Vuselela';

  @override
  String get employee_season_view_celebration => 'Bona umkhosi';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'Ujoyine ngempumelelo \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Iphutha ekungeneni esizini: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'Akasabikho izinhloso zesizini ze-\"$seasonTitle\" okwamanje.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Ihlulekile ukuvula imininingwane yenhloso: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'Kuthunyelwe ukuze kugunyazwe ngumphathi';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Iphutha ekuthumeleni ekugunyazweni: $error';
  }

  @override
  String get goal_delete_title => 'Cima Inhloso';

  @override
  String get goal_deleted => 'Inhloso icishiwe';

  @override
  String goal_delete_error(Object error) {
    return 'Iphutha ekucisheni inhloso: $error';
  }

  @override
  String get goal_start_success =>
      'Inhloso isiqalile! Uthole amaphuzu angu-20 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Iphutha ekuqaleni kwenhloso: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Sicela uqale inhloso ngaphambi kokuyiqeda.';

  @override
  String get goal_complete_require_100 =>
      'Beka inqubekela phambili ku-100% ukuze uqede.';

  @override
  String get goal_complete_success =>
      'Inhloso seyiqediwe! Uthole amaphuzu angu-100 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Iphutha ekupheleni kwenhloso: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Inqubekela phambili ivuselelwe ku-$progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Iphutha ekuvuseleleni inqubekela phambili: $error';
  }

  @override
  String get goal_set_to_100 => 'Beka ku-100%';

  @override
  String get goal_submit_for_approval_title => 'Thumela Ukuze Kugunyazwe';

  @override
  String get goal_add_milestone => 'Engeza i-milestone';

  @override
  String get goal_milestone_requires_sign_in =>
      'Kumele ungene ngemvume ukuze uphathe ama-milestone.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Izinhloso eziqediwe azisatholi ama-milestone amasha.';

  @override
  String get goal_milestone_title_required => 'Isihloko siyadingeka.';

  @override
  String get goal_milestone_due_date_required => 'Khetha usuku lokuphela.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Iphutha ekulondolozeni i-milestone: $error';
  }

  @override
  String get goal_milestone_deadline_hint =>
      'Chofoza ukukhetha usuku lokuphela';

  @override
  String get goal_milestone_change => 'Shintsha';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'Imakwe njenge-$status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Iphutha ekubuyekezeni i-milestone: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Cima i-milestone';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Ufuna ukukhipha le milestone kule nhloso?';

  @override
  String get goal_milestone_deleted => 'I-milestone icishiwe.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Iphutha ekucisheni i-milestone: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Hlela imininingwane';

  @override
  String get goal_milestone_mark_not_started => 'Maka njengingakaqali';

  @override
  String get goal_milestone_mark_in_progress => 'Maka njengiqhubeka';

  @override
  String get goal_milestone_mark_blocked => 'Maka njengivinjiwe';

  @override
  String get goal_milestone_mark_completed => 'Maka njengiphelile';

  @override
  String get manager_team_workspace_create_team_goal => 'Dala inhloso yeqembu';

  @override
  String get manager_team_workspace_view_details => 'Bona imininingwane';

  @override
  String get manager_team_workspace_manage_team => 'Phatha iqembu';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Dala inhloso yeqembu';

  @override
  String get database_test_title => 'Ukuhlola i-database';

  @override
  String get database_test_add_goal => 'Engeza inhloso';

  @override
  String get database_test_add_sample_goals => 'Engeza izinhloso zesibonelo';

  @override
  String get employee_profile_detail_send_nudge => 'Thumela isikhuthazo';

  @override
  String get employee_profile_detail_schedule_meeting => 'Hlela umhlangano';

  @override
  String get employee_profile_detail_give_recognition => 'Nikeza ukuhlonipha';

  @override
  String get employee_profile_detail_assign_goal => 'abela inhloso';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Umsebenzi uzofakwa lapha kamuva';

  @override
  String get my_goal_workspace_suggest => 'Phakamisa';

  @override
  String get my_goal_workspace_generate => 'Dala';

  @override
  String get my_goal_workspace_enter_goal_title =>
      'Sicela ufake isihloko senhloso';

  @override
  String get my_goal_workspace_select_target_date =>
      'Sicela ukhethe usuku okuhlosiwe ngalo';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Iphutha ekudaleni inhloso: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Dala inhloso';

  @override
  String get team_chats_edit_message => 'Hlela umlayezo';

  @override
  String get team_chats_delete_message_title => 'Cima umlayezo?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'Lesi senzo asikwazi ukubuyiselwa emuva.';

  @override
  String get gamification_title => 'Ugqugquzelo ngemidlalo';

  @override
  String get gamification_content =>
      'Okuqukethwe kwesikrini sokugqugquzela ngemidlalo';

  @override
  String get my_pdp_ok => 'Kulungile';

  @override
  String get my_pdp_upload_file => 'Layisha ifayela (PDF/Word/Isithombe)';

  @override
  String get my_pdp_save_note_link => 'Gcina inothi/isixhumanisi';

  @override
  String get my_pdp_change_evidence => 'Shintsha ubufakazi';

  @override
  String get my_pdp_go_to_settings => 'Iya Ezilungiseleleni';

  @override
  String get my_pdp_add_session => '+1 iseshini';

  @override
  String get my_pdp_module_complete => 'Imodyuli iqediwe';

  @override
  String get role_access_restricted_title => 'Ukufinyelela Kunqunyelwe';

  @override
  String role_access_restricted_body(Object role) {
    return 'Indima yakho ($role) ayivunyelwe kuleli khasi.';
  }

  @override
  String get role_go_to_my_portal => 'Iya kuphothali yami';

  @override
  String get evidence_sign_in_required =>
      'Sicela ungene ngemvume ukuze ubone ubufakazi bakho.';

  @override
  String get evidence_sort_by_date => 'Hlela Ngosuku';

  @override
  String get evidence_sort_by_title => 'Hlela Ngangesihloko';

  @override
  String get evidence_no_evidence_found => 'Akukho bufakazi obutholakeleyo.';

  @override
  String get evidence_dialog_title => 'Ubufakazi';

  @override
  String get employee_profile_remove_photo => 'Susa Isithombe';

  @override
  String get employee_profile_login_required_remove_photo =>
      'Kumele ungene ngemvume ukuze ususe isithombe sakho.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Ihlulekile ukususa isithombe: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'Kumele ungene ngemvume ukuze ulayishe isithombe.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Ihlulekile ukulayisha isithombe: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'Kumele ungene ngemvume ukuze ugcine iphrofayela yakho.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Ihlulekile ukulondoloza iphrofayela: $error';
  }

  @override
  String get employee_drawer_exit => 'Phuma';

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
      'Iphutha ekulayisheni idatha yomsebenzisi';

  @override
  String get progress_visuals_all_departments => 'Iminyango yonke';

  @override
  String get progress_visuals_send_nudge => 'Thumela isikhuthazo';

  @override
  String get progress_visuals_meet => 'Hlangana';

  @override
  String get progress_visuals_view_details => 'Bona imininingwane';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Isikhuthazo sithunyelwe ku-$employeeName';
  }

  @override
  String get progress_visuals_debug_information =>
      'Ulwazi lokuxazulula amaphutha';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Iphutha lokulungisa: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'Imibono ye-AI';

  @override
  String get alerts_nudges_ai_assistant => 'Umncedisi we-AI';

  @override
  String get alerts_nudges_refresh => 'Vuselela';

  @override
  String get alerts_nudges_create_first_goal => 'Dala inhloso yakho yokuqala';

  @override
  String get alerts_nudges_dismiss => 'Cisha';

  @override
  String get alerts_nudges_copy => 'Kopisha';

  @override
  String get alerts_nudges_edit => 'Hlela';

  @override
  String get manager_alerts_add_reschedule_note =>
      'Engeza inothi yokuhlela kabusha';

  @override
  String get manager_alerts_skip => 'Weqa';

  @override
  String get manager_alerts_save => 'Gcina';

  @override
  String get manager_alerts_reject_goal => 'Nqaba inhloso';

  @override
  String get manager_alerts_ai_team_insights => 'Imibono yeqembu ye-AI';

  @override
  String get manager_alerts_all_priorities => 'Zonke izinga lokubaluleka';

  @override
  String get manager_alerts_review_goal => 'Bukeza inhloso';

  @override
  String get manager_alerts_reschedule => 'Hlela kabusha';

  @override
  String get manager_alerts_extend_deadline => 'Nweba usuku lokugcina';

  @override
  String get manager_alerts_pause_goal => 'Misa inhloso isikhashana';

  @override
  String get manager_alerts_mark_burnout => 'Maka ukukhathala';

  @override
  String get manager_alerts_select_goal_hint => 'Khetha inhloso';

  @override
  String get manager_alerts_send_bulk_nudge => 'Thumela izikhuthazo ngobuningi';

  @override
  String get manager_alerts_send_to_all => 'Thumela kubo bonke';

  @override
  String get notifications_bell_ok => 'Kulungile';

  @override
  String get landing_app_title => 'Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}
