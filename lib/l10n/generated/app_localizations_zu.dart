// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Zulu (`zu`).
class AppLocalizationsZu extends AppLocalizations {
  AppLocalizationsZu([String locale = 'zu']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Ulimi lusesha lubuyekeziwe';

  @override
  String get ok => 'Kulungile';

  @override
  String get cancel => 'Khansela';

  @override
  String get close => 'Vala';

  @override
  String get retry => 'Zama futhi';

  @override
  String get save => 'Londoloza';

  @override
  String get delete => 'Susa';

  @override
  String get create => 'Dala';

  @override
  String get submit => 'Thumela';

  @override
  String get view => 'Buka';

  @override
  String get details => 'Imininingwane';

  @override
  String get settings_go_to => 'Iya kuzilungiselelo';

  @override
  String get sign_out => 'Phuma';

  @override
  String get delete_account => 'Susa i-akhawunti';

  @override
  String get export_my_data => 'Thumela idatha yami';

  @override
  String get send_password_reset_email =>
      'Thumela i-imeyili yokusetha kabusha iphasiwedi';

  @override
  String get language_english => 'IsiNgisi';

  @override
  String get language_spanish => 'iSpanish';

  @override
  String get language_french => 'iFrench';

  @override
  String get language_german => 'iGerman';

  @override
  String get time_15_minutes => 'imizuzu eyi-15';

  @override
  String get time_30_minutes => 'imizuzu engama-30';

  @override
  String get time_60_minutes => 'ihora eli-1';

  @override
  String get time_120_minutes => 'amahora ama-2';

  @override
  String get status_all => 'Zonke izimo';

  @override
  String get status_verified => 'Kuqinisekisiwe';

  @override
  String get status_pending => 'Kulindile';

  @override
  String get status_rejected => 'Kwenqatshiwe';

  @override
  String get audit_export_csv => 'Thumela njenge-CSV';

  @override
  String get audit_export_pdf => 'Thumela njenge-PDF';

  @override
  String get audit_submit_for_audit => 'Thumela ukuze kubuyekezwe';

  @override
  String get audit_no_timeline_events_yet =>
      'Azikabikho izehlakalo zomugqa wesikhathi';

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
      'Ilinde ukugunyazwa umphathi.';

  @override
  String get employee_create_first_goal => 'Dala inhloso yakho yokuqala';

  @override
  String get manager_team_kpis => 'Ama-KPI eqembu';

  @override
  String get manager_team_health => 'Impilo yeqembu';

  @override
  String get manager_activity_summary => 'Isifinyezo somsebenzi';

  @override
  String get manager_top_performers => 'Abasebenzi abahamba phambili';

  @override
  String get manager_no_performers_yet => 'Abakabi bikho abasebenzi abavelele';

  @override
  String get manager_quick_actions => 'Izenzo ezisheshayo';

  @override
  String get manager_complete_season => 'Qedela isizini';

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
  String get manager_inbox_approve => 'Gunyaza';

  @override
  String get manager_inbox_request_changes => 'Cela izinguquko';

  @override
  String get manager_inbox_reject => 'Nqaba';

  @override
  String get manager_inbox_mark_all_as_read => 'Phawula konke kufundiwe';

  @override
  String get manager_inbox_view_goal => 'Buka inhloso';

  @override
  String get manager_inbox_view_badges => 'Buka ama-badge';

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
  String get manager_review_check_authentication => 'Hlola ukuqinisekisa';

  @override
  String get season_management_title => 'Ukuphathwa kwesizini';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Phatha u-$seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Nweba isizini';

  @override
  String get season_management_view_celebration => 'Buka umgubho';

  @override
  String get season_challenge_title => 'Inselelo yesizini';

  @override
  String get team_challenges_create_season => 'Dala isizini';

  @override
  String get team_challenges_view_details => 'Buka imininingwane';

  @override
  String get team_challenges_manage => 'Phatha';

  @override
  String get team_challenges_celebration => 'Umgubho';

  @override
  String get team_challenges_paused_only => 'Okumisiwe kuphela';

  @override
  String get season_details_not_found => 'Isizini ayitholakali';

  @override
  String get season_details_complete_season => 'Qedela isizini';

  @override
  String get season_details_extend_season => 'Nweba isizini';

  @override
  String get season_details_celebrate => 'Gubha';

  @override
  String get season_details_recompute => 'Bala kabusha';

  @override
  String get season_details_delete_season => 'Susa isizini';

  @override
  String get season_details_force_complete_title => 'Qedela isizini ngamandla?';

  @override
  String get season_details_force_complete_confirm => 'Qedela ngamandla';

  @override
  String get season_details_complete_title => 'Qedela isizini?';

  @override
  String get season_details_complete_confirm => 'Qedela';

  @override
  String get season_details_delete_title => 'Susa isizini?';

  @override
  String get season_details_delete_confirm => 'Susa';

  @override
  String get season_goal_completion_title => 'Qedela inhloso yesizini';

  @override
  String get season_goal_completion_go_back => 'Buyela emuva';

  @override
  String get season_celebration_share => 'Yabelana ngomgubho';

  @override
  String get season_celebration_create_new => 'Dala isizini entsha';

  @override
  String get season_celebration_shared_success => 'Umgubho wabelwane ngawo!';

  @override
  String get employee_season_join => 'Joyina isizini';

  @override
  String get employee_season_view_details => 'Buka imininingwane';

  @override
  String get employee_season_complete_goals => 'Qedela izinhloso';

  @override
  String get employee_season_update => 'Buyekeza';

  @override
  String get employee_season_view_celebration => 'Buka umgubho';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'Ujoyine ngempumelelo \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Iphutha ekujoyineni isizini: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'Azikabikho izinhloso zesizini zika-\"$seasonTitle\" okwamanje.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Yehlulekile ukuvula imininingwane yenhloso: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'Kuthunyelwe ukuze kugunyazwe umphathi';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Yehlulekile ukuthumela ukuze kugunyazwe: $error';
  }

