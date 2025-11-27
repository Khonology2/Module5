// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Afrikaans (`af`).
class AppLocalizationsAf extends AppLocalizations {
  AppLocalizationsAf([String locale = 'af']) : super(locale);

  @override
  String get app_title => 'Personal Development Hub';

  @override
  String get language_updated => 'Taalinstelling is opgedateer';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Kanselleer';

  @override
  String get close => 'Sluit';

  @override
  String get retry => 'Probeer weer';

  @override
  String get save => 'Stoor';

  @override
  String get delete => 'Vee uit';

  @override
  String get create => 'Skep';

  @override
  String get submit => 'Dien in';

  @override
  String get view => 'Bekyk';

  @override
  String get details => 'Besonderhede';

  @override
  String get settings_go_to => 'Gaan na Instellings';

  @override
  String get sign_out => 'Meld af';

  @override
  String get delete_account => 'Skrap rekening';

  @override
  String get export_my_data => 'Voer my data uit';

  @override
  String get send_password_reset_email => 'Stuur wagwoord-herstel e-pos';

  @override
  String get language_english => 'Engels';

  @override
  String get language_spanish => 'Spaans';

  @override
  String get language_french => 'Frans';

  @override
  String get language_german => 'Duits';

  @override
  String get time_15_minutes => '15 minute';

  @override
  String get time_30_minutes => '30 minute';

  @override
  String get time_60_minutes => '1 uur';

  @override
  String get time_120_minutes => '2 uur';

  @override
  String get status_all => 'Alle statusse';

  @override
  String get status_verified => 'Geverifieer';

  @override
  String get status_pending => 'Hangend';

  @override
  String get status_rejected => 'Verwerp';

  @override
  String get audit_export_csv => 'Voer uit as CSV';

  @override
  String get audit_export_pdf => 'Voer uit as PDF';

  @override
  String get audit_submit_for_audit => 'Dien in vir oudit';

  @override
  String get audit_no_timeline_events_yet => 'Geen tydlyngebeurtenisse nog nie';

  @override
  String get dashboard_refresh_data => 'Verfris data';

  @override
  String get dashboard_recent_activity => 'Onlangse aktiwiteit';

  @override
  String get dashboard_quick_actions => 'Vinnige aksies';

  @override
  String get dashboard_upcoming_goals => 'Komende doelwitte';

  @override
  String get dashboard_add_goal => 'Voeg doelwit by';

  @override
  String get dashboard_awaiting_manager_approval =>
      'Wag op bestuurder se goedkeuring.';

  @override
  String get employee_create_first_goal => 'Skep jou eerste doelwit';

  @override
  String get manager_team_kpis => 'Span-KPI’s';

  @override
  String get manager_team_health => 'Spanwelstand';

  @override
  String get manager_activity_summary => 'Aktiwiteitsopsomming';

  @override
  String get manager_top_performers => 'Toppresteerders';

  @override
  String get manager_no_performers_yet => 'Geen presteerders nog nie';

  @override
  String get manager_quick_actions => 'Vinnige aksies';

  @override
  String get manager_complete_season => 'Voltooi seisoen';

  @override
  String manager_team_size(Object teamSize) {
    return 'Spangrootte: $teamSize';
  }

  @override
  String get team_goal_join_title => 'Sluit by Spandoel aan';

  @override
  String get team_goal_join_cancel => 'Kanselleer';

  @override
  String get team_goal_join_confirm => 'Sluit by span aan';

  @override
  String team_details_error(Object error) {
    return 'Fout: $error';
  }

  @override
  String get team_goal_not_found => 'Spandoel nie gevind nie.';

  @override
  String get manager_inbox_approve => 'Keur goed';

  @override
  String get manager_inbox_request_changes => 'Versoek wysigings';

  @override
  String get manager_inbox_reject => 'Verwerp';

  @override
  String get manager_inbox_mark_all_as_read => 'Merk alles as gelees';

