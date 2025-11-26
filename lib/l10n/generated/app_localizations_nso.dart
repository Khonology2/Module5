// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Pedi Northern Sotho Sepedi (`nso`).
class AppLocalizationsNso extends AppLocalizations {
  AppLocalizationsNso([String locale = 'nso']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Puo e ntšhitšwe gape';

  @override
  String get ok => 'Go lokile';

  @override
  String get cancel => 'Khansela';

  @override
  String get close => 'Tswalela';

  @override
  String get retry => 'Leka gape';

  @override
  String get save => 'Boloka';

  @override
  String get delete => 'Phumola';

  @override
  String get create => 'Hlama';

  @override
  String get submit => 'Romela';

  @override
  String get view => 'Lebelela';

  @override
  String get details => 'Dintlha';

  @override
  String get settings_go_to => 'Eya go Di-Settings';

  @override
  String get sign_out => 'Etšwa';

  @override
  String get delete_account => 'Phumola akhaonto';

  @override
  String get export_my_data => 'Romela tšhedimošo ya ka ka ntle';

  @override
  String get send_password_reset_email =>
      'Romela imeile ya go beakanya phasewete gape';

  @override
  String get language_english => 'Seisemane';

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
  String get time_60_minutes => 'iri e 1';

  @override
  String get time_120_minutes => 'diiri tše 2';

  @override
  String get status_all => 'Maemo ka moka';

  @override
  String get status_verified => 'Netefaditšwe';

  @override
  String get status_pending => 'E sa emetše';

  @override
  String get status_rejected => 'Gannwe';

  @override
  String get audit_export_csv => 'Romela bjalo ka CSV';

  @override
  String get audit_export_pdf => 'Romela bjalo ka PDF';

  @override
  String get audit_submit_for_audit => 'Romela go hlahlobiwa';

  @override
  String get audit_no_timeline_events_yet =>
      'Ga go ditiragalo mo mothalong wa nako ga bjale';

  @override
  String get dashboard_refresh_data => 'Mpshafatša data';

  @override
  String get dashboard_recent_activity => 'Mediro ya morago bjale';

  @override
  String get dashboard_quick_actions => 'Ditiro tše kapejana';

  @override
  String get dashboard_upcoming_goals => 'Dikgopolo tše di tlago';

  @override
  String get dashboard_add_goal => 'Oketša sepheo';

  @override
  String get dashboard_awaiting_manager_approval =>
      'E emetše tumelelo ya molaodi.';

  @override
  String get employee_create_first_goal => 'Hlama sepheo sa gago sa mathomo';

  @override
  String get manager_team_kpis => 'Dikgopolo tša KPI tša sehlopha';

  @override
  String get manager_team_health => 'Maphelo a sehlopha';

  @override
  String get manager_activity_summary => 'Kakaretšo ya mediro';

  @override
  String get manager_top_performers => 'Ba šomago gabotse kudu';

  @override
  String get manager_no_performers_yet => 'Ga go ba šomago gabotse ga bjale';

  @override
  String get manager_quick_actions => 'Ditiro tše kapejana';

  @override
  String get manager_complete_season => 'Fediša sehla';

  @override
  String manager_team_size(Object teamSize) {
    return 'Bogolo bja sehlopha: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Tsena sepheng sa sehlopha';

  @override
  String get team_goal_join_cancel => 'Khansela';

  @override
  String get team_goal_join_confirm => 'Tsena sehlopheng';

  @override
  String team_details_error(Object error) {
    return 'Phoso: $error';
  }

  @override
  String get team_goal_not_found => 'Sepheo sa sehlopha ga se a hwetšwa.';

  @override
  String get manager_inbox_approve => 'Amohela';

  @override
  String get manager_inbox_request_changes => 'Kgopela diphetošo';

  @override
  String get manager_inbox_reject => 'Gana';

  @override
  String get manager_inbox_mark_all_as_read => 'Marka tšohle di badilwe';

  @override
  String get manager_inbox_view_goal => 'Lebelela sepheo';

  @override
  String get manager_inbox_view_badges => 'Lebelela dipheji';

  @override
  String get manager_inbox_all_priorities => 'Diprioriti tšohle';

  @override
  String get manager_review_nudge => 'Godiša';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Teboho';

  @override
  String get manager_review_activity => 'Modiro';

  @override
  String get manager_review_send => 'Romela';

  @override
  String get manager_review_schedule => 'Beakanya nako';

  @override
  String get manager_review_send_kudos => 'Romela teboho';

  @override
  String get manager_review_close => 'Tswalela';

  @override
  String get manager_review_check_authentication => 'Lekola netefatšo';

  @override
  String get season_management_title => 'Taolo ya sehla';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Laola $seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Oketša sehla';

  @override
  String get season_management_view_celebration => 'Lebelela moletlo';

  @override
  String get season_challenge_title => 'Tšhwaro ya sehla';

  @override
  String get team_challenges_create_season => 'Hlama sehla';

  @override
  String get team_challenges_view_details => 'Lebelela dintlha';

  @override
  String get team_challenges_manage => 'Laola';

  @override
  String get team_challenges_celebration => 'Moletlo';

  @override
  String get team_challenges_paused_only => 'Tše emišitšwego feela';

  @override
  String get season_details_not_found => 'Sehla ga se a hwetšwa';

  @override
  String get season_details_complete_season => 'Fediša sehla';

  @override
  String get season_details_extend_season => 'Oketša sehla';

  @override
  String get season_details_celebrate => 'Keteka';

  @override
  String get season_details_recompute => 'Balela gape';

  @override
  String get season_details_delete_season => 'Phumola sehla';

  @override
  String get season_details_force_complete_title =>
      'Na o nyaka go fediša sehla ka kgatelelo?';

  @override
  String get season_details_force_complete_confirm => 'Fediša ka kgatelelo';

  @override
  String get season_details_complete_title => 'Na o nyaka go fediša sehla?';

  @override
  String get season_details_complete_confirm => 'Fediša';

  @override
  String get season_details_delete_title => 'Na o nyaka go phumola sehla?';

  @override
  String get season_details_delete_confirm => 'Phumola';

  @override
  String get season_goal_completion_title => 'Fediša sepheo sa sehla';

  @override
  String get season_goal_completion_go_back => 'Boela morago';

  @override
  String get season_celebration_share => 'Abelana ka moletlo';

  @override
  String get season_celebration_create_new => 'Hlama sehla se sefsa';

  @override
  String get season_celebration_shared_success =>
      'Moletlo o abetšwe ka katlego!';

  @override
  String get employee_season_join => 'Tsena sehleng';

  @override
  String get employee_season_view_details => 'Lebelela dintlha';

  @override
  String get employee_season_complete_goals => 'Fediša dikgomo';

  @override
  String get employee_season_update => 'Ntšhafatša';

  @override
  String get employee_season_view_celebration => 'Lebelela moletlo';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'O tsenetše ka katlego \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Phoso ge o tsena sehleng: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'Ga go dikgomo tša sehla tša \"$seasonTitle\" gabjale.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Phoso ge go bulwa dintlha tsa sepheo: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'E rometšwe gore e amogelwe ke molaodi';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Phoso ge go romelwa bakeng sa tumelelo: $error';
  }

  @override
  String get goal_delete_title => 'Phumola Sepheo';

  @override
  String get goal_deleted => 'Sepheo se phumotšwe';

  @override
  String goal_delete_error(Object error) {
    return 'Phoso ge go phumulwa sepheo: $error';
  }

  @override
  String get goal_start_success =>
      'Sepheo se thomile! O hweditše diponto tše 20 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Phoso ge go thongwa sepheo: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Hle thoma sepheo pele o se fediša.';

  @override
  String get goal_complete_require_100 => 'Bea tswelopele go 100% go fediša.';

  @override
  String get goal_complete_success =>
      'Sepheo se feditšwe! O hweditše diponto tše 100 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Phoso ge go fedišwa sepheo: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Tswelopele e ntšhitšwe go $progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Phoso ge go ntšhafatšwa tswelopele: $error';
  }