  @override
  String get goal_delete_title => 'Susa inhloso';

  @override
  String get goal_deleted => 'Inhloso isusiwe';

  @override
  String goal_delete_error(Object error) {
    return 'Yehlulekile ukususa inhloso: $error';
  }

  @override
  String get goal_start_success =>
      'Inhloso iqalile! Amamaki angu-20 atholiwe 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Iphutha ekuqaleni kwenhloso: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Sicela uqale inhloso ngaphambi kokuyiqedela.';

  @override
  String get goal_complete_require_100 =>
      'Setha inqubekelaphambili ku-100% ukuze uqedele.';

  @override
  String get goal_complete_success =>
      'Inhloso iqediwe! Amamaki angu-100 atholiwe 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Iphutha ekupheleni kwenhloso: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Inqubekelaphambili ibuyekezwe ku-$progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Iphutha ekuvuseleleni inqubekelaphambili: $error';
  }

  @override
  String get goal_set_to_100 => 'Setha ku-100%';

  @override
  String get goal_submit_for_approval_title => 'Thumela ukuze kugunyazwe';

  @override
  String get goal_add_milestone => 'Engeza ibanga';

  @override
  String get goal_milestone_requires_sign_in =>
      'Kufanele ungene ngemvume ukuze uphathe amabanga.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Izinhloso eziqediwe azisamukeli amabanga amasha.';

  @override
  String get goal_milestone_title_required => 'Isihloko siyadingeka.';

  @override
  String get goal_milestone_due_date_required => 'Khetha usuku lokuphela.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Yehlulekile ukulondoloza ibanga: $error';
  }

  @override
  String get goal_milestone_deadline_hint =>
      'Thepha ukuze ukhethe usuku lokugcina';

  @override
  String get goal_milestone_change => 'Shintsha';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'Kuphawulwe njenge-$status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Yehlulekile ukuvuselela ibanga: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Susa ibanga';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Susa leli banga enhlosweni?';

  @override
  String get goal_milestone_deleted => 'Ibangalokususa.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Yehlulekile ukususa ibanga: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Hlela imininingwane';

  @override
  String get goal_milestone_mark_not_started => 'Phawula ukuthi akuqali';

  @override
  String get goal_milestone_mark_in_progress => 'Phawula ukuthi iyaqhubeka';

  @override
  String get goal_milestone_mark_blocked => 'Phawula ukuthi ivinjiwe';

  @override
  String get goal_milestone_mark_completed => 'Phawula ukuthi iqediwe';

  @override
  String get manager_team_workspace_create_team_goal => 'Dala inhloso yeqembu';

  @override
  String get manager_team_workspace_view_details => 'Buka imininingwane';

  @override
  String get manager_team_workspace_manage_team => 'Phatha iqembu';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Dala inhloso yeqembu';

  @override
  String get database_test_title => 'Isivivinyo sedatha';

  @override
  String get database_test_add_goal => 'Engeza inhloso';

  @override
  String get database_test_add_sample_goals => 'Engeza izinhloso zesampula';

  @override
  String get employee_profile_detail_send_nudge => 'Thumela isikhuthazo';

  @override
  String get employee_profile_detail_schedule_meeting => 'Hlela umhlangano';

  @override
  String get employee_profile_detail_give_recognition => 'Nikeza ukuqashelwa';

  @override
  String get employee_profile_detail_assign_goal => 'abela inhloso';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Umsebenzi uzofakwa lapha';

  @override
  String get my_goal_workspace_suggest => 'Phakamisa';

  @override
  String get my_goal_workspace_generate => 'Khiqiza';

  @override
  String get my_goal_workspace_enter_goal_title =>
      'Sicela ufake isihloko senhloso';

  @override
  String get my_goal_workspace_select_target_date =>
      'Sicela ukhethe usuku okuhlosiwe';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Iphutha ekudaleni inhloso: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Dala inhloso';

  @override
  String get team_chats_edit_message => 'Hlela umlayezo';

  @override
  String get team_chats_delete_message_title => 'Susa umlayezo?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'Lesi senzo asikwazi ukubuyiselwa emuva.';

  @override
  String get gamification_title => 'Ukugqugquzela ngokuqanjwa kwamaphuzu';

  @override
  String get gamification_content => 'Okuqukethwe kwesikrini sokugqugquzela';

  @override
  String get my_pdp_ok => 'Kulungile';

  @override
  String get my_pdp_upload_file => 'Layisha ifayela (PDF/Word/Isithombe)';

  @override
  String get my_pdp_save_note_link => 'Londoloza inothi/ilinki';

  @override
  String get my_pdp_change_evidence => 'Shintsha ubufakazi';

  @override
  String get my_pdp_go_to_settings => 'Iya kuzilungiselelo';

  @override
  String get my_pdp_add_session => '+1 iseshini';

  @override
  String get my_pdp_module_complete => 'Imojula iqediwe';

  @override
  String get role_access_restricted_title => 'Ukufinyelela kunqunyelwe';

  @override
  String role_access_restricted_body(Object role) {
    return 'Indima yakho ($role) ayinakho ukufinyelela kuleli khasi.';
  }

  @override
  String get role_go_to_my_portal => 'Iya kuphothali yami';

  @override
  String get evidence_sign_in_required =>
      'Sicela ungene ngemvume ukuze ubone ubufakazi bakho.';

  @override
  String get evidence_sort_by_date => 'Hlunga ngedethi';

  @override
  String get evidence_sort_by_title => 'Hlunga ngesihloko';

  @override
  String get evidence_no_evidence_found => 'Akutholakali bufakazi.';

  @override
  String get evidence_dialog_title => 'Ubufakazi';

  @override
  String get employee_profile_remove_photo => 'Susa isithombe';

  @override
  String get employee_profile_login_required_remove_photo =>
      'Kufanele ungene ngemvume ukuze ususe isithombe sakho.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Yehlulekile ukususa isithombe: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'Kufanele ungene ngemvume ukuze ulayishe isithombe.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Yehlulekile ukulayisha isithombe: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'Kufanele ungene ngemvume ukuze ulondoloze iphrofayela yakho.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Yehlulekile ukulondoloza iphrofayela: $error';
  }

  @override
  String get employee_drawer_exit => 'Phuma';

  @override
  String get nav_dashboard => 'Iphaneli';

  @override
  String get nav_goal_workspace => 'Indawo yokusebenza ngezinhloso';

  @override
  String get nav_my_profile => 'Iphrofayela yami';

  @override
  String get nav_my_pdp => 'MyPdp';

  @override
  String get nav_progress_visuals => 'Izibonakaliso zenqubekelaphambili';

  @override
  String get nav_alerts_nudges => 'Izexwayiso & Izikhuthazo';

  @override
  String get nav_badges_points => 'Amabhajhi & Amaphuzu';

  @override
  String get nav_season_challenges => 'Izinselelo zesizini';

  @override
  String get nav_leaderboard => 'Uhlu lokuhola';

  @override
  String get nav_repository_audit => 'I-Repository & Ucwaningo';

  @override
  String get nav_settings_privacy => 'Izilungiselelo & Ubumfihlo';

  @override
  String get nav_team_challenges => 'Izinselelo zeqembu';

  @override
  String get nav_team_alerts_nudges => 'Izexwayiso nezinxushunxushu zeqembu';

  @override
  String get nav_manager_inbox => 'Ibhokisi lemiyalezo';

  @override
  String get nav_review_team => 'Buyekeza iqembu';

  @override
  String get nav_admin_dashboard => 'Iphaneli yomlawuli';

  @override
  String get nav_user_management => 'Ukuphathwa kwabasebenzisi';

  @override
  String get nav_analytics => 'Ukuhlaziywa';

  @override
  String get nav_system_settings => 'Izilungiselelo zesistimu';

  @override
  String get nav_security => 'Ezokuphepha';

  @override
  String get nav_backup_restore => 'Ukugcinwa nokubuyiselwa';

  @override
  String get employee_portal_title => 'Iphothali yabasebenzi';

  @override
  String get progress_visuals_error_loading_user_data =>
      'Iphutha ekulayisheni idatha yomsebenzisi';

  @override
  String get progress_visuals_all_departments => 'Yonke iminyango';

  @override
  String get progress_visuals_send_nudge => 'Thumela isikhuthazo';

  @override
  String get progress_visuals_meet => 'Hlangana';

  @override
  String get progress_visuals_view_details => 'Buka imininingwane';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Isikhuthazo sithunyelwe ku-$employeeName';
  }

  @override
  String get progress_visuals_debug_information =>
      'Ulwazi lokuxazulula amaphutha';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Iphutha lokuxazulula: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'Ukuqonda kwe-AI';

  @override
  String get alerts_nudges_ai_assistant => 'Umsizi we-AI';

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
  String get manager_alerts_add_reschedule_note => 'Engeza inothi lokuhlehlisa';

  @override
  String get manager_alerts_skip => 'Weqa';

  @override
  String get manager_alerts_save => 'Londoloza';

  @override
  String get manager_alerts_reject_goal => 'Nqaba inhloso';

  @override
  String get manager_alerts_ai_team_insights => 'Ukuqonda kweqembu kwe-AI';

  @override
  String get manager_alerts_all_priorities => 'Zonke izinga lokubaluleka';

  @override
  String get manager_alerts_review_goal => 'Bukeza inhloso';

  @override
  String get manager_alerts_reschedule => 'Hlela kabusha';

  @override
  String get manager_alerts_extend_deadline => 'Nweba usuku lokugcina';

  @override
  String get manager_alerts_pause_goal => 'Misa inhloso okwesikhashana';

  @override
  String get manager_alerts_mark_burnout => 'Phawula ukukhathala';

  @override
  String get manager_alerts_select_goal_hint => 'Khetha inhloso';

  @override
  String get manager_alerts_send_bulk_nudge => 'Thumela izikhuthazo ngobuningi';

  @override
  String get manager_alerts_send_to_all => 'Thumela kubo bonke';

  @override
  String get notifications_bell_ok => 'Kulungile';

  @override
  String get landing_app_title => 'I-Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}