  @override
  String get manager_inbox_view_goal => 'Bekyk doelwit';

  @override
  String get manager_inbox_view_badges => 'Bekyk kentekens';

  @override
  String get manager_inbox_all_priorities => 'Alle prioriteite';

  @override
  String get manager_review_nudge => 'Stootjie';

  @override
  String get manager_review_1_1 => '1:1';

  @override
  String get manager_review_kudos => 'Lof';

  @override
  String get manager_review_activity => 'Aktiwiteit';

  @override
  String get manager_review_send => 'Stuur';

  @override
  String get manager_review_schedule => 'Skeduleer';

  @override
  String get manager_review_send_kudos => 'Stuur lof';

  @override
  String get manager_review_close => 'Sluit';

  @override
  String get manager_review_check_authentication => 'Kontroleer verifikasie';

  @override
  String get season_management_title => 'Seisoenbestuur';

  @override
  String season_management_manage_title(Object seasonTitle) {
    return 'Bestuur $seasonTitle';
  }

  @override
  String get season_management_extend_season => 'Verleng seisoen';

  @override
  String get season_management_view_celebration => 'Bekyk viering';

  @override
  String get season_challenge_title => 'Seisoenuitdaging';

  @override
  String get team_challenges_create_season => 'Skep seisoen';

  @override
  String get team_challenges_view_details => 'Bekyk besonderhede';

  @override
  String get team_challenges_manage => 'Bestuur';

  @override
  String get team_challenges_celebration => 'Viering';

  @override
  String get team_challenges_paused_only => 'Net gepouseer';

  @override
  String get season_details_not_found => 'Seisoen nie gevind nie';

  @override
  String get season_details_complete_season => 'Voltooi seisoen';

  @override
  String get season_details_extend_season => 'Verleng seisoen';

  @override
  String get season_details_celebrate => 'Vier';

  @override
  String get season_details_recompute => 'Herbereken';

  @override
  String get season_details_delete_season => 'Skrap seisoen';

  @override
  String get season_details_force_complete_title => 'Voltooi seisoen forto?';

  @override
  String get season_details_force_complete_confirm => 'Voltooi';

  @override
  String get season_details_complete_title => 'Seisoen voltooi?';

  @override
  String get season_details_complete_confirm => 'Voltooi';

  @override
  String get season_details_delete_title => 'Skrap seisoen?';

  @override
  String get season_details_delete_confirm => 'Skrap';

  @override
  String get season_goal_completion_title => 'Voltooi Seisoendoelwit';

  @override
  String get season_goal_completion_go_back => 'Gaan terug';

  @override
  String get season_celebration_share => 'Deel viering';

  @override
  String get season_celebration_create_new => 'Skep nuwe seisoen';

  @override
  String get season_celebration_shared_success => 'Viering gedeel!';

  @override
  String get employee_season_join => 'Sluit by seisoen aan';

  @override
  String get employee_season_view_details => 'Bekyk besonderhede';

  @override
  String get employee_season_complete_goals => 'Voltooi doelwitte';

  @override
  String get employee_season_update => 'Werk by';

  @override
  String get employee_season_view_celebration => 'Bekyk viering';

  @override
  String employee_season_joined_success(Object seasonTitle) {
    return 'Suksesvol aangesluit by \"$seasonTitle\"!';
  }

  @override
  String employee_season_join_error(Object error) {
    return 'Fout met aansluiting by seisoen: $error';
  }

  @override
  String employee_season_no_goals(Object seasonTitle) {
    return 'Geen seisoendoelwitte vir \"$seasonTitle\" nog nie.';
  }

  @override
  String employee_season_open_details_error(Object error) {
    return 'Kon nie doelwitbesonderhede oopmaak nie: $error';
  }

  @override
  String get goal_submit_for_approval_snackbar =>
      'Ingedien vir bestuurdergoedkeuring';

  @override
  String goal_submit_for_approval_error(Object error) {
    return 'Kon nie vir goedkeuring indien nie: $error';
  }