  @override
  String get goal_set_to_100 => 'Bea go 100%';

  @override
  String get goal_submit_for_approval_title => 'Romela bakeng sa Tumelelo';

  @override
  String get goal_add_milestone => 'Oketša milestone';

  @override
  String get goal_milestone_requires_sign_in =>
      'O swanetše go tsena (sign in) go laola di-milestone.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Dikgomo tša go fetša ga di amogele di-milestone tše mpsha.';

  @override
  String get goal_milestone_title_required => 'Sehlogo se a nyakega.';

  @override
  String get goal_milestone_due_date_required => 'Kgetha letšatši la go fetša.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Phoso ge go bolokwa milestone: $error';
  }

  @override
  String get goal_milestone_deadline_hint =>
      'Tobetsa go kgetha letšatši la go fetša';

  @override
  String get goal_milestone_change => 'Fetola';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'E markilwe bjalo ka $status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Phoso ge go ntšhafatšwa milestone: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Phumola Milestone';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Na o nyaka go tloša milestone ye sepheng?';

  @override
  String get goal_milestone_deleted => 'Milestone e phumotšwe.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Phoso ge go phumulwa milestone: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Rulaganya dintlha';

  @override
  String get goal_milestone_mark_not_started => 'Marka bjalo ka ga se ya thoma';

  @override
  String get goal_milestone_mark_in_progress =>
      'Marka bjalo ka ya tswella pele';

  @override
  String get goal_milestone_mark_blocked => 'Marka bjalo ka e thibetšwe';

  @override
  String get goal_milestone_mark_completed => 'Marka bjalo ka e feditšwe';

  @override
  String get manager_team_workspace_create_team_goal =>
      'Thea sepheo sa sehlopha';

  @override
  String get manager_team_workspace_view_details => 'Sheba dintlha';

  @override
  String get manager_team_workspace_manage_team => 'Laola sehlopha';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Thea sepheo sa sehlopha';

  @override
  String get database_test_title => 'Tekolo ya database';

  @override
  String get database_test_add_goal => 'Eketsa sepheo';

  @override
  String get database_test_add_sample_goals => 'Eketsa mehlala ya dikgomo';

  @override
  String get employee_profile_detail_send_nudge => 'Romela kgothatšo';

  @override
  String get employee_profile_detail_schedule_meeting => 'Beakanya kopano';

  @override
  String get employee_profile_detail_give_recognition => 'Nea tlotlo';

  @override
  String get employee_profile_detail_assign_goal => 'abela sepheo';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Modiro o tla dirwa mo nakong e tlago';

  @override
  String get my_goal_workspace_suggest => 'Eletša';

  @override
  String get my_goal_workspace_generate => 'Hlama';

  @override
  String get my_goal_workspace_enter_goal_title =>
      'Ka kopo tsenya sehlogo sa sepheo';

  @override
  String get my_goal_workspace_select_target_date =>
      'Ka kopo kgetha letšatši leo o le lebanyago';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Phoso ge go thehwa sepheo: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Theha sepheo';

  @override
  String get team_chats_edit_message => 'Rulaganya molaetša';

  @override
  String get team_chats_delete_message_title => 'Phumola molaetša?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'Tiro ye e ka se boeletšwe morago.';

  @override
  String get gamification_title => 'Gamification';

  @override
  String get gamification_content => 'Dikagare tša skrine sa Gamification';

  @override
  String get my_pdp_ok => 'Go lokile';

  @override
  String get my_pdp_upload_file => 'Uplaotha faele (PDF/Word/Seswantšho)';

  @override
  String get my_pdp_save_note_link => 'Boloka tlhako/sekopano';

  @override
  String get my_pdp_change_evidence => 'Fetola bopaki';

  @override
  String get my_pdp_go_to_settings => 'Eya go Di-Settings';

  @override
  String get my_pdp_add_session => '+1 session';

  @override
  String get my_pdp_module_complete => 'Mojulu o feditšwe';

  @override
  String get role_access_restricted_title => 'Phihlelelo e Lekantšwego';

  @override
  String role_access_restricted_body(Object role) {
    return 'Karolo ya gago ($role) ga e na tumelelo ya letlakala le.';
  }

  @override
  String get role_go_to_my_portal => 'Eya portal ya ka';

  @override
  String get evidence_sign_in_required =>
      'Ka kopo tsena go bona bopaki bja gago.';

  @override
  String get evidence_sort_by_date => 'Rulaganya ka letšatši';

  @override
  String get evidence_sort_by_title => 'Rulaganya ka sehlogo';

  @override
  String get evidence_no_evidence_found => 'Ga go bopaki bjo hweditšwego.';

  @override
  String get evidence_dialog_title => 'Bopaki';

  @override
  String get employee_profile_remove_photo => 'Tloša foto';

  @override
  String get employee_profile_login_required_remove_photo =>
      'O swanetše go tsena go tloša foto ya gago.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Phoso ge go tlošwa foto: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'O swanetše go tsena go uplaotha foto.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Phoso ge go uplaothwa foto: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'O swanetše go tsena go boloka profaele ya gago.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Phoso ge go bolokwa profaele: $error';
  }

  @override
  String get employee_drawer_exit => 'Etšwa';

  @override
  String get progress_visuals_error_loading_user_data =>
      'Phoso ge go laišwa data ya modiriši';

  @override
  String get progress_visuals_all_departments => 'Dikgaolo tšohle';

  @override
  String get progress_visuals_send_nudge => 'Romela kgothatšo';

  @override
  String get progress_visuals_meet => 'Kopano';

  @override
  String get progress_visuals_view_details => 'Sheba dintlha';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Kgothatšo e rometšwe go $employeeName';
  }

  @override
  String get progress_visuals_debug_information =>
      'Tshedimošo ya go lokiša diphoso';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Phoso ya debug: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'Maikutlo a AI';

  @override
  String get alerts_nudges_ai_assistant => 'Mothuši wa AI';

  @override
  String get alerts_nudges_refresh => 'Ntšhafatša';

  @override
  String get alerts_nudges_create_first_goal => 'Theha sepheo sa gago sa pele';

  @override
  String get alerts_nudges_dismiss => 'Tlohela';

  @override
  String get alerts_nudges_copy => 'Kopela';

  @override
  String get alerts_nudges_edit => 'Hlophisa';

  @override
  String get manager_alerts_add_reschedule_note =>
      'Eketsa temoso ya go rulaganya gape';

  @override
  String get manager_alerts_skip => 'Fetola godimo';

  @override
  String get manager_alerts_save => 'Boloka';

  @override
  String get manager_alerts_reject_goal => 'Gana sepheo';

  @override
  String get manager_alerts_ai_team_insights => 'Maikutlo a sehlopha a AI';

  @override
  String get manager_alerts_all_priorities => 'Diprioriti tšohle';

  @override
  String get manager_alerts_review_goal => 'Hlahloba sepheo';

  @override
  String get manager_alerts_reschedule => 'Rulaganya nako gape';

  @override
  String get manager_alerts_extend_deadline => 'Atolosa letsatsi la mafelelo';

  @override
  String get manager_alerts_pause_goal => 'Emiša sepheo nakwana';

  @override
  String get manager_alerts_mark_burnout => 'Marka go fela maatla';

  @override
  String get manager_alerts_select_goal_hint => 'Kgetha sepheo';

  @override
  String get manager_alerts_send_bulk_nudge => 'Romela dikgothatšo tše dintši';

  @override
  String get manager_alerts_send_to_all => 'Romela go bohle';

  @override
  String get notifications_bell_ok => 'Go lokile';

  @override
  String get landing_app_title => 'Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}
