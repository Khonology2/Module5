// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Xhosa (`xh`).
class AppLocalizationsXh extends AppLocalizations {
  AppLocalizationsXh([String locale = 'xh']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Ulwimi luseti luhlaziyiwe';

  @override
  String get ok => 'Kulungile';

  @override
  String get cancel => 'Rhoxisa';

  @override
  String get close => 'Vala';

  @override
  String get retry => 'Zama kwakhona';

  @override
  String get save => 'Gcina';

  @override
  String get delete => 'Cima';

  @override
  String get create => 'Yenza';

  @override
  String get submit => 'Thumela';

  @override
  String get view => 'Jonga';

  @override
  String get details => 'Iinkcukacha';

  @override
  String get settings_go_to => 'Yi kwimimiselo';

  @override
  String get sign_out => 'Phuma';

  @override
  String get delete_account => 'Cima iakhawunti';

  @override
  String get export_my_data => 'Thumela ngaphandle idatha yam';

  @override
  String get send_password_reset_email =>
      'Thumela i-imeyile yokuseta kwakhona iphasiwedi';

  @override
  String get language_english => 'IsiNgesi';

  @override
  String get language_spanish => 'IsiSpeyinishi';

  @override
  String get language_french => 'IsiFrentshi';

  @override
  String get language_german => 'IsiJamani';

  @override
  String get time_15_minutes => 'imizuzu eli-15';

  @override
  String get time_30_minutes => 'imizuzu engama-30';

  @override
  String get time_60_minutes => 'iyure e-1';

  @override
  String get time_120_minutes => 'iiyure ezi-2';

  @override
  String get status_all => 'Zonke iimeko';

  @override
  String get status_verified => 'Iqinisekisiwe';

  @override
  String get status_pending => 'Iyalindelwa';

  @override
  String get status_rejected => 'Yaliwe';

  @override
  String get audit_export_csv => 'Thumela ngaphandle njenge-CSV';

  @override
  String get audit_export_pdf => 'Thumela ngaphandle njenge-PDF';

  @override
  String get audit_submit_for_audit => 'Thumela ukuze kuhlolwe';

  @override
  String get audit_no_timeline_events_yet =>
      'Akukabikho ziganeko kumgca wexesha';

  @override
  String get dashboard_refresh_data => 'Hlaziya idatha';

  @override
  String get dashboard_recent_activity => 'Umsebenzi wakutsha nje';

  @override
  String get dashboard_quick_actions => 'Iintshukumo ezikhawulezayo';

  @override
  String get dashboard_upcoming_goals => 'Iinjongo ezizayo';

  @override
  String get dashboard_add_goal => 'Yongeza injongo';

  @override
  String get dashboard_awaiting_manager_approval =>
      'Ilindele imvume yomphathi.';

  @override
  String get employee_create_first_goal => 'Yenza injongo yakho yokuqala';

  @override
  String get manager_team_kpis => 'Ii-KPI zeqela';

  @override
  String get manager_team_health => 'Impilo yeqela';

  @override
  String get manager_activity_summary => 'Isishwankathelo somsebenzi';

  @override
  String get manager_top_performers => 'Abasebenzi abaphezulu';

  @override
  String get manager_no_performers_yet =>
      'Akukho basebenzi babalaseleyo okwangoku';

  @override
  String get manager_quick_actions => 'Iintshukumo ezikhawulezayo';

  @override
  String get manager_complete_season => 'Gqiba isizini';

  @override
  String manager_team_size(Object teamSize) {
    return 'Ubungakanani beqela: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Joyina injongo yeqela';

  @override
  String get team_goal_join_cancel => 'Rhoxisa';

  @override
  String get team_goal_join_confirm => 'Joyina iqela';

  @override
  String team_details_error(Object error) {
    return 'Imposiso: $error';
  }

  @override
  String get team_goal_not_found => 'Injongo yeqela ayifumanekanga.';

  @override
  String get manager_inbox_approve => 'Vuma';

  @override
  String get manager_inbox_request_changes => 'Cela utshintsho';

  @override
  String get manager_inbox_reject => 'Yala';

  @override
  String get manager_inbox_mark_all_as_read =>
      'Phawula konke njengokufundiweyo';

  @override
  String get manager_inbox_view_goal => 'Jonga injongo';

  @override
  String get manager_inbox_view_badges => 'Jonga iibheji';

  @override
  String get manager_inbox_all_priorities => 'Zonke izinto ezibalulekileyo';

  @override
  String get manager_review_nudge => 'Khwaza';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Imibulelo';

  @override
  String get manager_review_activity => 'Umsebenzi';

  @override
  String get manager_review_send => 'Thumela';

  @override
  String get manager_review_schedule => 'Cwangcisa';

  @override
  String get manager_review_send_kudos => 'Thumela imibulelo';

  @override
  String get manager_review_close => 'Vala';

  @override
  String get manager_review_check_authentication => 'Jonga isazisi';

  @override
  String get season_management_title => 'Ulawulo lwesizini';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Lawula u-$seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Yandisa isizini';

  @override
  String get season_management_view_celebration => 'Jonga umnyhadala';

  @override
  String get season_challenge_title => 'Umceli mngeni wesizini';

  @override
  String get team_challenges_create_season => 'Yenza isizini';

  @override
  String get team_challenges_view_details => 'Jonga iinkcukacha';

  @override
  String get team_challenges_manage => 'Lawula';

  @override
  String get team_challenges_celebration => 'Umnyhadala';

  @override
  String get team_challenges_paused_only => 'Okumisiweyo kuphela';

  @override
  String get season_details_not_found => 'Isizini ayifumanekanga';

  @override
  String get season_details_complete_season => 'Gqiba isizini';

  @override
  String get season_details_extend_season => 'Yandisa isizini';

  @override
  String get season_details_celebrate => 'Bhiyozela';

  @override
  String get season_details_recompute => 'Bala kwakhona';

  @override
  String get season_details_delete_season => 'Cima isizini';

  @override
  String get season_details_force_complete_title => 'Ugqibe isizini ngenkani?';

  @override
  String get season_details_force_complete_confirm => 'Gqiba ngenkani';

  @override
  String get season_details_complete_title => 'Ugqibe isizini?';

  @override
  String get season_details_complete_confirm => 'Gqiba';

  @override
  String get season_details_delete_title => 'Ucima isizini?';

  @override
  String get season_details_delete_confirm => 'Cima';

  @override
  String get season_goal_completion_title => 'Gqiba injongo yesizini';

  @override
  String get season_goal_completion_go_back => 'Buyela umva';

  @override
  String get season_celebration_share => 'Yabelana ngomnyhadala';

  @override
  String get season_celebration_create_new => 'Yenza isizini entsha';

  @override
  String get season_celebration_shared_success => 'Umnyhadala wabelwana ngawo!';

  @override
  String get employee_season_join => 'Joyina isizini';

  @override
  String get employee_season_view_details => 'Jonga iinkcukacha';

  @override
  String get employee_season_complete_goals => 'Gqiba iinjongo';

  @override
  String get employee_season_update => 'Hlaziya';

  @override
  String get employee_season_view_celebration => 'Jonga umnyhadala';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'Ujoyine ngempumelelo \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Imposiso ekjoyineni isizini: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'Akukho zinjongo zesizini zika-\"$seasonTitle\" okwangoku.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Kusilele ukuvula iinkcukacha zenjongo: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'Kuthunyelwe ukuze kuvunywe ngumphathi';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Kusilele ukuthumela ukuze kuvunywe: $error';
  }

  @override
  String get goal_delete_title => 'Cima injongo';

  @override
  String get goal_deleted => 'Injongo icinyiwe';

  @override
  String goal_delete_error(Object error) {
    return 'Kusilele ukucima injongo: $error';
  }

  @override
  String get goal_start_success =>
      'Injongo iqalile! Amanqaku angama-20 afunyenwe 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Imposiso ekuqaleni kwenjongo: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Nceda uqale injongo ngaphambi kokuba uyigqibe.';

  @override
  String get goal_complete_require_100 =>
      'Misela inkqubela kwi-100% ukuze ugqibe.';

  @override
  String get goal_complete_success =>
      'Injongo igqityiwe! Amanqaku ayi-100 afunyenwe 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Imposiso ekugqibeleni injongo: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Inkqubela ihlaziywe ku-$progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Imposiso ekuhlaziyeni inkqubela: $error';
  }