  @override
  String get goal_delete_title => 'Skrap Doelwit';

  @override
  String get goal_deleted => 'Doelwit geskrap';

  @override
  String goal_delete_error(Object error) {
    return 'Kon nie doelwit skrap nie: $error';
  }

  @override
  String get goal_start_success => 'Doelwit begin! +20 punte verdien 🎉';

  @override
  String goal_start_error(Object error) {
    return 'Fout met begin van doelwit: $error';
  }

  @override
  String get goal_complete_require_start =>
      'Begin die doelwit voordat jy dit voltooi.';

  @override
  String get goal_complete_require_100 =>
      'Stel vordering op 100% om te voltooi.';

  @override
  String get goal_complete_success => 'Doelwit voltooi! +100 punte verdien 🏆';

  @override
  String goal_complete_error(Object error) {
    return 'Fout met voltooi van doelwit: $error';
  }

  @override
  String goal_progress_updated(Object progress) {
    return 'Vordering opgedateer na $progress%';
  }

  @override
  String goal_progress_update_error(Object error) {
    return 'Kon nie vordering opdateer nie: $error';
  }

  @override
  String get goal_set_to_100 => 'Stel op 100%';

  @override
  String get goal_submit_for_approval_title => 'Dien vir Goedkeuring In';

  @override
  String get goal_add_milestone => 'Voeg MyIpaal by';

  @override
  String get goal_milestone_requires_sign_in =>
      'Jy moet aangemeld wees om mylpale te bestuur.';

  @override
  String get goal_milestone_no_new_on_completed =>
      'Voltooide doelwitte kan nie nuwe mylpale kry nie.';

  @override
  String get goal_milestone_title_required => 'Titel is verpligtend.';

  @override
  String get goal_milestone_due_date_required => 'Kies \'n sperdatum.';

  @override
  String goal_milestone_save_error(Object error) {
    return 'Kon nie mylpaal stoor nie: $error';
  }

  @override
  String get goal_milestone_deadline_hint => 'Tik om sperdatum te kies';

  @override
  String get goal_milestone_change => 'Verander';

  @override
  String goal_milestone_marked_as(Object status) {
    return 'Gemerk as $status.';
  }

  @override
  String goal_milestone_update_error(Object error) {
    return 'Kon nie mylpaal bywerk nie: $error';
  }

  @override
  String get goal_milestone_delete_title => 'Skrap Mylpaal';

  @override
  String get goal_milestone_delete_confirm_text =>
      'Verwyder hierdie mylpaal van die doelwit?';

  @override
  String get goal_milestone_deleted => 'Mylpaal geskrap.';

  @override
  String goal_milestone_delete_error(Object error) {
    return 'Kon nie mylpaal skrap nie: $error';
  }

  @override
  String get goal_milestone_edit_details => 'Wysig besonderhede';

  @override
  String get goal_milestone_mark_not_started => 'Merk Nie Begin nie';

  @override
  String get goal_milestone_mark_in_progress => 'Merk In proses';

  @override
  String get goal_milestone_mark_blocked => 'Merk Geblokkeer';

  @override
  String get goal_milestone_mark_completed => 'Merk Voltooi';

  @override
  String get manager_team_workspace_create_team_goal => 'Skep Spandoelwit';

  @override
  String get manager_team_workspace_view_details => 'Bekyk besonderhede';

  @override
  String get manager_team_workspace_manage_team => 'Bestuur span';

  @override
  String get manager_team_workspace_dialog_create_team_goal =>
      'Skep Spandoelwit';

  @override
  String get database_test_title => 'Databasis Toets';

  @override
  String get database_test_add_goal => 'Voeg doelwit by';

  @override
  String get database_test_add_sample_goals => 'Voeg voorbeeld-doelwitte by';

  @override
  String get employee_profile_detail_send_nudge => 'Stuur Stootjie';

  @override
  String get employee_profile_detail_schedule_meeting =>
      'Skeduleer Vergadering';

  @override
  String get employee_profile_detail_give_recognition => 'Gee Erkenning';

  @override
  String get employee_profile_detail_assign_goal => 'Ken Doelwit Toe';

  @override
  String get employee_profile_detail_dialog_placeholder =>
      'Funksionaliteit sal hier geïmplementeer word';

  @override
  String get my_goal_workspace_suggest => 'Stel voor';

  @override
  String get my_goal_workspace_generate => 'Genereer';

  @override
  String get my_goal_workspace_enter_goal_title => 'Voer \'n doelwittitel in';

  @override
  String get my_goal_workspace_select_target_date => 'Kies \'n teikendatum';

  @override
  String my_goal_workspace_create_goal_error(Object error) {
    return 'Kon nie doelwit skep nie: $error';
  }

  @override
  String get my_goal_workspace_create_goal => 'Skep Doelwit';

  @override
  String get team_chats_edit_message => 'Wysig boodskap';

  @override
  String get team_chats_delete_message_title => 'Skrap boodskap?';

  @override
  String get team_chats_delete_message_confirm_text =>
      'Hierdie aksie kan nie ontdoen word nie.';

  @override
  String get gamification_title => 'Gamifikasie';

  @override
  String get gamification_content => 'Gamifikasie Skerm Inhoud';

  @override
  String get my_pdp_ok => 'OK';

  @override
  String get my_pdp_upload_file => 'Laai lêer op (PDF/Woord/Prent)';

  @override
  String get my_pdp_save_note_link => 'Stoor nota/skakel';

  @override
  String get my_pdp_change_evidence => 'Verander Bewys';

  @override
  String get my_pdp_go_to_settings => 'Gaan na Instellings';

  @override
  String get my_pdp_add_session => '+1 sessie';

  @override
  String get my_pdp_module_complete => 'Module voltooi';

  @override
  String get role_access_restricted_title => 'Toegang Beperk';

  @override
  String role_access_restricted_body(Object role) {
    return 'Jou rol ($role) het nie toegang tot hierdie bladsy nie.';
  }

  @override
  String get role_go_to_my_portal => 'Gaan na my portaal';

  @override
  String get evidence_sign_in_required =>
      'Meld asseblief aan om jou bewyse te sien.';

  @override
  String get evidence_sort_by_date => 'Sorteer volgens Datum';

  @override
  String get evidence_sort_by_title => 'Sorteer volgens Titel';

  @override
  String get evidence_no_evidence_found => 'Geen bewyse gevind nie.';

  @override
  String get evidence_dialog_title => 'Bewyse';

  @override
  String get employee_profile_remove_photo => 'Verwyder Foto';

  @override
  String get employee_profile_login_required_remove_photo =>
      'Jy moet aangemeld wees om jou foto te verwyder.';

  @override
  String employee_profile_remove_photo_fail(Object error) {
    return 'Kon nie foto verwyder nie: $error';
  }

  @override
  String get employee_profile_login_required_upload_photo =>
      'Jy moet aangemeld wees om \'n foto op te laai.';

  @override
  String employee_profile_upload_photo_fail(Object error) {
    return 'Kon nie foto oplaai nie: $error';
  }

  @override
  String get employee_profile_login_required_save_profile =>
      'Jy moet aangemeld wees om jou profiel te stoor.';

  @override
  String employee_profile_save_profile_fail(Object error) {
    return 'Kon nie profiel stoor nie: $error';
  }

  @override
  String get employee_drawer_exit => 'Verlaat';

  @override
  String get nav_dashboard => 'Paneelbord';

  @override
  String get nav_goal_workspace => 'Doelwit-werksruimte';

  @override
  String get nav_my_profile => 'My Profiel';

  @override
  String get nav_my_pdp => 'MyPdp';

  @override
  String get nav_progress_visuals => 'Vorderingsvisualisasies';