  @override
  String get goal_set_to_100 => 'Misela ku-100%';

  @override
  String get goal_submit_for_approval_title => 'Thumela ukuze kuvunywe';

  @override
  String get goal_add_milestone => 'Yongeza inqanaba';

  @override
  String get goal_milestone_requires_sign_in =>
      'Kufuneka ungene ukuze ulawule amanqanaba.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Iinjongo ezigqityiweyo azamkeli amanqanaba amatsha.';

  @override
  String get goal_milestone_title_required => 'Isihloko siyafuneka.';

  @override
  String get goal_milestone_due_date_required => 'Khetha umhla wokuphela.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Kusilele ukugcina inqanaba: $error';
  }

  @override
  String get goal_milestone_deadline_hint =>
      'Cofa ukuze ukhethe umhla wokuphela';

  @override
  String get goal_milestone_change => 'Tshintsha';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'Iphawulwe njenge-$status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Kusilele ukuhlaziya inqanaba: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Cima inqanaba';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Ufuna ukususa eli nqanaba kule njongo?';

  @override
  String get goal_milestone_deleted => 'Inqanaba licinyiwe.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Kusilele ukucima inqanaba: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Hlela iinkcukacha';

  @override
  String get goal_milestone_mark_not_started => 'Phawula njenge-ingakaqali';

  @override
  String get goal_milestone_mark_in_progress => 'Phawula njenge-iyaqhubeka';

  @override
  String get goal_milestone_mark_blocked => 'Phawula njenge-ivaliwe';

  @override
  String get goal_milestone_mark_completed => 'Phawula njenge-igqityiwe';

  @override
  String get manager_team_workspace_create_team_goal => 'Yenza injongo yeqela';

  @override
  String get manager_team_workspace_view_details => 'Jonga iinkcukacha';

  @override
  String get manager_team_workspace_manage_team => 'Lawula iqela';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Yenza injongo yeqela';

  @override
  String get database_test_title => 'Uvavanyo lwedatha';

  @override
  String get database_test_add_goal => 'Yongeza injongo';

  @override
  String get database_test_add_sample_goals => 'Yongeza iinjongo zesampulu';

  @override
  String get employee_profile_detail_send_nudge => 'Thumela isikhuthazo';

  @override
  String get employee_profile_detail_schedule_meeting =>
      'Cwangcisa intlanganiso';

  @override
  String get employee_profile_detail_give_recognition => 'Nika uqaphelo';

  @override
  String get employee_profile_detail_assign_goal => 'abela injongo';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Umsebenzi uza kufakwa apha';

  @override
  String get my_goal_workspace_suggest => 'Cebisa';

  @override
  String get my_goal_workspace_generate => 'Velisa';

  @override
  String get my_goal_workspace_enter_goal_title =>
      'Nceda ufake isihloko senjongo';

  @override
  String get my_goal_workspace_select_target_date =>
      'Nceda ukhethe umhla ojoliswe kuwo';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Imposiso ekudaleni injongo: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Yenza injongo';

  @override
  String get team_chats_edit_message => 'Hlela umyalezo';

  @override
  String get team_chats_delete_message_title => 'Cima umyalezo?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'Esi senzo asinakubuyiselwa umva.';

  @override
  String get gamification_title => 'Umdlalo wokukhuthaza';

  @override
  String get gamification_content => 'Umxholo wesikrini somdlalo wokukhuthaza';

  @override
  String get my_pdp_ok => 'Kulungile';

  @override
  String get my_pdp_upload_file => 'Layisha ifayile (PDF/Word/Umfanekiso)';

  @override
  String get my_pdp_save_note_link => 'Gcina inqaku/ikhonkco';

  @override
  String get my_pdp_change_evidence => 'Tshintsha ubungqina';

  @override
  String get my_pdp_go_to_settings => 'Yi kwimimiselo';

  @override
  String get my_pdp_add_session => '+1 iseshoni';

  @override
  String get my_pdp_module_complete => 'Imodyuli igqityiwe';

  @override
  String get role_access_restricted_title => 'Ufikelelo lunqatshelwe';

  @override
  String role_access_restricted_body(Object role) {
    return 'Indima yakho ($role) ayinayo imvume yokungena kweli phepha.';
  }

  @override
  String get role_go_to_my_portal => 'Yi kwindawo yam yefestile';

  @override
  String get evidence_sign_in_required =>
      'Nceda ungene ukuze ubone ubungqina bakho.';

  @override
  String get evidence_sort_by_date => 'Hlela ngomhla';

  @override
  String get evidence_sort_by_title => 'Hlela ngesihloko';

  @override
  String get evidence_no_evidence_found => 'Akufumanekanga bungqina.';

  @override
  String get evidence_dialog_title => 'Ubungqina';

  @override
  String get employee_profile_remove_photo => 'Susa ifoto';

  @override
  String get employee_profile_login_required_remove_photo =>
      'Kufuneka ungene ukuze ususe ifoto yakho.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Kusilele ukususa ifoto: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'Kufuneka ungene ukuze ulayishe ifoto.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Kusilele ukulayisha ifoto: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'Kufuneka ungene ukuze ugcine iprofayile yakho.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Kusilele ukugcina iprofayile: $error';
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
  String get nav_my_pdp => 'My PDP';

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
      'Imposiso ekulayisheni idatha yomsebenzisi';

  @override
  String get progress_visuals_all_departments => 'Zonke izebe';

  @override
  String get progress_visuals_send_nudge => 'Thumela isikhuthazo';

  @override
  String get progress_visuals_meet => 'Dibana';

  @override
  String get progress_visuals_view_details => 'Jonga iinkcukacha';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Isikhuthazo sithunyelwe ku-$employeeName';
  }

  @override
  String get progress_visuals_debug_information =>
      'Ulwazi lokulungisa iimpazamo';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Imposiso yokulungisa: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'Iingcebiso ze-AI';

  @override
  String get alerts_nudges_ai_assistant => 'Umncedisi we-AI';

  @override
  String get alerts_nudges_refresh => 'Hlaziya';

  @override
  String get alerts_nudges_create_first_goal => 'Yenza injongo yakho yokuqala';

  @override
  String get alerts_nudges_dismiss => 'Vala';

  @override
  String get alerts_nudges_copy => 'Kopisha';

  @override
  String get alerts_nudges_edit => 'Hlela';

  @override
  String get manager_alerts_add_reschedule_note =>
      'Yongeza inqaku lokuhlehlisa';

  @override
  String get manager_alerts_skip => 'Tsiba';

  @override
  String get manager_alerts_save => 'Gcina';

  @override
  String get manager_alerts_reject_goal => 'Yala injongo';

  @override
  String get manager_alerts_ai_team_insights => 'Iingcebiso zeqela ze-AI';

  @override
  String get manager_alerts_all_priorities => 'Zonke izinto ezibalulekileyo';

  @override
  String get manager_alerts_review_goal => 'Hlola injongo';

  @override
  String get manager_alerts_reschedule => 'Cwangcisa kwakhona';

  @override
  String get manager_alerts_extend_deadline => 'Yandisa umhla wokuphela';

  @override
  String get manager_alerts_pause_goal => 'Misa injongo okwethutyana';

  @override
  String get manager_alerts_mark_burnout => 'Phawula ukudinwa';

  @override
  String get manager_alerts_select_goal_hint => 'Khetha injongo';

  @override
  String get manager_alerts_send_bulk_nudge => 'Thumela izikhuthazo ngobuninzi';

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