  @override
  String get nav_alerts_nudges => 'Kennisgewings & Stootjies';

  @override
  String get nav_badges_points => 'Kentekens & Punte';

  @override
  String get nav_season_challenges => 'Seisoen-uitdagings';

  @override
  String get nav_leaderboard => 'Ranglys';

  @override
  String get nav_repository_audit => 'Bewaarplek & Oudit';

  @override
  String get nav_settings_privacy => 'Instellings & Privaatheid';

  @override
  String get nav_team_challenges => 'Spanutdagings';

  @override
  String get nav_team_alerts_nudges => 'Span-kennisgewings & Stootjies';

  @override
  String get nav_manager_inbox => 'Posbus';

  @override
  String get nav_review_team => 'Hersien span';

  @override
  String get nav_admin_dashboard => 'Admin-paneelbord';

  @override
  String get nav_user_management => 'Gebruikerbestuur';

  @override
  String get nav_analytics => 'Analitiese data';

  @override
  String get nav_system_settings => 'Stelselinstellings';

  @override
  String get nav_security => 'Sekuriteit';

  @override
  String get nav_backup_restore => 'Rugsteun & Herstel';

  @override
  String get employee_portal_title => 'Werknemerportaal';

  @override
  String get progress_visuals_error_loading_user_data =>
      'Fout met laai van gebruikersdata';

  @override
  String get progress_visuals_all_departments => 'Alle Afdelings';

  @override
  String get progress_visuals_send_nudge => 'Stuur Stootjie';

  @override
  String get progress_visuals_meet => 'Ontmoet';

  @override
  String get progress_visuals_view_details => 'Bekyk Besonderhede';

  @override
  String progress_visuals_nudge_sent(Object employeeName) {
    return 'Stootjie gestuur na $employeeName';
  }

  @override
  String get progress_visuals_debug_information => 'Ontfout Inligting';

  @override
  String progress_visuals_debug_error(Object error) {
    return 'Ontfout Fout: $error';
  }

  @override
  String get progress_visuals_ai_insights => 'AI-insigte';

  @override
  String get alerts_nudges_ai_assistant => 'AI-assistent';

  @override
  String get alerts_nudges_refresh => 'Verfris';

  @override
  String get alerts_nudges_create_first_goal => 'Skep jou eerste doelwit';

  @override
  String get alerts_nudges_dismiss => 'Verwyder';

  @override
  String get alerts_nudges_copy => 'Kopieer';

  @override
  String get alerts_nudges_edit => 'Wysig';

  @override
  String get manager_alerts_add_reschedule_note => 'Voeg Herskeduleer-nota by';

  @override
  String get manager_alerts_skip => 'Slaan oor';

  @override
  String get manager_alerts_save => 'Stoor';

  @override
  String get manager_alerts_reject_goal => 'Verwerp Doelwit';

  @override
  String get manager_alerts_ai_team_insights => 'AI-spaninsigte';

  @override
  String get manager_alerts_all_priorities => 'Alle Prioriteite';

  @override
  String get manager_alerts_review_goal => 'Evalueer Doelwit';

  @override
  String get manager_alerts_reschedule => 'Herskeduleer';

  @override
  String get manager_alerts_extend_deadline => 'Verleng Spertyd';

  @override
  String get manager_alerts_pause_goal => 'Pouseer Doelwit';

  @override
  String get manager_alerts_mark_burnout => 'Merk Uitbranding';

  @override
  String get manager_alerts_select_goal_hint => 'Kies Doelwit';

  @override
  String get manager_alerts_send_bulk_nudge => 'Stuur Massa-stootjie';

  @override
  String get manager_alerts_send_to_all => 'Stuur na Almal';

  @override
  String get notifications_bell_ok => 'OK';

  @override
  String get landing_app_title => 'Personal Development Hub';

  @override
  String greeting_user(Object greeting, Object userName) {
    return '$greeting, $userName!';
  }
}
