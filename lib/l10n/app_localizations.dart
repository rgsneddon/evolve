import '../models/locale_config.dart';
import '../services/scenario_input_profile.dart';
import '../services/scenario_lean_context.dart';
import 'discourse_strings.dart';
import 'part_three_slim_strings.dart';
import 'analysis_ui_strings.dart';
import 'fcg_strings.dart';
import 'results_ui_strings.dart';
import 'wallet_strings.dart';
import 'weight_construal_strings.dart';

/// Lightweight i18n — language UI strings + regional agent role labels.
class AppLocalizations {
  AppLocalizations(this.config);

  final LocaleConfig config;

  String get languageCode => config.languageCode;
  String get regionId => config.regionId;

  static AppLocalizations of(LocaleConfig config) => AppLocalizations(config);

  String t(String key) => (_ui[languageCode] ?? _ui['en']!)[key] ?? key;

  String agentRole(String roleKey, String region) {
    final global = _agents['global']!;
    return _agents[region]?[roleKey] ?? global[roleKey] ?? global['lead_authority']!;
  }

  String part3HeadlinePercent(String agent) =>
      t('part3_headline_pct').replaceAll('{agent}', agent);

  String part3HeadlineCohesion(String agent) =>
      t('part3_headline_scs').replaceAll('{agent}', agent);

  String part3TargetPercent(int current, int projected, String subject) =>
      t('part3_target_pct')
          .replaceAll('{current}', '$current')
          .replaceAll('{projected}', '$projected')
          .replaceAll('{subject}', subject);

  String part3TargetScs(int current, int min, int max, String subject) =>
      t('part3_target_scs')
          .replaceAll('{current}', '$current')
          .replaceAll('{min}', '$min')
          .replaceAll('{max}', '$max')
          .replaceAll('{subject}', subject);

  String part3ImpactPercent(int current, int projected, String subject) =>
      t('part3_impact_pct')
          .replaceAll('{current}', '$current')
          .replaceAll('{projected}', '$projected')
          .replaceAll('{subject}', subject);

  String part3ImpactScs(int current, int min, int max) =>
      t('part3_impact_scs')
          .replaceAll('{current}', '$current')
          .replaceAll('{min}', '$min')
          .replaceAll('{max}', '$max');

  String part3Context(String agent, ScenarioInputProfile profile) =>
      t('part3_context')
          .replaceAll('{agent}', agent)
          .replaceAll('{subject}', profile.subject)
          .replaceAll('{binding}', profile.bindingSummary);

  String part3InputBinding(ScenarioInputProfile profile) =>
      t('part3_input_binding').replaceAll('{binding}', profile.bindingSummary);

  List<String> part3Actions(String agent, ScenarioInputProfile profile) => [
        _part3Action('part3_action_1', agent, profile),
        _part3Action('part3_action_2', agent, profile),
        _part3Action('part3_action_3', agent, profile),
      ];

  String _part3Action(String key, String agent, ScenarioInputProfile profile) =>
      t(key)
          .replaceAll('{agent}', agent)
          .replaceAll('{subject}', profile.subject)
          .replaceAll('{topic_suffix}', profile.topicSuffix)
          .replaceAll('{shear_hook}', profile.shearHook)
          .replaceAll('{resistance_hook}', profile.resistanceHook)
          .replaceAll('{flow_hook}', profile.flowHook);

  String constructName(String key) => t('construct_${key}_name');

  String constructHint(String key) => t('construct_${key}_hint');

  String part3HeadlinePercentMitigate(String agent) =>
      t('part3_headline_pct_mitigate').replaceAll('{agent}', agent);

  String part3HeadlinePercentSupport(String agent) =>
      t('part3_headline_pct_support').replaceAll('{agent}', agent);

  String part3HeadlineCohesionMitigate(String agent) =>
      t('part3_headline_scs_mitigate').replaceAll('{agent}', agent);

  String part3HeadlineCohesionSupport(String agent) =>
      t('part3_headline_scs_support').replaceAll('{agent}', agent);

  String part3TargetPercentMitigate(int current, int projected, String subject) =>
      t('part3_target_pct_mitigate')
          .replaceAll('{current}', '$current')
          .replaceAll('{projected}', '$projected')
          .replaceAll('{subject}', subject);

  String part3TargetPercentSupport(int current, int projected, String subject) =>
      t('part3_target_pct_support')
          .replaceAll('{current}', '$current')
          .replaceAll('{projected}', '$projected')
          .replaceAll('{subject}', subject);

  String part3TargetScsMitigate(int current, int min, int max, String subject) =>
      t('part3_target_scs_mitigate')
          .replaceAll('{current}', '$current')
          .replaceAll('{min}', '$min')
          .replaceAll('{max}', '$max')
          .replaceAll('{subject}', subject);

  String part3TargetScsSupport(int current, int min, int max, String subject) =>
      t('part3_target_scs_support')
          .replaceAll('{current}', '$current')
          .replaceAll('{min}', '$min')
          .replaceAll('{max}', '$max')
          .replaceAll('{subject}', subject);

  String part3ImpactPercentMitigate(int current, int projected, String subject) =>
      t('part3_impact_pct_mitigate')
          .replaceAll('{current}', '$current')
          .replaceAll('{projected}', '$projected')
          .replaceAll('{subject}', subject);

  String part3ImpactPercentSupport(int current, int projected, String subject) =>
      t('part3_impact_pct_support')
          .replaceAll('{current}', '$current')
          .replaceAll('{projected}', '$projected')
          .replaceAll('{subject}', subject);

  String part3ImpactScsMitigate(int current, int min, int max) =>
      t('part3_impact_scs_mitigate')
          .replaceAll('{current}', '$current')
          .replaceAll('{min}', '$min')
          .replaceAll('{max}', '$max');

  String part3ImpactScsSupport(int current, int min, int max) =>
      t('part3_impact_scs_support')
          .replaceAll('{current}', '$current')
          .replaceAll('{min}', '$min')
          .replaceAll('{max}', '$max');

  String part3SlimHeadlineScs(String agent) =>
      t('part3_slim_headline_scs').replaceAll('{agent}', agent);

  String part3SlimHeadlinePct(String agent) =>
      t('part3_slim_headline_pct').replaceAll('{agent}', agent);

  String part3SlimTargetScs(int current, int min, int max) => t('part3_slim_target_scs')
      .replaceAll('{current}', '$current')
      .replaceAll('{min}', '$min')
      .replaceAll('{max}', '$max');

  String part3SlimTargetPct(int current, int projected, ScenarioLeanContext leanCtx) {
    final key = leanCtx.mitigateScenario
        ? 'part3_slim_target_pct_shift'
        : 'part3_slim_target_pct_build';
    return t(key)
        .replaceAll('{current}', '$current')
        .replaceAll('{projected}', '$projected');
  }

  String part3SlimImpactScs(int min, int max) => t('part3_slim_impact_scs')
      .replaceAll('{min}', '$min')
      .replaceAll('{max}', '$max');

  String part3SlimImpactPct() => t('part3_slim_impact_pct');

  String part3SlimLeanLine(
    ScenarioLeanContext leanCtx,
    String subject,
    String regionId,
  ) =>
      t('part3_slim_lean_line')
          .replaceAll('{lean}', leanCtx.leanLabel(this))
          .replaceAll('{region}', t('region_$regionId'))
          .replaceAll('{reg}', '${leanCtx.regressivePct.round()}')
          .replaceAll('{prog}', '${leanCtx.progressivePct.round()}')
          .replaceAll('{subject}', subject);

  static const _agents = <String, Map<String, String>>{
    'global': {
      'lead_authority': 'lead public authority',
      'mayor': 'mayor',
      'governor': 'governor',
      'minister': 'minister',
      'president': 'president',
      'prime_minister': 'prime minister',
      'first_minister': 'first minister',
      'chief_executive': 'chief executive',
      'director_general': 'director-general',
      'commissioner': 'commissioner',
      'prefect': 'prefect',
      'governor_general': 'governor-general',
      'council': 'local council',
      'parliament': 'parliament',
      'senate': 'senate',
      'assembly': 'legislative assembly',
      'authority': 'public authority',
      'agency': 'government agency',
    },
    'usa': {
      'lead_authority': 'elected federal official',
      'mayor': 'mayor',
      'governor': 'state governor',
      'minister': 'cabinet secretary',
      'president': 'president',
      'senator': 'senator',
      'congress': 'member of Congress',
      'council': 'city council',
      'assembly': 'state legislature',
    },
    'americas': {
      'lead_authority': 'elected public official',
      'mayor': 'mayor',
      'governor': 'state governor',
      'minister': 'cabinet secretary',
      'president': 'president',
      'prime_minister': 'prime minister',
      'council': 'city council',
      'senate': 'senator',
      'assembly': 'state legislature',
    },
    'europe': {
      'lead_authority': 'elected representative',
      'mayor': 'mayor',
      'minister': 'minister',
      'prime_minister': 'prime minister',
      'council': 'municipal council',
      'parliament': 'member of parliament',
      'assembly': 'regional assembly',
    },
    'uk_ireland': {
      'lead_authority': 'public office-holder',
      'mayor': 'mayor',
      'minister': 'minister',
      'first_minister': 'first minister',
      'prime_minister': 'prime minister',
      'council': 'local council',
      'parliament': 'MP',
    },
    'mena': {
      'lead_authority': 'senior public official',
      'mayor': 'mayor',
      'governor': 'governor',
      'minister': 'minister',
      'president': 'president',
      'authority': 'government authority',
    },
    'sub_saharan_africa': {
      'lead_authority': 'public office-holder',
      'mayor': 'mayor',
      'minister': 'minister',
      'president': 'president',
      'governor': 'regional governor',
      'assembly': 'national assembly',
    },
    'south_asia': {
      'lead_authority': 'public office-holder',
      'mayor': 'mayor',
      'minister': 'minister',
      'chief_executive': 'chief minister',
      'governor': 'governor',
      'commissioner': 'district commissioner',
    },
    'east_asia': {
      'lead_authority': 'public office-holder',
      'mayor': 'mayor',
      'governor': 'governor',
      'minister': 'minister',
      'prefect': 'prefect',
      'director_general': 'director-general',
    },
    'southeast_asia': {
      'lead_authority': 'public office-holder',
      'mayor': 'mayor',
      'minister': 'minister',
      'governor': 'governor',
      'agency': 'government agency',
    },
    'oceania': {
      'lead_authority': 'public office-holder',
      'mayor': 'mayor',
      'minister': 'minister',
      'premier': 'premier',
      'governor_general': 'governor-general',
      'council': 'local council',
    },
  };

  static final _ui = <String, Map<String, String>>{
    'en': _en,
    'es': _es,
    'fr': _fr,
    'de': _de,
    'pt': _pt,
    'ar': _ar,
    'zh': _zh,
    'hi': _hi,
    'ja': _ja,
  };
}

final _en = {
  'app_title': 'Evolve',
  'app_subtitle': 'Social Science Chronoflux Framework',
  'splash_tagline': 'Full Community Governance Suite',
  'nav_analysis': 'Analysis',
  'nav_wallet': 'Wallet',
  'nav_voting': 'Voting',
  'nav_credit': 'Credit',
  'fcg_title': 'Parish council voting',
  'fcg_subtitle':
      'Full Community Governance (FCG) ward voting for {region} — social cohesion narratives from your prior scenario runs.',
  'fcg_governance_blurb':
      'SSUCF parish council voting uses Chronoflux cohesion narratives to structure ward policy debate.',
  'fcg_read_paper': 'FCG white paper',
  'fcg_moderator_title': 'Ward moderator',
  'fcg_moderator_account_hint':
      'Register a PERC wallet as Moderator (see your Ward Moderator Pack for Instructions) to initiate votes and manage parish voter accounts.',
  'fcg_signed_in_as': 'Signed in as {user}',
  'fcg_moderator_sign_in_hint':
      'Sign in with a MOD_* ward account on the Wallet tab to administer voting.',
  'fcg_initiate_title': 'Initiate parish vote',
  'fcg_policy_question': 'Policy question',
  'fcg_policy_question_hint':
      'e.g. Should the parish adopt the proposed flood resilience levy?',
  'fcg_analysis_modes': 'Chronoflux analysis for this policy',
  'fcg_run_cohesion': 'Social cohesion score (SCS)',
  'fcg_run_percent': 'Percent chance',
  'fcg_initiate_button': 'Open vote & run analysis',
  'fcg_initiate_moderator_only': 'Only a signed-in MOD_* ward moderator can open a vote.',
  'fcg_active_session': 'Active parish vote',
  'fcg_cohesion_score': 'SCS ~{scs}/100',
  'fcg_percent_chance': '{pct}% chance',
  'fcg_votes_cast': '{cast}/{total} votes cast',
  'fcg_vote_support': 'Support',
  'fcg_vote_oppose': 'Oppose',
  'fcg_vote_abstain': 'Abstain',
  'fcg_session_narrative': 'Linked cohesion narrative',
  'fcg_narrative_picker_title': 'Prior scenario narratives',
  'fcg_narrative_picker_hint':
      'Pull social cohesion text from your previous Analysis tab runs for this ward region.',
  'fcg_link_narrative': 'Link',
  'fcg_narrative_linked': 'Linked',
  'fcg_no_narratives':
      'No prior scenario runs for this region yet — complete analyses on the Analysis tab first.',
  'fcg_admin_panel_title': 'Moderator admin — enroll voters',
  'fcg_admin_panel_hint':
      'Add each parish voter\'s PERC address to slots 1–30. Once committed, that wallet may cast one ballot.',
  'fcg_perc_address': 'PERC wallet address',
  'fcg_perc_address_hint': 'percpriv1…',
  'fcg_commit_address': 'Commit',
  'fcg_clear_address': 'Clear',
  'fcg_slot_label': 'Slot',
  'fcg_slot_empty': 'Awaiting address',
  'fcg_slot_enrolled': 'Enrolled',
  'fcg_slot_roster_title': 'Voter slot roster',
  'fcg_slot_roster_public_hint':
      'Your ward moderator enrolls PERC addresses before you can vote.',
  'fcg_enrolled_count': '{enrolled}/{total} slots enrolled',
  'fcg_your_ballot_title': 'Your ballot (slot {slot})',
  'fcg_your_ballot_hint':
      'You are enrolled for this parish vote. Cast one ballot on the policy question below.',
  'fcg_ballot_recorded': 'Ballot recorded: {choice}',
  'fcg_not_enrolled_hint':
      'Your PERC address is not enrolled yet. Ask the ward MOD_* moderator to commit your wallet address to a voter slot.',
  'fcg_voter_narrative': 'Optional cohesion narrative',
  'fcg_no_narrative': 'No linked narrative',
  'fcg_address_committed': 'PERC address committed to voter slot.',
  'fcg_address_cleared': 'Voter slot cleared.',
  'fcg_vote_recorded': 'Your ballot has been recorded.',
  'fcg_wallet_not_enrolled': 'Your PERC wallet is not enrolled in this vote.',
  'fcg_no_active_vote': 'No active parish vote.',
  'fcg_invalid_slot': 'Invalid voter slot.',
  'fcg_invalid_perc_address': 'Enter a valid PERC wallet address.',
  'fcg_address_already_enrolled': 'That PERC address is already enrolled in another slot.',
  'fcg_slot_already_enrolled': 'This slot already has a committed address. Release it first.',
  'fcg_address_reenrolled': 'PERC address re-enrolled on voter slot.',
  'fcg_slot_released': 'Voter slot released for re-enrollment.',
  'fcg_release_slot': 'Release',
  'fcg_reenroll_address': 'Re-enroll',
  'fcg_results_dashboard': 'Live results dashboard',
  'fcg_quorum_participation':
      'Participation {pct}% (quorum {threshold}%) — {met}',
  'fcg_quorum_met_yes': 'quorum met',
  'fcg_quorum_met_no': 'quorum not met',
  'fcg_deciding_votes': '{count} deciding votes',
  'fcg_support_share': 'Support share of deciding votes: {pct}%',
  'fcg_outcome_pass': 'Outcome: PASS',
  'fcg_outcome_fail': 'Outcome: FAIL',
  'fcg_outcome_tie': 'Outcome: TIE',
  'fcg_outcome_no_quorum': 'Outcome: awaiting quorum',
  'fcg_outcome_pending': 'Outcome: voting in progress',
  'fcg_export_copy_md': 'Copy Markdown',
  'fcg_export_copy_json': 'Copy JSON',
  'fcg_export_save_md': 'Save Markdown',
  'fcg_export_copied_md': 'Pilot Markdown copied',
  'fcg_export_copied_json': 'Pilot JSON copied',
  'fcg_export_saved': 'Pilot results saved',
  'fcg_audit_log_title': 'Immutable audit log ({count})',
  'fcg_audit_log_hint':
      'Append-only hash chain — every commit, release, re-enrollment, and ballot.',
  'fcg_audit_chain_tip': 'Chain tip: {hash}…',
  'fcg_audit_empty': 'No audit entries yet.',
  'fcg_close_session': 'Close vote',
  'fcg_history_title': 'Scenario run library',
  'fcg_history_hint':
      'Cohesion narratives saved automatically when you calculate on the Analysis tab.',
  'fcg_history_empty': 'No saved runs for this ward region yet.',
  'fcg_cancel': 'Cancel',
  'fcg_analyzing_policy': 'Running Chronoflux policy analysis…',
  'fcg_session_started': 'Parish vote opened — assign voter ballots below.',
  'fcg_narrative_linked': 'Cohesion narrative linked to this vote.',
  'fcg_voter_added': 'Voter account added.',
  'fcg_voter_removed': 'Voter account removed.',
  'fcg_voters_reset': 'Voter list reset to 30 placeholders.',
  'fcg_session_closed': 'Parish vote closed.',
  'moderator_required': 'Sign in with a MOD_* ward moderator account first.',
  'policy_question_required': 'Enter a policy question before opening the vote.',
  'analysis_mode_required': 'Select at least one analysis mode (SCS or % chance).',
  'credit_title': 'Credit & governance',
  'credit_governance_intro': 'This app is best used alongside the ',
  'credit_governance_link_label': 'Full Community Governance',
  'credit_governance_link_suffix':
      ' as a tool to debate and come to consensus conclusions within parish wards.',
  'credit_parish_note':
      'Use Evolve Chronoflux analysis to structure ward-level debate and reach shared conclusions — not as a substitute for democratic process, but as a quantitative companion to Full Community Governance.',
  'credit_cohesion_goal':
      'Build release aims for 94% Social Cohesion within the British Isles.',
  'credit_peace_goal':
      'Full committal across Earth will bring Peace on Earth at a scattered 93% Social Cohesion.',
  'credit_attribution_title': 'Attribution',
  'credit_attribution_body':
      'CREATED BY RUSSELL G SNEDDON BASED ON THE CHRONOFLUX PRINCIPIA BY ROY D HERBERT, REWARD TOKEN FORKED / CLONED FROM BEAMPRIVACY',
  'creator_attribution_prefix': 'CREATED BY ',
  'creator_attribution_russell': 'RUSSELL G SNEDDON',
  'creator_attribution_middle': ' BASED ON THE CHRONOFLUX PRINCIPIA BY ',
  'creator_attribution_roy': 'ROY D HERBERT',
  'creator_attribution_suffix': ', REWARD TOKEN FORKED / CLONED FROM ',
  'creator_attribution_beam': 'BEAMPRIVACY',
  'wallet_title': 'Evolve Wallet',
  'wallet_opening_title': 'Opening wallet',
  'wallet_opening_message':
      'Your Perccent wallet is loading. Please wait…',
  'wallet_opening_error':
      'The wallet could not open. Check your connection and try again.',
  'wallet_opening_retry': 'Try again',
  'wallet_details_section': 'Chain & network details',
  'wallet_subtitle': 'Perccent chain · scenario-driven treasury',
  'wallet_creator_credit':
      'CREATED BY RUSSELL G SNEDDON BASED ON THE CHRONOFLUX PRINCIPIA BY ROY D HERBERT, REWARD TOKEN FORKED / CLONED FROM BEAMPRIVACY',
  'wallet_privacy_title': 'Beam-confidential Perccent',
  'wallet_privacy_note':
      'Perccent is forked from Beam privacy — confidential addresses and shielded balances on-device.',
  'wallet_avg_block_time': 'Average time per block: {time}',
  'wallet_time_confirmations_title': 'Chronoflux TIME confirmations',
  'wallet_supply_infinite': 'Infinite continuum supply (∞ PERC)',
  'wallet_balance_label': 'Available balance',
  'wallet_staking_title': 'Cumulative staking',
  'wallet_staking_note':
      'Confirmed held PERC earns 5 cent each block (10% of the 50 cent base) after 1 block confirmation. 1 PERC = 100,000,000 cent (0.00000001 PERC each).',
  'wallet_staking_earned': 'Total staking earned: {amount} PERC',
  'wallet_burned_title': 'Burned PERC',
  'wallet_burned_note':
      'Every send network fee (0.00000001 PERC) is permanently burned — removed from circulation across the Perccent chain.',
  'wallet_burned_total': 'Cumulative burned: {amount} PERC',
  'wallet_tx_staking': 'Staking reward',
  'wallet_tx_revert': 'Returned transfer',
  'wallet_tx_genesis': 'Genesis renewal (283M PERC Perccent)',
  'wallet_signed_in_as': 'Signed in as {user}',
  'wallet_logout': 'Sign out',
  'wallet_session_expired':
      'Your wallet session ended after 7 minutes away from the seed connection — sign in again to run SCS analyses.',
  'wallet_treasury_title': 'Treasury emission',
  'wallet_treasury_note':
      'Perccent chain advances on scenario analysis — not on Grok construal or field keystrokes. Treasury emission is dynamic: it scales with average block time and wallet load on top of the faucet-aligned baseline (up to 1 PERC per 7-minute window at 1.0× load). Infinite Chronoflux continuum supply.',
  'wallet_treasury_dynamic_rate':
      'Current emission: {rate} PERC/min — load {load}× · block pace {block}×',
  'wallet_treasury_cycle': 'Treasury cycle #{cycle}',
  'wallet_treasury_minted': '{minted} PERC minted ({pct}% continuum)',
  'wallet_treasury_remaining': 'Treasury remaining: {amount} PERC',
  'wallet_treasury_pool': 'Treasury pool (faucet): {amount} PERC',
  'wallet_treasury_inflation_epoch': 'Last inflation epoch: {time}',
  'wallet_treasury_inflation_next': 'Time to next inflation: {wait}',
  'wallet_treasury_inflation_ready': 'Inflation ready — run a scenario',
  'wallet_treasury_inflation_critical':
      'Treasury at 1 cent reserve — aligned emission accrues on next scenario',
  'wallet_treasury_send_locked':
      'Manual sends from evolve_treasury are disabled. Emission and faucet payouts continue.',
  'wallet_treasury_manual_send_note':
      'Treasury is active — faucet-aligned emission (~0.14285714 PERC/min) and scenario payouts continue. Manual sends from evolve_treasury are disabled.',
  'wallet_treasury_offline_note':
      'Treasury awaits blockchain launch. Run analysis after launch to draw from the faucet.',
  'wallet_block_height': 'Block height: {height}',
  'wallet_scenario_block_height':
      'Your scenario block: {current} / {max}',
  'wallet_scenario_block_capped':
      'Scenario block cap reached ({max} scenario checks)',
  'wallet_seed_block_anchor': 'Seed anchor: block {block}',
  'wallet_faucet_title': 'Analysis faucet',
  'wallet_faucet_note':
      'Tap Calculate percent chance or Calculate social cohesion score to draw xx/100 PERC from treasury — xx is the two-digit outcome (percent or SCS) — once every 7 minutes.',
  'wallet_faucet_outcome': 'Outcome reward',
  'wallet_faucet_cooldown': 'Next treasury draw in approximately {wait}',
  'wallet_mesh_title': 'Concurrent wallet mesh',
  'wallet_mesh_connected':
      'Connected to {count} other wallet(s) on the shared Perccent chain',
  'wallet_mesh_peers': 'Peers: {peers}',
  'wallet_mesh_incomplete': 'Mesh linking wallets…',
  'wallet_mesh_network_synced':
      'Seed connected — internet height {height} — node {node}',
  'wallet_mesh_network_syncing':
      'Syncing to internet block height {height}…',
  'wallet_sync_button': 'Sync wallet',
  'wallet_sync_syncing': 'Syncing…',
  'wallet_sync_success': 'Wallet synced to seed — block height {height}',
  'wallet_sync_partial':
      'Partial sync — local height {local}, network height {network}',
  'wallet_sync_seed_offline':
      'Cannot reach the seed node — check your internet connection and try again',
  'wallet_evolution_title': 'Evolutionary blockchain',
  'wallet_evolution_note':
      'Every app version connects to the same chain — evolution verified by the Chronoflux Principia.',
  'wallet_evolution_chain': 'Evolutionary chain: {id}',
  'wallet_evolution_principia': 'Chronoflux Principia: {id}',
  'wallet_evolution_app': 'App version: {version}',
  'wallet_evolution_epochs': 'Evolution epochs: {count}',
  'wallet_evolution_versions': 'Connected versions: {versions}',
  'wallet_dapp_suite_title': 'Perccent dapp suite',
  'wallet_dapp_suite_subtitle':
      'Beam-suite structure — side chain, send/receive, bridges, and governance for all users',
  'wallet_dapp_featured_label': 'MAIN DAPP · v2.0',
  'wallet_dapp_ward_voting': 'Community Ward Voting',
  'ward_voting_tab_vote': 'Vote',
  'ward_voting_tab_scenario': 'Scenario checker',
  'ward_voting_intro':
      'Submit a proposal for everyone to see for 10 days. Each wallet may cast one vote per proposal.',
  'ward_proposal_submit_title': 'Submit a ward proposal',
  'ward_proposal_title_label': 'Proposal title',
  'ward_proposal_summary_label': 'Proposal summary',
  'ward_proposal_ward_label': 'Community ward',
  'ward_proposal_submit_button': 'List for 10 days',
  'ward_proposal_listed_ok': 'Proposal listed for all wallets — voting open for 10 days.',
  'ward_proposal_days_left': '{days} day(s) left in listing',
  'ward_proposal_by': 'Proposed by {user}',
  'ward_voting_login_required':
      'Sign in to submit a proposal or cast your vote. Live results below are public — no vote required to view.',
  'ward_voting_public_results_title': 'Live public results',
  'ward_voting_public_results_note':
      'Vote tallies and comments update for every wallet as ballots are cast.',
  'ward_voting_total_ballots': '{count} wallet(s) voted',
  'ward_voting_no_ballots_yet': 'No votes yet — results will appear here as wallets vote.',
  'ward_voting_public_comments': 'Public comments',
  'ward_voting_comment_choice_for': 'For',
  'ward_voting_comment_choice_against': 'Against',
  'ward_voting_comment_choice_abstain': 'Abstain',
  'ward_voting_no_proposals': 'No open ward proposals at this time.',
  'ward_voting_select_proposal': 'Select proposal',
  'ward_voting_comment_label': 'Your comment',
  'ward_voting_comment_hint': 'Explain how Chronoflux analysis informs your vote…',
  'ward_voting_for': 'For',
  'ward_voting_against': 'Against',
  'ward_voting_abstain': 'Abstain',
  'ward_voting_already_cast': 'This wallet has voted — one vote per wallet per proposal.',
  'ward_voting_vote_locked': 'Vote recorded for this wallet',
  'ward_voting_cast_ok': 'Vote and comment recorded on the ward ledger.',
  'ward_conclusion_link_button': 'Vote on this conclusion in Community Ward',
  'ward_conclusion_link_loaded': 'Loaded from Evolve analysis conclusion',
  'ward_conclusion_link_grok_badge': 'Includes Grok construal context',
  'ward_conclusion_link_summary_header': 'Evolve analysis — ward proposal summary',
  'ward_conclusion_link_vote_prefill_header': 'My vote is informed by this Evolve analysis:',
  'ward_conclusion_link_question': 'Posed question',
  'ward_conclusion_link_grok_note': 'Grok construal:',
  'ward_dual_populator_title': 'Dual analysis — % and SCS',
  'ward_dual_populator_note':
      'Run percent chance and social cohesion score together, then populate proposal and vote fields with both metrics.',
  'ward_dual_populator_from_link_note':
      'Using the Evolve conclusion link — runs % and SCS for that scenario and fills proposal and vote fields with both.',
  'ward_dual_run_button': 'Run % + SCS analysis',
  'ward_dual_rerun_from_link_button': 'Re-run % + SCS for linked scenario',
  'ward_dual_populate_button': 'Populate proposal & vote fields',
  'ward_dual_populated_ok': 'Proposal and vote fields filled with % and SCS combined.',
  'ward_dual_populated_from_link_ok':
      'Linked conclusion enriched with % and SCS — proposal and vote fields updated.',
  'ward_dual_summary_header': 'Evolve dual analysis — ward proposal summary',
  'ward_dual_vote_prefill_header': 'My vote is informed by this dual Chronoflux analysis:',
  'ward_grok_use_construal': 'Use Grok construal',
  'ward_grok_live_connected': 'Live Grok connected — ω/σ/Iτ/Jμ filled before analysis',
  'ward_grok_heuristic_mode': 'Heuristic Grok construal — discourse levers applied',
  'ward_grok_available': 'Grok construal available for ward analysis',
  'ward_scenario_intro':
      'Free open scenario probability checker — runs both percent chance and social cohesion score (SCS) from the Chronoflux paper without treasury draw.',
  'ward_scenario_topic_label': 'Scenario topic (optional)',
  'ward_scenario_question_label': 'Posed question',
  'ward_scenario_question_hint': 'What outcome should the ward weigh?',
  'ward_scenario_run': 'Run open scenario check',
  'ward_scenario_need_question': 'Enter a posed question to run the checker.',
  'ward_scenario_percent_title': 'Percent chance',
  'ward_scenario_scs_title': 'Social cohesion score',
  'ward_scenario_free_note':
      'Open checker only — does not credit PERC. Use the Analysis tab for faucet rewards.',
  'wallet_dapp_send_receive': 'Send / Receive',
  'wallet_dapp_send_receive_note':
      'Every registered wallet can receive PERC. Send only to a PERC address.',
  'wallet_dapp_side_chain': 'Chronoflux Side Chain',
  'wallet_dapp_governance': 'Perccent Governance',
  'wallet_dapp_analysis': 'Analysis Gallery',
  'wallet_dapp_bridge': 'Side Chain Bridge',
  'wallet_dapp_bridge_note':
      'Microblocks on the Chronoflux side chain seal into main-chain blocks at 100M.',
  'wallet_dapp_mesh': 'Wallet Mesh Bridges',
  'wallet_dapp_mesh_peer': 'Concurrent mesh bridge — active',
  'wallet_dapp_names': 'Perccent Name Service',
  'wallet_dapp_minter': 'Asset Minter',
  'wallet_dapp_main_chain': 'Main chain',
  'wallet_sidechain_id': 'Side chain ID',
  'wallet_sidechain_parent': 'Parent chain',
  'wallet_sidechain_height': 'Side-chain microblock height',
  'wallet_sidechain_pending':
      'Seal cycle: {completed} / {total} wards — {pending} / {bundle} microblocks in active ward',
  'wallet_sidechain_main_height': 'Parent main-chain height',
  'wallet_sidechain_last_seal': 'Last seal block',
  'wallet_explorer_link': 'the blockchain explorer',
  'wallet_explorer_block_current': 'Block #{height}',
  'wallet_explorer_title': 'the blockchain explorer',
  'wallet_explorer_subtitle': 'Graph-based Perccent chain dapp',
  'wallet_explorer_block_label': 'Current block',
  'wallet_explorer_empty': 'No blocks yet — run a scenario to advance the chain.',
  'wallet_explorer_emission_chart': 'Treasury emission per block',
  'wallet_explorer_cumulative_chart': 'Cumulative treasury minted',
  'wallet_chronoflux_graph_title': 'Chronoflux five-point variables',
  'wallet_chronoflux_graph_note':
      'Pentagon radar and five-point time series for ρt, ω, σ, Iτ, Jμ — times match Chronoflux input order across scenario draws.',
  'wallet_chronoflux_graph_empty':
      'Run a percent chance or social cohesion analysis to populate Chronoflux variable graphs.',
  'wallet_explorer_legend_emission': 'Treasury Perccent (PERC)',
  'wallet_explorer_legend_txs': 'Transactions',
  'wallet_explorer_history': 'BLOCK HISTORY',
  'wallet_explorer_trigger': 'Triggered by {user}',
  'wallet_explorer_tx_count': '{count} transaction(s)',
  'wallet_explorer_transfer_row': 'Manual tx · {amount} {symbol} · {from} → {to}',
  'wallet_explorer_transfer_lane_title': 'Main-chain transfer lane (100M microblock framework)',
  'wallet_explorer_transfer_lane_entry':
      'Block #{index} · {amount} {symbol} · {from} → {to}',
  'wallet_explorer_transfer_lane_empty':
      'No Perccent transfers yet — sends appear here on the lawful split.',
  'wallet_explorer_pending_tx_flow_title': 'Pending',
  'wallet_explorer_pending_tx_flow_empty':
      'No pending transfers — inbound PERC settles on sign-in',
  'wallet_explorer_pending_tx_flow_entry':
      '{amount} {symbol} · {from} → {to} · awaiting settlement',
  'wallet_explorer_genesis_renewal': 'Genesis renewal — cycle #{cycle} (283M PERC Perccent)',
  'wallet_explorer_confirmations': '{count} confirmation(s) required — fully confirmed',
  'wallet_explorer_confirmed': 'Fully confirmed (1 block)',
  'wallet_explorer_frame_flow_title': 'Lawful Frame-Flow Split — 10,000 Block Wards',
  'wallet_explorer_frame_flow_subtitle':
      'Degenerate one-vector ansatz set aside; lawful continuity split retained — microblocks bundled into wards of {bundle}.',
  'wallet_explorer_ward_title': 'Ward bundles — dynamic microblock explorer',
  'wallet_explorer_ward_subtitle':
      'Each ward seals {bundle} Chronoflux microblocks. 10,000 wards complete one main-chain seal cycle.',
  'wallet_explorer_ward_cycle':
      'Current cycle: {completed} / {total} wards bundled — ward #{ward} filling ({pending} / {bundle} microblocks)',
  'wallet_explorer_ward_lifetime': 'Lifetime wards sealed: {count}',
  'wallet_explorer_ward_pending':
      'Active ward #{ward}: {pending} / {bundle} microblocks',
  'wallet_explorer_ward_field_count':
      '{wards} wards in field — {lit} bundled ({bundle} microblocks each)',
  'wallet_explorer_ward_legend':
      'Green = sealed ward · Blue = ward in progress · Dark = pending',
  'wallet_explorer_frame_flow_center':
      'Lawful frame-flow split — frame defines the slice; drift remains inside the slice',
  'wallet_explorer_frame_flow_status':
      'A2 status: lawful frame-flow split; projector built from frame only; drift remains measurable. '
      'Structural consequence of the foundational continuity regime.',
  'wallet_explorer_shard_count':
      '{visible} / {visible} wards in field — {lit} bundled in current seal cycle',
  'wallet_explorer_ward_seal_progress':
      'Seal cycle: {completed} / {total} block wards — ward filling {pending} / {bundle} microblocks',
  'wallet_explorer_microblock_height': 'Fair-usage microblocks logged: {count}',
  'wallet_explorer_microblock_log_title': 'Fair-usage microblock log',
  'wallet_explorer_microblock_log_note':
      'Each microblock records one fair app interaction — keystrokes and field edits on the analysis form. The log holds up to {bundle} entries per ward; when a ward fills, the log clears for the next ward.',
  'wallet_explorer_microblock_log_ward_status':
      'Ward {ward} log: {count} / {bundle} entries',
  'wallet_explorer_microblock_log_empty':
      'No microblocks yet — type in the analysis fields after blockchain launch.',
  'wallet_explorer_microblock_log_entry':
      '#{index} ward {ward} · μ{pos} · {time} · {label}{extra}',
  'wallet_explorer_microblock_log_truncated':
      'Showing last {shown} of {total} logged microblocks',
  'wallet_explorer_microblock_log_count': 'Log entries: {count}',
  'wallet_explorer_microblock_fair_usage': 'Fair app usage',
  'wallet_explorer_degenerate_title':
      'Degenerate one-vector ansatz — not an admissible frame-flow representation',
  'wallet_explorer_degenerate_body':
      'The same vector cannot define the frame and supply spatial drift. The drift is projected away when the projector is built from the direction it tests.',
  'wallet_explorer_lawful_title': 'Lawful variables',
  'wallet_explorer_label_frame': 'Frame normal nμ defines slicing',
  'wallet_explorer_label_drift': 'Spatial drift vμ inside slice',
  'wallet_explorer_label_split': 'Split nμ vμ = 0 orthogonal',
  'wallet_explorer_label_projector': 'Projector h(n)μν from frame',
  'wallet_cooldown_popup_title': 'Treasury draw on cooldown',
  'wallet_cooldown_popup_body':
      'Your wallet already drew from treasury within the last 7 minutes. The Perccent chain advances on scenarios — your next eligible draw (and block) is in approximately {blockWait}. You can draw xx/100 PERC again after {wait}.',
  'wallet_cooldown_popup_ok': 'OK',
  'wallet_blockchain_awaiting_launch':
      'Connecting to the live Perccent seed — scenario rewards unlock once sync completes.',
  'wallet_blockchain_launch_title': 'Blockchain launched!',
  'wallet_blockchain_launch_body':
      'The Perccent chain is live. Run scenarios to advance blocks.',
  'wallet_blockchain_launch_ok': 'Let\'s go',
  'wallet_faucet_base': 'Base reward',
  'wallet_faucet_bonus': 'Outcome bonus',
  'wallet_faucet_total': 'Total credited',
  'wallet_address_label': 'Your Perccent address',
  'wallet_copy_address': 'Copy address',
  'wallet_address_copied': 'Address copied',
  'wallet_transactions_title': 'RECENT TRANSACTIONS',
  'wallet_transactions_empty':
      'Run a percent-chance or social-cohesion calculation on Analysis to receive your first Perccent faucet payout.',
  'wallet_treasury_setup_title': 'Secure treasury account',
  'wallet_treasury_setup_note':
      'Treasury holder receives all scenario-driven emissions. Create your password now (first use only).',
  'wallet_treasury_username': 'Treasury username',
  'wallet_password': 'Password',
  'wallet_password_confirm': 'Confirm password',
  'wallet_create_password': 'Create password',
  'wallet_login_title': 'Evolve Wallet sign-in',
  'wallet_login_note':
      'Sign in with the username you chose when you created your wallet.',
  'wallet_register_title': 'Create your wallet',
  'wallet_register_note':
      'Pick a username and password — your Perccent address is generated from them on this device.',
  'wallet_choose_username': 'Choose username',
  'wallet_username_hint': 'e.g. parish_ward_42',
  'wallet_username_rules': '3–24 characters: lowercase letters, numbers, underscores.',
  'wallet_treasury_setup_link': 'Treasury holder? Secure treasury account',
  'wallet_back_to_sign_in': 'Back to sign in',
  'wallet_app_gate_title': 'Create your wallet first',
  'wallet_app_gate_note':
      'Evolve unlocks after you register and receive a Perccent address on this device.',
  'splash_enter_app': 'Enter Evolve',
  'splash_preparing_wallet': 'Preparing wallet…',
  'splash_wallet_loading': 'Wallet loading…',
  'splash_signed_in_as': 'Signed in as {user}',
  'splash_version_checking': 'Checking for updates…',
  'splash_version_latest': 'You have the latest version ({version})',
  'splash_version_update':
      'Update available: {latest} — you have {current}',
  'splash_version_update_action': 'Get the update',
  'wallet_username': 'Username',
  'wallet_sign_in': 'Sign in',
  'wallet_register': 'Create account',
  'wallet_send': 'Send',
  'wallet_receive': 'Receive',
  'wallet_send_title': 'Send Perccent',
  'wallet_send_to': 'To PERC address',
  'wallet_send_to_hint': 'Paste or scan the recipient PERC address',
  'wallet_send_scan_qr': 'Scan QR code',
  'wallet_send_scan_title': 'Scan PERC address',
  'wallet_send_scan_body':
      'Point your camera at another user\'s Receive QR code to fill in their PERC address.',
  'wallet_send_scan_cancel': 'Cancel scan',
  'wallet_send_scan_invalid': 'That QR code is not a valid PERC address.',
  'wallet_send_scan_ready': 'Camera ready — align the QR code in the frame.',
  'wallet_send_scan_camera_error':
      'Could not access the camera. Allow camera permission in device settings, then try again.',
  'wallet_send_scan_unavailable':
      'QR scan needs a phone or tablet camera (Android/iOS). Paste the PERC address instead.',
  'wallet_camera_permission_title': 'Allow camera access',
  'wallet_camera_permission_body':
      'Evolve needs your camera to scan another user\'s PERC Receive QR code when sending Perccent coins.',
  'wallet_camera_permission_allow': 'Allow camera',
  'wallet_camera_permission_not_now': 'Not now',
  'wallet_camera_permission_denied':
      'Camera access denied — allow camera in settings to scan PERC QR codes.',
  'wallet_camera_permission_settings_body':
      'Camera access is turned off for Evolve. Open settings and enable Camera to scan PERC QR codes.',
  'wallet_camera_permission_open_settings': 'Open settings',
  'wallet_send_address_pick': 'Or pick a known address',
  'wallet_send_amount': 'Amount (PERC)',
  'wallet_send_amount_hint': '0.00000001',
  'wallet_send_amount_helper':
      'Divisible to 0.00000001 PERC (1 cent). All wallets can receive any amount down to 1 cent.',
  'wallet_tx_fee_burned': 'Network fee burned',
  'wallet_send_memo': 'Memo (optional)',
  'wallet_send_confirm': 'Send Perccent',
  'wallet_receive_title': 'Receive Perccent',
  'wallet_receive_note':
      'Others can scan this QR code or copy your PERC address to send Perccent (PERC) to you.',
  'wallet_receive_qr_hint': 'Scan to send PERC',
  'wallet_tx_treasury': 'Treasury emission',
  'wallet_tx_reward': 'Analysis reward',
  'wallet_tx_sent': 'Sent to {user}',
  'wallet_tx_received': 'Received from {user}',
  'wallet_tx_pending': 'Pending',
  'wallet_tx_pending_hint': 'Confirming transfer on the network.',
  'wallet_login_language_label': 'Language',
  'wallet_password_mismatch': 'Passwords do not match',
  'wallet_endpoint_label': 'Endpoint: {endpoint}',
  'wallet_tx_microblock_seal': 'Chronoflux microblock seal',
  'wallet_status_treasury_secured':
      'Treasury secured — awaiting seed treasury sign-in to launch chain',
  'wallet_status_account_created': 'Account created',
  'wallet_status_signed_in': 'Signed in as {user}',
  'wallet_err_sign_in_to_send': 'Sign in to send {name}',
  'wallet_err_invalid_amount':
      'Enter a valid {symbol} amount (up to 8 decimal places)',
  'wallet_err_minimum_send': 'Minimum send is {min} {symbol} (1 cent)',
  'wallet_err_insufficient_balance':
      'Insufficient balance — need {total} {symbol} ({amount} + {fee} network fee)',
  'wallet_err_recipient_not_found':
      'Recipient PERC address not found on the network — the owner must register and sign in once so the address is discoverable',
  'wallet_status_genesis_renewal':
      'Genesis block — treasury cycle {cycle} renewed (283M {symbol} {name})',
  'wallet_status_sent_instant':
      'Sent {amount} {symbol} to {dest} (network fee {fee} {symbol})',
  'wallet_status_sent_pending':
      'Sent {amount} {symbol} to {dest} (network fee {fee} {symbol}) — delivering on the network',
  'wallet_status_sent_queued':
      'Sent {amount} {symbol} to {dest} (network fee {fee} {symbol}) — queued until they sign in on the network within {delay}, otherwise returns to your wallet',
  'wallet_status_treasury_empty': 'Treasury empty — run another scenario later',
  'wallet_status_treasury_cap': 'Treasury cap reached',
  'wallet_status_faucet_credited': '+{amount} {symbol}',
  'wallet_faucet_label_scs': 'Social cohesion score analysis',
  'wallet_faucet_label_percent': 'Percent chance analysis',
  'wallet_err_unknown_account': 'Unknown account',
  'wallet_err_send_to_yourself': 'Cannot send to yourself',
  'wallet_err_invalid_password': 'Invalid password',
  'wallet_err_generic': 'Something went wrong — try again',
  'wallet_err_address_empty': 'Enter a recipient PERC address',
  'wallet_err_address_confidential': 'Enter a valid confidential PERC address',
  'wallet_err_address_invalid': 'Enter a valid PERC address',
  'wallet_inbound_revert_days': '7 days',
  'wallet_inbound_revert_hours': 'several hours',
  'wallet_inbound_revert_seconds': 'a short time',
  'license_panel_title': 'License & Chronoflux attribution',
  'license_dialog_title': 'Evolve License',
  'license_chronoflux_attribution':
      'CREATED BY RUSSELL G SNEDDON BASED ON THE CHRONOFLUX PRINCIPIA BY ROY D HERBERT, REWARD TOKEN FORKED / CLONED FROM BEAMPRIVACY',
  'license_copyright': 'Copyright (c) 2026 Evolve Chronoflux. All rights reserved.',
  'license_dual_summary':
      'Proprietary / dual license: personal non-commercial use permitted under LICENSE; commercial use requires a separate Commercial License (russell.gray.sneddon@gmail.com).',
  'license_view_full': 'View full license',
  'grok_construe_label': 'GROK CONSTRUE',
  'grok_bar_hint':
      'Requires your actual X Premium account. Sign in with X first — Grok observes live social discourse from your authenticated session, then fills blank ω/σ/Iτ/Jμ from X posts, news, and data. Your field text is never overwritten.',
  'grok_sign_in_x': 'SIGN IN WITH X',
  'grok_sign_in_x_required':
      'Sign in with your X Premium account to enable Grok construal — live social discourse observation requires a real authenticated session.',
  'grok_mock_mode_blocked':
      'Mock sign-in is disabled. Set X_CLIENT_ID in grok_proxy.local.env and sign in with your real X Premium account.',
  'grok_preparing_sign_in': 'Preparing X sign-in…',
  'grok_open_x_tab': 'OPEN X SIGN-IN (NEW TAB)',
  'grok_open_x_body':
      'Tap the button below to open X login in a new tab. '
      'This works with DuckDuckGo, Chrome, Edge, Firefox, and your default browser. '
      'The X permission screen should say Evolve wants to access your account. '
      'If it still shows SSUCF, rename your app at console.x.com (see checklist below). '
      'After you sign in, return here — Evolve will detect your Premium account.',
  'grok_oauth_redirect_hint':
      'If X says “Something went wrong”, register the callback for your platform in console.x.com → your app → OAuth 2.0 → Callback URLs:',
  'grok_oauth_portal_checklist':
      'X Developer Portal checklist:\n'
      '1. console.x.com → your app → App settings → App name: Evolve (replaces SSUCF in the sign-in popup)\n'
      '2. User authentication settings → OAuth 2.0 enabled\n'
      '3. App type: Native App\n'
      '4. Callback URLs (add both if you use Windows and Android):\n'
      '   • Desktop: http://127.0.0.1:8787/auth/callback\n'
      '   • Android: evolve://auth/callback\n'
      '5. Scopes allowed: tweet.read, users.read, offline.access\n'
      '6. Keys and tokens → OAuth 2.0 Client ID must match Evolve exactly (shown when you sign in)\n'
      '7. Rebuild Android APK after changing grok_proxy.local.env (scripts\\build.ps1 apk)',
  'grok_oauth_denied':
      'X denied access — check your Developer Portal callback URL and OAuth 2.0 settings.',
  'grok_dialog_cancel': 'Cancel',
  'grok_begin_construe': 'BEGIN GROK CONSTRUE',
  'grok_begin_requires_enable': 'Turn Grok construal to Use before beginning construal.',
  'grok_yes': 'Use',
  'grok_no': "Don't use",
  'grok_connect_title': 'Connect your X account',
  'grok_connect_body':
      'Sign in with X in your browser. Evolve verifies Premium before Grok can construe live context. Chronoflux still runs locally.',
  'grok_starting_proxy': 'Starting Grok proxy…',
  'grok_proxy_start_failed': 'Could not start the Grok proxy on this device.',
  'grok_connecting':
      'Complete X sign-in in your browser. This window and the browser tab will close automatically when you are connected.',
  'grok_connecting_mobile':
      'Complete X sign-in in the browser tab. You will return to Evolve automatically when your account is connected.',
  'grok_connecting_background':
      'X sign-in opened in your browser. Keep using Evolve — connection completes automatically when you authorize.',
  'grok_connecting_mobile_background':
      'X sign-in opened in your browser. Return to Evolve anytime — your account connects automatically after you authorize.',
  'grok_connect_failed': 'X connection failed — try again or leave Grok construe off.',
  'grok_connect_cancelled': 'X connection cancelled.',
  'grok_premium_required':
      'X Premium is required for Grok construal. Leave the slider on Don\'t use for offline-only calculation.',
  'grok_connected_as': 'Connected @{user}',
  'grok_proxy_unreachable':
      'Grok proxy is not reachable. Leave Grok construe on Don\'t use for offline-only calculation.',
  'grok_launch_failed': 'Could not open X sign-in in your default browser.',
  'grok_online_ready': 'Grok construal on — variables fill as you pose your question.',
  'grok_web_heuristic_ready':
      'Web heuristic construal on (@evolve_web) — blank ω/σ/Iτ/Jμ fill from your posed question. No proxy or X login on GitHub Pages.',
  'grok_android_heuristic_ready':
      'Android heuristic construal on (@evolve_android) — blank ω/σ/Iτ/Jμ fill from your posed question. Embedded proxy unavailable; use Windows for live X Premium Grok.',
  'grok_web_proxy_required':
      'Live Grok on web requires a hosted Grok proxy (GROK_PROXY_URL) and an X Premium account. '
      'GitHub Pages uses in-browser heuristic construal instead — slide Use to enable.',
  'grok_proxy_detected': 'Grok proxy found — you can sign in with X.',
  'grok_proxy_not_detected':
      'Grok proxy not found. Start it with: dart run tool/grok_proxy.dart (port 8787), then tap Retry.',
  'grok_mock_signing_in': 'Dev mock mode — signing in without opening X…',
  'grok_mock_signed_in':
      'Dev mock mode — signed in as @{user}. Set X_CLIENT_ID in grok_proxy.local.env for real X login.',
  'grok_retry_proxy': 'RETRY PROXY',
  'grok_open_x_link': 'Open X sign-in',
  'grok_construing':
      'Grok is running real-time discourse analysis on your question and filling blank ρt/ω/σ/Iτ/Jμ fields…',
  'grok_fields_populated': 'Grok filled blank variables from your posed question.',
  'grok_fields_ready': 'All ω/σ/Iτ/Jμ variables are ready — tap Calculate when you are.',
  'grok_filled_badge': 'Grok',
  'constructs_section_title': 'CHRONOFLUX VARIABLES (ω · σ · Iτ · Jμ)',
  'constructs_section_grok':
      'Tap BEGIN GROK CONSTRUE (above) after your full question is written — blank ρt/ω/σ/Iτ/Jμ fill from real-time observance of live discourse, ongoing events, and pertinent data scoped only to your question (not by repeating your question).',
  'constructs_section_manual':
      'Complete all four variables below, or turn on Grok construal to auto-fill them.',
  'constructs_missing_headline': 'Complete the Chronoflux variables',
  'constructs_missing_body':
      'With Grok construal off, fill every variable before Calculate:',
  'status_need_constructs': 'Complete these variables before Calculate: {missing}.',
  'grok_offline_mode': 'Grok construal off — local Chronoflux only.',
  'grok_construal_applied': 'Grok suggestions applied to blank fields — calculation complete.',
  'grok_construal_failed': 'Grok construal failed — switched to offline mode.',
  'grok_dialog_ok': 'OK',
  'status_calc_grok_pipeline': 'Construing with Grok, then running Chronoflux…',
  'start_fresh': 'RESET',
  'web_grok_inactive_notice':
      'Grok construe on web requires a hosted Grok proxy (GROK_PROXY_URL) and your X Premium sign-in. Use the Windows desktop app with grok_proxy.local.env, or deploy the proxy and rebuild with --dart-define=GROK_PROXY_URL=…',
  'region_select_advice': 'SELECT THE REGION OR COUNTRY YOU WISH TO ANALYSE',
  'posed_question_section': 'YOUR QUESTION',
  'posed_question_label': 'POSE YOUR QUESTION HERE',
  'posed_question_label_cohesion': 'POSE YOUR QUESTION HERE (optional)',
  'posed_question_hint': 'Your scenario question for this analysis.',
  'outcome_part_enable_multi': 'Use multi-part pathways',
  'outcome_part_enable_hint':
      'Check to list separate percent chances per pathway. Unchecked uses your main question as a single outcome.',
  'outcome_parts_section': 'Outcome pathways',
  'outcome_parts_hint':
      'Enter each pathway below for a listed percent-chance breakdown (minimum two).',
  'outcome_context_label': 'Shared outcome (optional)',
  'outcome_context_hint': 'Outcome context for your scenario',
  'outcome_part_label': 'Pathway {n}',
  'outcome_part_hint': 'Pathway or outcome part label',
  'outcome_part_add': 'Add pathway field',
  'outcome_part_remove': 'Remove',
  'outcome_part_include_others': 'Include Others (non-exhaustive)',
  'posed_question_hint_cohesion':
      'Optional on Social Cohesion — use narrative link or ω/σ/Iτ/Jμ below instead.',
  'status_need_posed_question': 'Pose your scenario question in POSE YOUR QUESTION HERE.',
  'region_label': 'Region',
  'language_label': 'Language',
  'region_global': 'Global',
  'region_uk_ireland': 'UK & Ireland',
  'region_usa': 'United States',
  'region_americas': 'Americas',
  'region_europe': 'Europe',
  'region_mena': 'Middle East & North Africa',
  'region_sub_saharan_africa': 'Sub-Saharan Africa',
  'region_south_asia': 'South Asia',
  'region_east_asia': 'East Asia',
  'region_southeast_asia': 'Southeast Asia',
  'region_oceania': 'Oceania',
  'lang_en': 'English',
  'lang_es': 'Español',
  'lang_fr': 'Français',
  'lang_de': 'Deutsch',
  'lang_pt': 'Português',
  'lang_ar': 'العربية',
  'lang_zh': '中文',
  'lang_hi': 'हिन्दी',
  'lang_ja': '日本語',
  'analysis_mode_heading': 'Choose your analysis',
  'mode_percent': 'Percent Chance',
  'mode_cohesion': 'Social Cohesion Score',
  'mode_percent_short': 'Percent chance',
  'mode_cohesion_short': 'Social cohesion',
  'banner_percent':
      'Pose any ω question or scenario. Optional σ/Iτ/Jμ fields. Chronoflux percent output.',
  'banner_cohesion':
      'Describe any scenario worldwide. Full PART ONE / TWO / THREE cohesion report.',
  'scenario_section': 'YOUR SCENARIO',
  'results_section': 'RESULTS',
  'calc_actions_heading': 'RUN ANALYSIS',
  'calc_percent': 'Calculate percent chance',
  'calc_percent_short': 'Calculate %',
  'calc_cohesion': 'Calculate social cohesion score',
  'calc_cohesion_short': 'Cohesion score',
  'empty_percent': 'Pose your scenario question and tap Calculate percent chance.',
  'empty_cohesion':
      'Paste a narrative link or enter scenario details, then tap Calculate social cohesion score.',
  'status_need_vortex': 'Enter any ω question or scenario in Vortex (ω).',
  'status_need_scenario':
      'Paste a narrative link or fill ω/σ/Iτ/Jμ construct fields, then calculate cohesion.',
  'bind_posed_question': 'posed question: {value}',
  'bind_vortex_variable': 'ω variable: {value}',
  'status_calc_percent': 'Calculating Chronoflux percent chance…',
  'status_calc_cohesion': 'Calculating social cohesion score…',
  'status_calc_pipeline': 'Running PART ONE → PART TWO → PART THREE…',
  'part_two_panel_title': 'PART TWO — Broader Political Continuum Integration',
  'part_two_refined_line':
      'Refined SCS ~{scs}/100 · THE CONTINUUM: {reg}% regressive / {prog}% progressive → {lean}',
  'part_two_copy': 'Copy PART TWO',
  'part_two_copied': 'PART TWO copied.',
  'status_done': 'Calculation complete.',
  'locale_updated': 'Region and language updated — results refreshed.',
  'part3_copy': 'Copy actions',
  'part3_copied': 'PART THREE actions copied',
  'part3_headline_pct': 'PART THREE — Recommended actions for the {agent}',
  'part3_headline_scs': 'PART THREE — Actions for the {agent} to raise cohesion',
  'part3_context': '{agent} — actions tied to this scenario: {binding}',
  'part3_input_binding': 'Bound to your inputs: {binding}',
  'part3_topic_suffix': ' (topic: "{topic}")',
  'part3_shear_user': 'Address the stated σ shear bias: "{text}".',
  'part3_shear_observed':
      'Address observed shear (σ {scs}/100) with verified facts, not rumour.',
  'part3_resistance_user': 'Work through the stated Iτ resistance: "{text}".',
  'part3_resistance_observed':
      'Reduce institutional drag (Iτ {scs}/100) with transparent follow-through.',
  'part3_flow_user': 'Preserve the stated Jμ nuance: "{text}".',
  'part3_flow_observed':
      'Strengthen trust transport (Jμ {scs}/100) via differentiated messaging.',
  'part3_target_pct': 'Target: ~{current}% → ~{projected}% on "{subject}"',
  'part3_target_scs': 'Target: SCS ~{current} → {min}–{max} on "{subject}"',
  'part3_impact_pct':
      'These steps may raise the estimate for "{subject}" from ~{current}% toward ~{projected}%.',
  'part3_impact_scs':
      'These steps may raise cohesion from ~{current}/100 toward {min}–{max}/100 within 3 months.',
  'part3_action_1':
      '{agent}: Hold an open public briefing on {subject}{topic_suffix} {shear_hook}',
  'part3_action_2':
      '{agent}: Convene stakeholders on {subject}{topic_suffix} within two weeks. {resistance_hook}',
  'part3_action_3':
      '{agent}: Announce time-bound deliverable steps on {subject}{topic_suffix} with a public tracker. {flow_hook}',
  'topic_hint': 'Topic / headline (optional)',
  'region_focus_banner': '{region} focus — pose your scenario question for this region',
  'grok_conclusion_marker': 'CONCLUSION - THE CONTINUUM:',
  'cohesion_final_summary': 'Final Summary:',
  'cohesion_cycle_complete':
      '🌀 SSUCF Cycle Complete. Analysis by Evolve Chronoflux from posed scenario and construct parameters.',
  'pct_probability': '~{n}% chance of {subject}',
  'pct_predictive': '~{n}% likelihood that {subject}',
  'pct_magnitude': '~{n}% relative estimate for {subject}',
  'pct_descriptive': '~{n}% Chronoflux estimate for {subject}',
  'cohesion_strained': 'cohesion strained but holding',
  'cohesion_favourable': 'cohesion transport favourable',
  'lean_progressive': 'PROGRESSIVE',
  'lean_regressive': 'REGRESSIVE',
  'drivers_high_shear': 'High shear from {snippet} drives tension',
  'drivers_high_shear_subject': 'High shear (σ) on "{subject}" drives tension',
  'drivers_default':
      'ω/σ/Iτ/Jμ dynamics on "{subject}" contextualise the {lean} lean on THE CONTINUUM',
  'obs_vortex':
      'Observed vortex (ω): circulation for "{subject}" in {region} (SCS {scs}/100).',
  'obs_vortex_relative':
      'Observed vortex (ω): "{vortex}" relative to "{subject}" in {region} (SCS {scs}/100).',
  'obs_shear':
      'Observed shear (σ): bias layer on "{subject}" in {region} (SCS {scs}/100).',
  'obs_resistance':
      'Observed resistance (Iτ): institutional tension on "{subject}" in {region} (SCS {scs}/100).',
  'obs_flow':
      'Observed flow (Jμ): trust transport on "{subject}" in {region} (SCS {scs}/100).',
  'obs_shear_fallback': 'Shear baseline from discourse observation.',
  'obs_resistance_fallback': 'Resistance baseline from discourse observation.',
  'obs_flow_fallback': 'Flow baseline from discourse observation.',
  'part_two_vortex_question':
      'Elite framing on "{subject}" compresses competing readings (ω {scs}/100).',
  'part_two_vortex_topic':
      'Unified institutional narrative on "{topic}" narrows public debate (ω {scs}/100).',
  'part_two_shear_question':
      'Polarisation on "{subject}" — {polarity} (σ {scs}/100).',
  'part_two_resistance_flow_question':
      '{transport}; net lean {lean} (Iτ {res_scs}/100, Jμ {flow_scs}/100).',
  'part_two_hint_suffix': 'Scenario signal: {hint}.',
  'part_two_frame_probability': 'probability-frame',
  'part_two_frame_predictive': 'predictive-path',
  'part_two_frame_magnitude': 'magnitude-estimate',
  'part_two_frame_descriptive': 'scenario',
  'part_two_polarity_adverse': 'elevates friction on adverse outcomes',
  'part_two_polarity_favourable': 'favours cohesion-repair paths',
  'part_two_polarity_open': 'balances elite and public readings',
  'part_two_transport_flow_dominant':
      'trust transport outruns institutional drag for this scenario',
  'part_two_transport_resistance_dominant':
      'institutional drag dominates trust transport for this scenario',
  'part_two_transport_contested_adverse':
      'contested transport with friction bias toward adverse resolution',
  'part_two_transport_contested':
      'contested transport — neither drag nor flow clearly dominates',
  'grok_reply':
      '{regressive}% regressive / {progressive}% progressive on THE CONTINUUM. Net momentum {momentum} → leans {lean}. {marker} {conclusion}',
  'recurrence_high': 'HIGH — cohesion collapse risk without targeted interventions.',
  'recurrence_moderate': 'MODERATE — recurrence possible if narrative compression persists.',
  'intervention_1':
      'Granular differentiation — acknowledge peaceful events separately from disorder.',
  'intervention_2':
      'Transparent data engagement — public dashboards and community forums.',
  'intervention_3':
      'Balanced condemnation — address concerns from all sides with data.',
  'intervention_4':
      'Policy adjustments — review programmes with local input.',
  'forecast_line':
      'Calibrated forecast: {pct}% (95% CI: {ci_low}–{ci_high}%) for {subject} over a {horizon}-day horizon. Based on {sample} historical cases ({year_min}–{year_max}), Brier={brier}. Chronoflux refined SCS {refined}/100; regressive continuum {regressive}%. Sources: {provenance}. No betting markets.',
  'forecast_line_foreclosed':
      'Foreclosed outcome: ~{pct}% for {subject}. {reason}. Historical base rates do not apply — the outcome is no longer achievable. No betting markets.',
  'continuum_hints_clause': '; discourse signals from question: {hints}',
  'continuum_conclusion_signals':
      'Construal data — posed question: "{question}"; {frame} frame, {polarity}, event class {event_class}, {horizon}-day horizon, region {region}{hints_clause}.',
  'continuum_conclusion_constructs':
      'Question-inferred Chronoflux: ω {vortex_scs}/100 ({w_v}% w), σ {shear_scs}/100 ({w_s}% w), Iτ {res_scs}/100 ({w_r}% w), Jμ {flow_scs}/100 ({w_f}% w) → refined SCS {refined}/100; THE CONTINUUM {reg}% regressive / {prog}% progressive → {lean}.',
  'continuum_conclusion_registry':
      'Outcome registry ({event_class}, {horizon}d): {base_rate}% from {n} cases ({year_min}–{year_max}); historical Wilson 95% CI {hist_ci_low}–{hist_ci_high}%; Brier {brier}; sources: {sources}.',
  'continuum_registry_cases_elaboration':
      'Exact historical cases underpinning the {n}-case base rate ({successes} outcomes observed): {cases}.',
  'percent_outcome_subtitle': '{lean} — {qualifier}',
  'percent_outcome_phrase': '{phrase} — {qualifier}',
  'continuum_outcome_lead':
      '{percent_phrase} — {lean} outcome ({pct}%): {outcome_qualifier}.',
  'continuum_outcome_regressive': 'regressive percentage, lower chance',
  'continuum_outcome_progressive': 'progressive percentage, higher chance',
  'continuum_conclusion_calibration':
      'Calibrated {lean} headline {pct}% ({outcome_qualifier}; 95% CI {ci_low}–{ci_high}%) = {base_w}% × registry {base_rate}% + {heur_w}% × Chronoflux heuristic {heuristic_pct}%. No polls or betting markets.',
  'cohesion_continuum_forecast': '## THE CONTINUUM — Calibrated Forecast',
  'event_class_civil_unrest': 'civil unrest',
  'event_class_recession': 'recession',
  'event_class_election_upset': 'electoral upset',
  'event_class_cohesion_decline': 'cohesion decline',
  'event_class_policy_passage': 'policy passage',
  'event_class_general_scenario': 'general scenario',
  'event_class_sports_championship': 'sports championship',
  'explainer_percent_lead':
      'The ~{pct}% headline{subject_clause} is not a poll or betting odd. Chronoflux regressive momentum is {reg}% of THE CONTINUUM; σ {shear}/100 and cohesion strain {strain} shape the heuristic. Net momentum {momentum} → {lean}; transport favours {transport}.',
  'explainer_data_points_intro': 'Data points used to construe and calibrate this outcome:',
  'explainer_registry_filter':
      'Outcome registry filter: event class {event_class}, region {region}, {horizon}-day horizon — {n} historical cases matched ({successes} with the adverse outcome observed).',
  'explainer_registry_cases_intro':
      'Exact historical registry cases used in the base rate ({n} cases, {successes} outcomes observed):',
  'explainer_registry_cases_empty':
      'No exact historical registry cases matched this filter; the base rate uses the Chronoflux seed prior until registry rows align.',
  'registry_case_line':
      '{id}: {event_class} in {region}, {horizon}d horizon, posed {year} — {outcome} (source: {source})',
  'registry_case_occurred': 'outcome observed',
  'registry_case_not_occurred': 'outcome not observed',
  'explainer_percent':
      'Calibrated ~{pct}% headline{subject_clause} blends historical base rate with Chronoflux regressive momentum ({reg}% of THE CONTINUUM), shear (σ {shear}/100), and cohesion strain ({strain}). Net momentum {momentum} → {lean}; transport favours {transport}. {forecast_line}',
  'explainer_cohesion':
      'Refined ~{refined}/100 {delta_word} from baseline ~{baseline}/100. THE CONTINUUM: {prog}% progressive / {reg}% regressive — {momentum}. PART THREE: {with_min}–{with_max}/100 with levers vs ~{without}/100 without. {recurrence}',
  'transport_progressive': 'cohesion-building',
  'transport_regressive': 'friction-inducing',
  'momentum_repair': 'favours cohesion repair',
  'momentum_friction': 'signals ongoing friction',
  'delta_improved': 'improved',
  'delta_strained': 'strained',
  'delta_held': 'held near baseline',
  'construct_bullet': '{symbol} {scs}/100 — {label}',
  'label_vortex': 'question framing',
  'label_shear': 'polarisation',
  'label_resistance': 'institutional drag',
  'label_flow': 'trust transport',
  'label_refined': 'PART TWO refined SCS',
  'label_continuum': 'continuum',
  'label_strongest': 'Strongest construct',
  'label_weakest': 'Weakest construct',
  'label_baseline_delta': 'Baseline → refined',
  'label_levers': 'actionable levers in PART THREE',
  'cohesion_title': '# SSUCF Analysis: {title}',
  'cohesion_subtitle':
      'Social Cohesion Analysis under Chronoflux-derived Covariant Continuity',
  'cohesion_topic': 'Topic: {topic}',
  'cohesion_part_one': '## Part One: Baseline Parameter Mapping',
  'cohesion_part_two': '## Part Two: Broader Political Continuum Integration',
  'cohesion_part_three': '## Part Three: Actionable Levers for Friction Reduction',
  'cohesion_vortex': '### Vortex (Initial Conditions)',
  'cohesion_shear': '### Shear (Social Forces)',
  'cohesion_resistance': '### Resistance',
  'cohesion_flow': '### Flow',
  'cohesion_baseline': 'Baseline Cohesion Score: ~{scs}/100',
  'cohesion_weighted': 'Weighted Overall SCS: ~{scs}/100',
  'cohesion_split': 'Regressive: ~{reg}% | Progressive: ~{prog}%',
  'cohesion_bullet_core_input': 'Core input: {text}',
  'cohesion_bullet_social_force': '{text}',
  'cohesion_vortex_mismatch_narrative':
      'Vortex mismatch: High-authority singular lens compresses heterogeneous events (SCS {scs}/100).',
  'cohesion_vortex_signal': 'ω signal: Authority circulation at SCS {scs}/100.',
  'cohesion_p2_vortex_elite_topic':
      'Elite statements on "{topic}" unify condemnation across party lines.',
  'cohesion_p2_vortex_elite_framing':
      'Framing on "{subject}" labels dissent while claiming cohesion (ω {scs}/100).',
  'cohesion_p2_continuum_lean':
      'Continuum integration: ~{reg}% regressive / ~{prog}% progressive lean.',
  'cohesion_p2_shear_elite_vs_public':
      'High elite alignment on "{subject}" vs. bottom-up grievance channels.',
  'cohesion_p2_shear_asymmetric':
      'Asymmetric two-tier perception sustains σ friction (SCS {scs}/100).',
  'cohesion_p2_rf_short_term_calm':
      'Short-term de-escalation possible; medium-term polarisation risk remains ({lean}).',
  'cohesion_p2_rf_trust_transport':
      'Trust transport outruns institutional drag — favourable Jμ path ({lean}).',
  'cohesion_expanded_vortex': '### Expanded Vortex',
  'cohesion_shear_refine': '### Shear Refinement',
  'cohesion_resistance_flow': '### Resistance & Flow',
  'cohesion_refined': 'Refined Cohesion Score: ~{scs}/100',
  'cohesion_interventions': '### Targeted Interventions',
  'cohesion_outcomes': '### Projected Outcomes',
  'cohesion_without': 'Without levers: Continued ~{scs}/100 with recurrence risk.',
  'cohesion_with': 'With levers: {min}–{max}/100 within 3 months.',
  'cohesion_conclusion_heading': '## Conclusion',
  'cohesion_weighted_panel': 'Weighted Overall SCS',
  'cohesion_final_text':
      'Final Summary: Move from narrative compression to differentiated, data-driven responses to rebuild covariant continuity.',
  'cohesion_final_dynamic':
      'Final Summary: Move from narrative compression on "{subject}" to differentiated, data-driven responses to rebuild covariant continuity and reduce social friction.',
  'synopsis_export_title': 'Export complete synopsis',
  'synopsis_export_hint':
      'Download as PDF or Markdown text, or open the full report in your browser — built from your posed scenario.',
  'synopsis_export_button': 'Export synopsis',
  'synopsis_export_pdf': 'PDF',
  'synopsis_export_text': 'Text (.md)',
  'synopsis_export_browser': 'View in browser',
  'synopsis_copy_button': 'Copy to clipboard',
  'synopsis_saved_pdf': 'Synopsis PDF saved',
  'synopsis_saved_text': 'Synopsis text file saved',
  'synopsis_copied': 'Complete synopsis copied to clipboard',
  'synopsis_percent_header': '## Calibrated Percent Chance',
  'synopsis_cohesion_header': '## Social Cohesion Outcome',
  'synopsis_cohesion_line': 'Refined cohesion score: **~{scs}/100**',
  'synopsis_agent_actions': '## Agent-Specific Recommended Actions',
  'synopsis_created': 'Created: {date}',
  'synopsis_region': 'Region focus (ω): {region}',
  'synopsis_mode_percent': 'Analysis mode: Percent chance',
  'synopsis_mode_cohesion': 'Analysis mode: Social cohesion',
  'synopsis_footer': 'Exported from Evolve Chronoflux — paste into MarkdownBin or any Markdown editor.',
  'party_response_section': '## Party Response SCS — Individual Attribution Analysis',
  'party_response_panel_title': 'Party response SCS (linked narrative)',
  'party_refinement_summary':
      'Narrative relies on {count} attributed party response(s). Individual SCS scores refined the overall narrative from ~{before}/100 to ~{after}/100 ({weight}% party-response weight).',
  'party_response_line': '### {party}',
  'party_response_scs':
      'Individual SCS: ~{scs}/100 · Regressive: ~{reg}% | Progressive: ~{prog}% → {lean}',
  'party_response_refined':
      'Refined narrative SCS (party-weighted): ~{before}/100 → ~{after}/100',
  'explainer_how_read': 'How to read this conclusion',
  'part_breakdown_title': 'Per-pathway percent chances',
  'part_breakdown_outcome': 'Toward: {outcome}',
  'part_breakdown_others': 'Others (non-exhaustive)',
  'part_breakdown_note':
      'Shares partition the outcome across pathways (total 100%). Lean is relative to sibling pathways on THE CONTINUUM.',
  'part_breakdown_total': 'Outcome partition total: {total}%',
  'part_breakdown_share_phrase':
      '~{n}% share via {pathway} toward {outcome}',
  'part_breakdown_share_only': '~{n}% share via {pathway}',
  'part_breakdown_lean_line': '{lean} — {qualifier} (continuum {reg}% / {prog}%)',
  'synopsis_part_breakdown_header': '## Per-pathway breakdown (partition = 100%)',
  'cohesion_refined_panel':
      'Refined cohesion score ~{scs}/100 after Parts One–Three',
  'cohesion_continuum_subtitle': '{lean} — {pct}%',
  ...discourseStringsEn,
  ...leanMitigateVariants(discourseStringsEn),
  ...sharedInfoStringsEn,
  ...partThreeSlimEn,
  ...weightConstrualEn,
  ...walletStringsProviderEn,
};

final _es = {
  ..._en,
  'app_subtitle': 'Marco cronoflux de ciencias sociales',
  'splash_tagline': 'Suite completa de gobernanza comunitaria',
  'nav_analysis': 'Análisis',
  'nav_wallet': 'Monedero',
  'nav_voting': 'Votación',
  'nav_credit': 'Crédito',
  'fcg_title': 'Votación del consejo parroquial',
  'fcg_subtitle':
      'Votación FCG para {region} — narrativas de cohesión social de sus análisis previos.',
  'fcg_governance_blurb':
      'La votación parroquial SSUCF usa narrativas Chronoflux para estructurar el debate.',
  'fcg_read_paper': 'documento FCG',
  'fcg_moderator_title': 'Moderador de distrito',
  'fcg_moderator_account_hint':
      'Registre una cartera PERC como Moderador (consulte su Paquete de Moderador de Distrito para instrucciones) para iniciar votaciones y gestionar cuentas de votantes parroquiales.',
  'fcg_signed_in_as': 'Conectado como {user}',
  'fcg_moderator_sign_in_hint':
      'Inicie sesión con una cuenta MOD_* en la pestaña Monedero.',
  'fcg_initiate_title': 'Iniciar votación parroquial',
  'fcg_policy_question': 'Pregunta de política',
  'fcg_policy_question_hint':
      'p. ej. ¿Debe la parroquia adoptar el gravamen de resiliencia?',
  'fcg_analysis_modes': 'Análisis Chronoflux para esta política',
  'fcg_run_cohesion': 'Puntuación de cohesión social (SCS)',
  'fcg_run_percent': 'Probabilidad %',
  'fcg_initiate_button': 'Abrir votación y analizar',
  'fcg_initiate_moderator_only': 'Solo un moderador MOD_* puede abrir una votación.',
  'fcg_active_session': 'Votación parroquial activa',
  'fcg_cohesion_score': 'SCS ~{scs}/100',
  'fcg_percent_chance': '{pct}% probabilidad',
  'fcg_votes_cast': '{cast}/{total} votos emitidos',
  'fcg_vote_support': 'A favor',
  'fcg_vote_oppose': 'En contra',
  'fcg_vote_abstain': 'Abstención',
  'fcg_session_narrative': 'Narrativa de cohesión vinculada',
  'fcg_narrative_picker_title': 'Narrativas de escenarios previos',
  'fcg_narrative_picker_hint':
      'Use textos de cohesión de análisis previos en esta región.',
  'fcg_link_narrative': 'Vincular',
  'fcg_narrative_linked': 'Vinculado',
  'fcg_no_narratives':
      'Sin análisis previos en esta región — complete escenarios en Análisis primero.',
  'fcg_admin_panel_title': 'Panel MOD — inscribir votantes',
  'fcg_admin_panel_hint':
      'Añada la dirección PERC de cada votante a las ranuras 1–30.',
  'fcg_perc_address': 'Dirección PERC',
  'fcg_perc_address_hint': 'percpriv1…',
  'fcg_commit_address': 'Confirmar',
  'fcg_clear_address': 'Borrar',
  'fcg_slot_label': 'Ranura',
  'fcg_slot_empty': 'Sin dirección',
  'fcg_slot_enrolled': 'Inscrito',
  'fcg_slot_roster_title': 'Lista de ranuras',
  'fcg_slot_roster_public_hint':
      'El moderador debe inscribir su dirección PERC antes de votar.',
  'fcg_enrolled_count': '{enrolled}/{total} ranuras inscritas',
  'fcg_your_ballot_title': 'Su papeleta (ranura {slot})',
  'fcg_your_ballot_hint':
      'Está inscrito. Emita un voto sobre la política planteada.',
  'fcg_ballot_recorded': 'Papeleta registrada: {choice}',
  'fcg_not_enrolled_hint':
      'Su dirección PERC aún no está inscrita. Pida al moderador MOD_* que la añada.',
  'fcg_voter_narrative': 'Narrativa de cohesión opcional',
  'fcg_no_narrative': 'Sin narrativa vinculada',
  'fcg_address_committed': 'Dirección PERC confirmada en la ranura.',
  'fcg_address_cleared': 'Ranura borrada.',
  'fcg_vote_recorded': 'Su voto ha sido registrado.',
  'fcg_wallet_not_enrolled': 'Su monedero PERC no está inscrito.',
  'fcg_no_active_vote': 'No hay votación activa.',
  'fcg_invalid_slot': 'Ranura no válida.',
  'fcg_invalid_perc_address': 'Introduzca una dirección PERC válida.',
  'fcg_address_already_enrolled': 'Esa dirección ya está en otra ranura.',
  'fcg_slot_already_enrolled': 'Esta ranura ya tiene una dirección confirmada.',
  'fcg_address_reenrolled': 'Dirección PERC reinscrita.',
  'fcg_slot_released': 'Ranura liberada para reinscripción.',
  'fcg_release_slot': 'Liberar',
  'fcg_reenroll_address': 'Reinscribir',
  'fcg_results_dashboard': 'Panel de resultados en vivo',
  'fcg_quorum_participation':
      'Participación {pct}% (quórum {threshold}%) — {met}',
  'fcg_quorum_met_yes': 'quórum alcanzado',
  'fcg_quorum_met_no': 'quórum no alcanzado',
  'fcg_deciding_votes': '{count} votos decisivos',
  'fcg_support_share': 'Apoyo entre votos decisivos: {pct}%',
  'fcg_outcome_pass': 'Resultado: APROBADO',
  'fcg_outcome_fail': 'Resultado: RECHAZADO',
  'fcg_outcome_tie': 'Resultado: EMPATE',
  'fcg_outcome_no_quorum': 'Resultado: esperando quórum',
  'fcg_outcome_pending': 'Resultado: votación en curso',
  'fcg_export_copy_md': 'Copiar Markdown',
  'fcg_export_copy_json': 'Copiar JSON',
  'fcg_export_save_md': 'Guardar Markdown',
  'fcg_export_copied_md': 'Markdown copiado',
  'fcg_export_copied_json': 'JSON copiado',
  'fcg_export_saved': 'Resultados guardados',
  'fcg_audit_log_title': 'Registro inmutable ({count})',
  'fcg_audit_log_hint': 'Cadena append-only de cada acción de votación.',
  'fcg_audit_chain_tip': 'Tip de cadena: {hash}…',
  'fcg_audit_empty': 'Sin entradas de auditoría.',
  'fcg_close_session': 'Cerrar votación',
  'fcg_history_title': 'Biblioteca de escenarios',
  'fcg_history_hint':
      'Narrativas guardadas al calcular en la pestaña Análisis.',
  'fcg_history_empty': 'Sin ejecuciones guardadas para esta región.',
  'fcg_cancel': 'Cancelar',
  'fcg_analyzing_policy': 'Ejecutando análisis de política…',
  'fcg_session_started': 'Votación abierta — asigne papeletas abajo.',
  'fcg_narrative_linked': 'Narrativa vinculada a esta votación.',
  'fcg_voter_added': 'Votante añadido.',
  'fcg_voter_removed': 'Votante eliminado.',
  'fcg_voters_reset': 'Lista restablecida a 30 reservas.',
  'fcg_session_closed': 'Votación cerrada.',
  'moderator_required': 'Inicie sesión con una cuenta MOD_* primero.',
  'policy_question_required': 'Introduzca una pregunta de política.',
  'analysis_mode_required': 'Seleccione al menos un modo de análisis.',
  'credit_title': 'Crédito y gobernanza',
  'credit_governance_intro': 'Esta aplicación funciona mejor junto al ',
  'credit_governance_link_label': 'Full Community Governance',
  'credit_governance_link_suffix':
      ' como herramienta para debatir y alcanzar conclusiones de consenso en las parroquias.',
  'credit_parish_note':
      'Use el análisis Evolve Chronoflux para estructurar el debate a nivel de parroquia y alcanzar conclusiones compartidas — no como sustituto del proceso democrático, sino como compañero cuantitativo de Full Community Governance.',
  'credit_cohesion_goal':
      'La versión de lanzamiento apunta al 94% de cohesión social en las Islas Británicas.',
  'credit_peace_goal':
      'El compromiso pleno en la Tierra traerá Paz en la Tierra con un 93% de cohesión social dispersa.',
  'credit_attribution_title': 'Atribución',
  'credit_attribution_body':
      'Evolve — creado por rgsneddon, con construcción Grok. Chronoflux Principia — Roy D Herbert. Cadena Perccent bifurcada de la arquitectura de privacidad Beam — Valdok y el CTO de Beam Alex Romanov.',
  'wallet_privacy_title': 'Perccent confidencial Beam',
  'wallet_privacy_note':
      'Perccent se bifurcó de Beam privacy — direcciones confidenciales y saldos protegidos en el dispositivo.',
  'wallet_avg_block_time': 'Tiempo medio por bloque: {time}',
  'wallet_time_confirmations_title': 'Confirmaciones Chronoflux TIME',
  'wallet_supply_infinite': 'Suministro continuo infinito (∞ PERC)',
  'wallet_title': 'Monedero Evolve',
  'wallet_subtitle': 'Cadena Perccent · tesorería por escenarios',
  'wallet_creator_credit':
      'Creado por rgsneddon · con Grok · Roy D Herbert (Chronoflux Principia) · Valdok · CTO de Beam Alex Romanov — bifurcación Perccent con privacidad Beam',
  'wallet_balance_label': 'Saldo disponible',
  'wallet_staking_title': 'Staking acumulativo',
  'wallet_staking_note':
      'El PERC confirmado en cartera gana 5 cent por bloque (10% de la base de 50 cent) tras 1 confirmación de bloque. 1 PERC = 100.000.000 cent (0,00000001 PERC cada uno).',
  'wallet_staking_earned': 'Staking total ganado: {amount} PERC',
  'wallet_burned_title': 'PERC quemado',
  'wallet_burned_note':
      'Cada comisión de envío (0,00000001 PERC) se quema permanentemente — se retira de la circulación en la cadena Perccent.',
  'wallet_burned_total': 'Total quemado: {amount} PERC',
  'wallet_tx_staking': 'Recompensa de staking',
  'wallet_tx_revert': 'Transferencia devuelta',
  'wallet_tx_genesis': 'Renovación génesis (283M PERC Perccent)',
  'wallet_signed_in_as': 'Sesión: {user}',
  'wallet_logout': 'Cerrar sesión',
  'wallet_session_expired':
      'Su sesión de cartera terminó tras 7 minutos sin conexión al nodo semilla — inicie sesión de nuevo para ejecutar análisis SCS.',
  'wallet_treasury_title': 'Emisión de tesorería',
  'wallet_treasury_note':
      'La cadena Perccent avanza con análisis de escenarios — no con construcción Grok ni pulsaciones de campo. La emisión es dinámica: escala con el tiempo medio de bloque y la carga de carteras sobre la base del grifo (hasta 1 PERC / 7 min a 1.0×). Suministro continuo infinito Chronoflux.',
  'wallet_treasury_dynamic_rate':
      'Emisión actual: {rate} PERC/min — carga {load}× · ritmo de bloque {block}×',
  'wallet_treasury_cycle': 'Ciclo de tesorería #{cycle}',
  'wallet_treasury_minted': '{minted} PERC acuñados ({pct}% continuo)',
  'wallet_treasury_remaining': 'Tesorería restante: {amount} PERC',
  'wallet_treasury_pool': 'Fondo de tesorería (grifo): {amount} PERC',
  'wallet_treasury_inflation_epoch': 'Última época de inflación: {time}',
  'wallet_treasury_inflation_next': 'Tiempo hasta la próxima inflación: {wait}',
  'wallet_treasury_inflation_ready': 'Inflación lista — ejecute un escenario',
  'wallet_treasury_inflation_critical':
      'Tesorería en reserva de 1 cent — la emisión alineada se acumula en el próximo escenario',
  'wallet_treasury_send_locked':
      'Los envíos manuales desde evolve_treasury están deshabilitados. La emisión y el grifo continúan.',
  'wallet_treasury_manual_send_note':
      'La tesorería está activa — emisión alineada con el grifo (~0,14285714 PERC/min) y pagos continúan. Los envíos manuales desde evolve_treasury están deshabilitados.',
  'wallet_treasury_offline_note':
      'La tesorería espera el lanzamiento de la cadena. Ejecute un análisis tras el lanzamiento para usar el grifo.',
  'wallet_block_height': 'Altura de bloque: {height}',
  'wallet_scenario_block_height':
      'Tu bloque de escenario: {current} / {max}',
  'wallet_scenario_block_capped':
      'Límite de bloques de escenario alcanzado ({max} análisis)',
  'wallet_seed_block_anchor': 'Ancla semilla: bloque {block}',
  'wallet_faucet_title': 'Grifo de análisis',
  'wallet_faucet_note':
      'Pulse Calcular probabilidad % o Calcular puntuación de cohesión social para retirar xx/100 PERC de la tesorería — xx es el resultado de dos dígitos (porcentaje o SCS) — una vez cada 7 minutos.',
  'wallet_faucet_outcome': 'Recompensa por resultado',
  'wallet_faucet_cooldown': 'Próximo retiro en aproximadamente {wait}',
  'wallet_explorer_link': 'the blockchain explorer',
  'wallet_explorer_block_current': 'Bloque #{height}',
  'wallet_explorer_title': 'the blockchain explorer',
  'wallet_explorer_subtitle': 'Dapp gráfica de la cadena Perccent',
  'wallet_explorer_block_label': 'Bloque actual',
  'wallet_explorer_empty': 'Sin bloques — ejecute un escenario para avanzar la cadena.',
  'wallet_explorer_emission_chart': 'Emisión de tesorería por bloque',
  'wallet_explorer_cumulative_chart': 'Acuñación acumulada de tesorería',
  'wallet_chronoflux_graph_title': 'Cinco variables Chronoflux',
  'wallet_chronoflux_graph_note':
      'Radar pentagonal y series de cinco puntos para ρt, ω, σ, Iτ, Jμ — tiempos alineados al orden de entrada Chronoflux.',
  'wallet_chronoflux_graph_empty':
      'Ejecute un análisis de probabilidad o cohesión social para poblar los gráficos.',
  'wallet_explorer_legend_emission': 'Perccent tesorería (PERC)',
  'wallet_explorer_legend_txs': 'Transacciones',
  'wallet_explorer_history': 'HISTORIAL DE BLOQUES',
  'wallet_explorer_trigger': 'Activado por {user}',
  'wallet_explorer_tx_count': '{count} transacción(es)',
  'wallet_explorer_genesis_renewal': 'Renovación génesis — ciclo #{cycle} (283M PERC Perccent)',
  'wallet_explorer_confirmations': '{count} confirmación(es) requerida(s) — totalmente confirmado',
  'wallet_explorer_confirmed': 'Totalmente confirmado (1 bloque)',
  'wallet_explorer_frame_flow_title': 'División frame-flow lícita — 10.000 block wards',
  'wallet_explorer_frame_flow_subtitle':
      'Ansatz de un vector degenerado descartado; microbloques agrupados en wards de {bundle}.',
  'wallet_explorer_ward_title': 'Wards — explorador dinámico de microbloques',
  'wallet_explorer_ward_subtitle':
      'Cada ward sella {bundle} microbloques Chronoflux. 10.000 wards completan un ciclo de sellado.',
  'wallet_explorer_ward_cycle':
      'Ciclo actual: {completed} / {total} wards — ward #{ward} ({pending} / {bundle} microbloques)',
  'wallet_explorer_ward_lifetime': 'Wards sellados (total): {count}',
  'wallet_explorer_ward_pending':
      'Ward activo #{ward}: {pending} / {bundle} microbloques',
  'wallet_explorer_ward_field_count':
      '{wards} wards en campo — {lit} agrupados ({bundle} microbloques cada uno)',
  'wallet_explorer_ward_legend':
      'Verde = ward sellado · Azul = ward en progreso · Oscuro = pendiente',
  'wallet_explorer_frame_flow_center':
      'División frame-flow lícita — el marco define la rebanada; la deriva permanece dentro',
  'wallet_explorer_frame_flow_status':
      'Estado A2: división frame-flow lícita; proyector solo del marco; deriva medible.',
  'wallet_explorer_shard_count':
      '{visible} / {visible} wards en campo — {lit} agrupados en el ciclo de sellado',
  'wallet_explorer_ward_seal_progress':
      'Ciclo de sellado: {completed} / {total} block wards — ward rellenando {pending} / {bundle} microbloques',
  'wallet_explorer_microblock_height': 'Microbloques de uso justo registrados: {count}',
  'wallet_explorer_microblock_log_title': 'Registro de microbloques de uso justo',
  'wallet_explorer_microblock_log_note':
      'Cada microbloque registra una interacción justa en la app — pulsaciones y ediciones en el formulario de análisis. El registro guarda hasta {bundle} entradas por ward; al completar un ward, se limpia para el siguiente.',
  'wallet_explorer_microblock_log_ward_status':
      'Registro ward {ward}: {count} / {bundle} entradas',
  'wallet_explorer_microblock_log_empty':
      'Sin microbloques aún — escriba en los campos de análisis tras el lanzamiento de la cadena.',
  'wallet_explorer_microblock_log_entry':
      '#{index} ward {ward} · μ{pos} · {time} · {label}{extra}',
  'wallet_explorer_microblock_log_truncated':
      'Mostrando los últimos {shown} de {total} microbloques registrados',
  'wallet_explorer_microblock_log_count': 'Entradas del registro: {count}',
  'wallet_explorer_microblock_fair_usage': 'Uso justo de la app',
  'wallet_explorer_degenerate_title': 'Ansatz de un vector degenerado — no admisible',
  'wallet_explorer_degenerate_body':
      'El mismo vector no puede definir el marco y la deriva espacial a la vez.',
  'wallet_explorer_lawful_title': 'Variables lícitas',
  'wallet_explorer_label_frame': 'Normal de marco nμ define corte',
  'wallet_explorer_label_drift': 'Deriva espacial vμ dentro del corte',
  'wallet_explorer_label_split': 'División nμ vμ = 0 ortogonal',
  'wallet_explorer_label_projector': 'Proyector h(n)μν del marco',
  'wallet_cooldown_popup_title': 'Retiro de tesorería en espera',
  'wallet_cooldown_popup_body':
      'Su monedero ya retiró de la tesorería en los últimos 7 minutos. La cadena avanza con escenarios — su próximo retiro (y bloque) es en aproximadamente {blockWait}. Puede retirar xx/100 PERC de nuevo tras {wait}.',
  'wallet_cooldown_popup_ok': 'OK',
  'wallet_blockchain_awaiting_launch':
      'Conectando al nodo semilla Perccent — las recompensas de escenario se activan al sincronizar.',
  'wallet_blockchain_launch_title': '¡Cadena lanzada!',
  'wallet_blockchain_launch_body':
      'La cadena Perccent está activa. Ejecute escenarios para avanzar bloques.',
  'wallet_blockchain_launch_ok': 'Adelante',
  'wallet_faucet_base': 'Recompensa base',
  'wallet_faucet_bonus': 'Bono por resultado',
  'wallet_faucet_total': 'Total acreditado',
  'wallet_address_label': 'Tu dirección Perccent',
  'wallet_copy_address': 'Copiar dirección',
  'wallet_address_copied': 'Dirección copiada',
  'wallet_transactions_title': 'TRANSACCIONES RECIENTES',
  'wallet_transactions_empty':
      'Ejecuta un análisis de probabilidad o cohesión social en Análisis para recibir tu primer pago Perccent.',
  'wallet_treasury_setup_title': 'Proteger cuenta de tesorería',
  'wallet_treasury_setup_note':
      'La tesorería recibe todas las emisiones. Cree su contraseña ahora (solo la primera vez).',
  'wallet_treasury_username': 'Usuario de tesorería',
  'wallet_password': 'Contraseña',
  'wallet_password_confirm': 'Confirmar contraseña',
  'wallet_create_password': 'Crear contraseña',
  'wallet_login_title': 'Inicio de sesión Evolve Wallet',
  'wallet_register_title': 'Crear su monedero',
  'wallet_register_note':
      'Elija un nombre de usuario y contraseña — su dirección Perccent se genera en este dispositivo.',
  'wallet_choose_username': 'Elija nombre de usuario',
  'wallet_username_hint': 'p. ej. parish_ward_42',
  'wallet_username_rules':
      '3–24 caracteres: minúsculas, números y guiones bajos.',
  'wallet_treasury_setup_link': '¿Tesorero? Proteger cuenta de tesorería',
  'wallet_back_to_sign_in': 'Volver al inicio de sesión',
  'wallet_login_note':
      'Regístrese o inicie sesión para generar su dirección Perccent — obligatorio para usar Evolve.',
  'wallet_app_gate_title': 'Cree su monedero primero',
  'wallet_app_gate_note':
      'Evolve se desbloquea tras registrarse y recibir una dirección Perccent en este dispositivo.',
  'splash_enter_app': 'Entrar en Evolve',
  'splash_preparing_wallet': 'Preparando monedero…',
  'splash_wallet_loading': 'Cargando monedero…',
  'splash_signed_in_as': 'Sesión iniciada como {user}',
  'splash_version_checking': 'Comprobando actualizaciones…',
  'splash_version_latest': 'Tiene la última versión ({version})',
  'splash_version_update':
      'Actualización disponible: {latest} — tiene {current}',
  'splash_version_update_action': 'Obtener la actualización',
  'wallet_username': 'Usuario',
  'wallet_sign_in': 'Iniciar sesión',
  'wallet_register': 'Crear cuenta',
  'wallet_send': 'Enviar',
  'wallet_receive': 'Recibir',
  'wallet_send_title': 'Enviar Perccent',
  'wallet_send_to': 'Dirección PERC destino',
  'wallet_send_to_hint': 'Pegue o escanee la dirección PERC del destinatario',
  'wallet_send_scan_qr': 'Escanear código QR',
  'wallet_send_scan_title': 'Escanear dirección PERC',
  'wallet_send_scan_body':
      'Apunte la cámara al código QR de Recibir de otro usuario para rellenar su dirección PERC.',
  'wallet_send_scan_cancel': 'Cancelar escaneo',
  'wallet_send_scan_invalid': 'Ese código QR no es una dirección PERC válida.',
  'wallet_send_scan_ready': 'Cámara lista — alinee el código QR en el marco.',
  'wallet_send_scan_camera_error':
      'No se pudo acceder a la cámara. Permita el acceso en ajustes del dispositivo e inténtelo de nuevo.',
  'wallet_send_scan_unavailable':
      'El escaneo QR requiere cámara en móvil (Android/iOS). Pegue la dirección PERC.',
  'wallet_camera_permission_title': 'Permitir acceso a la cámara',
  'wallet_camera_permission_body':
      'Evolve necesita la cámara para escanear el código QR de Recibir de otro usuario al enviar Perccent.',
  'wallet_camera_permission_allow': 'Permitir cámara',
  'wallet_camera_permission_not_now': 'Ahora no',
  'wallet_camera_permission_denied':
      'Acceso a la cámara denegado — actívela en ajustes para escanear códigos QR PERC.',
  'wallet_camera_permission_settings_body':
      'El acceso a la cámara está desactivado para Evolve. Abra ajustes y active Cámara.',
  'wallet_camera_permission_open_settings': 'Abrir ajustes',
  'wallet_send_address_pick': 'O elija una dirección conocida',
  'wallet_send_amount': 'Cantidad (PERC)',
  'wallet_send_amount_hint': '0.00000001',
  'wallet_send_amount_helper':
      'Divisible hasta 0.00000001 PERC (1 cent). Todas las carteras pueden recibir desde 1 cent.',
  'wallet_tx_fee_burned': 'Comisión de red quemada',
  'wallet_send_memo': 'Nota (opcional)',
  'wallet_send_confirm': 'Enviar Perccent',
  'wallet_receive_title': 'Recibir Perccent',
  'wallet_receive_note':
      'Otros pueden escanear este código QR o copiar su dirección PERC para enviarle Perccent (PERC).',
  'wallet_receive_qr_hint': 'Escanear para enviar PERC',
  'wallet_tx_treasury': 'Emisión de tesorería',
  'wallet_tx_reward': 'Recompensa de análisis',
  'wallet_tx_sent': 'Enviado a {user}',
  'wallet_tx_received': 'Recibido de {user}',
  'wallet_tx_pending': 'Pendiente',
  'wallet_tx_pending_hint':
      'Ejecute un escenario en la sección Análisis para confirmar esta transferencia y acreditar su saldo.',
  'grok_construe_label': 'CONSTRUIR CON GROK',
  'grok_bar_hint':
      'Requiere X Premium. Escriba la pregunta y pulse COMENZAR CONSTRUCCIÓN GROK — Grok rellena ω/σ/Iτ/Jμ desde el discurso público y datos (sin repetir la pregunta).',
  'grok_sign_in_x': 'INICIAR SESIÓN CON X',
  'grok_preparing_sign_in': 'Preparando inicio de sesión en X…',
  'grok_open_x_tab': 'ABRIR X (NUEVA PESTAÑA)',
  'grok_open_x_body':
      'Pulse el botón para abrir el inicio de sesión de X en una nueva pestaña. '
      'Compatible con DuckDuckGo, Chrome, Edge y su navegador predeterminado. '
      'La pantalla de permisos de X debe decir Evolve. Si aún muestra SSUCF, renombre la app en console.x.com.',
  'grok_oauth_redirect_hint':
      'Si X muestra un error, registre la URL de retorno de su plataforma en console.x.com → su app → OAuth 2.0:',
  'grok_oauth_portal_checklist':
      'Lista en el portal de X:\n'
      '1. console.x.com → su app → App settings → App name: Evolve\n'
      '2. OAuth 2.0 activado en la app\n'
      '3. Tipo Native App\n'
      '4. URLs de retorno (escritorio y Android):\n'
      '   • Escritorio: http://127.0.0.1:8787/auth/callback\n'
      '   • Android: evolve://auth/callback\n'
      '5. Ámbitos: tweet.read, users.read, offline.access',
  'grok_oauth_denied':
      'X denegó el acceso — revise la URL de retorno y OAuth 2.0 en el portal.',
  'grok_dialog_cancel': 'Cancelar',
  'grok_begin_construe': 'COMENZAR CONSTRUCCIÓN GROK',
  'grok_begin_requires_enable': 'Active Construir con Grok antes de comenzar.',
  'grok_construing': 'Grok lee su pregunta y rellena ω/σ/Iτ/Jμ vacíos…',
  'grok_fields_populated': 'Grok rellenó variables vacías desde su pregunta.',
  'grok_fields_ready': 'Todas las variables ω/σ/Iτ/Jμ están listas — pulse Calcular.',
  'grok_filled_badge': 'Grok',
  'constructs_section_title': 'VARIABLES CHRONOFLUX (ω · σ · Iτ · Jμ)',
  'constructs_section_grok':
      'Pulse COMENZAR CONSTRUCCIÓN GROK cuando la pregunta esté completa — ω/σ/Iτ/Jμ desde el discurso público y datos pertinentes.',
  'constructs_section_manual':
      'Complete las cuatro variables o active Grok construal para rellenarlas.',
  'constructs_missing_headline': 'Complete las variables Chronoflux',
  'constructs_missing_body':
      'Con Grok construal desactivado, rellene cada variable antes de Calcular:',
  'status_need_constructs': 'Complete estas variables antes de Calcular: {missing}.',
  'grok_yes': 'Usar',
  'grok_no': 'No usar',
  'grok_connect_title': 'Conectar su cuenta de X',
  'grok_connect_body':
      'Inicie sesión con X en el navegador. Evolve verifica Premium antes de construir en vivo.',
  'grok_starting_proxy': 'Iniciando proxy Grok…',
  'grok_proxy_start_failed': 'No se pudo iniciar el proxy Grok en este dispositivo.',
  'grok_connecting':
      'Complete el inicio de sesión de X en su navegador. Esta ventana y la pestaña del navegador se cerrarán automáticamente al conectarse.',
  'grok_connecting_mobile':
      'Complete el inicio de sesión de X en la pestaña del navegador. Volverá a Evolve automáticamente al conectarse.',
  'grok_connecting_background':
      'Inicio de sesión de X abierto en el navegador. Siga usando Evolve — la conexión se completa automáticamente al autorizar.',
  'grok_connecting_mobile_background':
      'Inicio de sesión de X abierto en el navegador. Vuelva a Evolve cuando quiera — su cuenta se conecta automáticamente tras autorizar.',
  'grok_connect_failed': 'Falló la conexión con X.',
  'grok_connect_cancelled': 'Conexión con X cancelada.',
  'grok_premium_required': 'Se requiere X Premium para construir con Grok.',
  'grok_connected_as': 'Conectado @{user}',
  'grok_proxy_unreachable':
      'Proxy Grok no disponible. Deje Grok en No usar para cálculo sin conexión.',
  'grok_launch_failed': 'No se pudo abrir el inicio de sesión de X.',
  'grok_online_ready': 'Construcción Grok activada.',
  'grok_web_heuristic_ready':
      'Construcción heurística web (@evolve_web) — ω/σ/Iτ/Jμ en blanco se rellenan desde su pregunta. Sin proxy ni X en GitHub Pages.',
  'grok_android_heuristic_ready':
      'Construcción heurística Android (@evolve_android) — ω/σ/Iτ/Jμ en blanco se rellenan desde su pregunta. Proxy integrado no disponible; use Windows para Grok X Premium en vivo.',
  'grok_web_proxy_required':
      'Grok en vivo en la web requiere un proxy Grok alojado (GROK_PROXY_URL) y X Premium. '
      'GitHub Pages usa construcción heurística en el navegador — active Usar.',
  'grok_offline_mode': 'Construcción Grok desactivada — solo Chronoflux local.',
  'grok_construal_applied': 'Sugerencias Grok aplicadas — cálculo completo.',
  'grok_construal_failed': 'Falló la construcción Grok — modo sin conexión.',
  'grok_dialog_ok': 'Aceptar',
  'status_calc_grok_pipeline': 'Construyendo con Grok, luego Chronoflux…',
  'start_fresh': 'REINICIAR',
  'web_grok_inactive_notice':
      'Grok construal no está activo en la versión web de Evolve. Descargue la app de Windows o Android para todas las funciones, o ejecute el cálculo con entradas manuales.',
  'region_select_advice': 'SELECCIONE LA REGIÓN O EL PAÍS QUE DESEA ANALIZAR',
  'posed_question_section': 'SU PREGUNTA',
  'posed_question_label': 'PLANTEE SU PREGUNTA AQUÍ',
  'posed_question_label_cohesion': 'PLANTEE SU PREGUNTA AQUÍ (opcional)',
  'posed_question_hint_cohesion':
      'Opcional en cohesión social — use el enlace narrativo o ω/σ/Iτ/Jμ abajo.',
  'posed_question_hint': 'Su pregunta de escenario para este análisis.',
  'status_need_posed_question': 'Plantee su pregunta en PLANTEE SU PREGUNTA AQUÍ.',
  'region_label': 'Región',
  'language_label': 'Idioma',
  'lang_en': 'English',
  'analysis_mode_heading': 'Elija su análisis',
  'mode_percent': 'Probabilidad %',
  'mode_cohesion': 'Cohesión social',
  'mode_percent_short': 'Probabilidad %',
  'mode_cohesion_short': 'Cohesión social',
  'calc_percent': 'Calcular probabilidad',
  'calc_cohesion': 'Calcular cohesión social',
  'part3_headline_pct': 'PARTE TRES — Acciones recomendadas para el/la {agent}',
  'part3_headline_scs': 'PARTE TRES — Acciones del/de la {agent} para elevar la cohesión',
  'part3_context': 'El/La {agent} — acciones vinculadas a este escenario: {binding}',
  'part3_input_binding': 'Vinculado a sus entradas: {binding}',
  'part3_action_1':
      '{agent}: Convocar una rueda de prensa abierta sobre {subject}{topic_suffix} {shear_hook}',
  'part3_action_2':
      '{agent}: Reunir a las partes interesadas sobre {subject}{topic_suffix} en dos semanas. {resistance_hook}',
  'part3_action_3':
      '{agent}: Anunciar medidas con plazos claros sobre {subject}{topic_suffix} con seguimiento público. {flow_hook}',
  'part3_impact_pct':
      'Estos pasos pueden elevar la estimación de "{subject}" de ~{current}% hacia ~{projected}%.',
  'part3_impact_scs':
      'Estos pasos pueden elevar la cohesión de ~{current}/100 hacia {min}–{max}/100 en 3 meses.',
  'region_focus_banner': 'Enfoque ω: {region} — plantee su pregunta para esta región',
  'region_usa': 'Estados Unidos',
  'grok_conclusion_marker': 'CONCLUSIÓN - EL CONTINUUM:',
  'pct_probability': '~{n}% de probabilidad de {subject}',
  'pct_predictive': '~{n}% de probabilidad de que {subject}',
  'cohesion_final_summary': 'Resumen final:',
  'cohesion_cycle_complete':
      '🌀 Ciclo SSUCF completo. Análisis Evolve Chronoflux a partir del escenario planteado.',
  'grok_reply':
      '{regressive}% regresivo / {progressive}% progresivo en EL CONTINUO. Momento neto {momentum} → inclina {lean}. {marker} {conclusion}',
  'continuum_hints_clause': '; señales discursivas de la pregunta: {hints}',
  'continuum_conclusion_signals':
      'Datos de construal — pregunta planteada: «{question}»; marco {frame}, {polarity}, clase {event_class}, horizonte {horizon} días, región {region}{hints_clause}.',
  'continuum_conclusion_constructs':
      'Chronoflux inferido de la pregunta: ω {vortex_scs}/100 ({w_v}% p), σ {shear_scs}/100 ({w_s}% p), Iτ {res_scs}/100 ({w_r}% p), Jμ {flow_scs}/100 ({w_f}% p) → SCS refinado {refined}/100; EL CONTINUO {reg}% regresivo / {prog}% progresivo → {lean}.',
  'continuum_conclusion_registry':
      'Registro de resultados ({event_class}, {horizon}d): {base_rate}% de {n} casos ({year_min}–{year_max}); IC Wilson histórico 95% {hist_ci_low}–{hist_ci_high}%; Brier {brier}; fuentes: {sources}.',
  'continuum_registry_cases_elaboration':
      'Casos históricos exactos que sustentan la tasa base de {n} casos ({successes} resultados observados): {cases}.',
  'percent_outcome_subtitle': '{lean} — {qualifier}',
  'percent_outcome_phrase': '{phrase} — {qualifier}',
  'continuum_outcome_lead':
      '{percent_phrase} — resultado {lean} ({pct}%): {outcome_qualifier}.',
  'continuum_outcome_regressive': 'porcentaje regresivo, menor probabilidad',
  'continuum_outcome_progressive': 'porcentaje progresivo, mayor probabilidad',
  'continuum_conclusion_calibration':
      'Titular {lean} calibrado {pct}% ({outcome_qualifier}; IC 95% {ci_low}–{ci_high}%) = {base_w}% × registro {base_rate}% + {heur_w}% × heurística Chronoflux {heuristic_pct}%. Sin encuestas ni apuestas.',
  'status_calc_pipeline': 'Ejecutando PARTE UNO → PARTE DOS → PARTE TRES…',
  'part_two_panel_title': 'PARTE DOS — Integración del continuo político',
  'part_two_refined_line':
      'SCS refinado ~{scs}/100 · EL CONTINUO: {reg}% regresivo / {prog}% progresivo → {lean}',
  'part_two_copy': 'Copiar PARTE DOS',
  'part_two_copied': 'PARTE DOS copiada.',
  'explainer_percent_lead':
      'El titular ~{pct}%{subject_clause} no es una encuesta ni una cuota de apuestas. El momento regresivo Chronoflux es {reg}% de EL CONTINUO; σ {shear}/100 y la tensión de cohesión {strain} moldean la heurística. Momento neto {momentum} → {lean}; el transporte favorece {transport}.',
  'explainer_data_points_intro':
      'Puntos de datos usados para construir y calibrar este resultado:',
  'explainer_registry_filter':
      'Filtro del registro de resultados: clase {event_class}, región {region}, horizonte {horizon} días — {n} casos históricos coincidentes ({successes} con el resultado adverso observado).',
  'explainer_registry_cases_intro':
      'Casos históricos exactos del registro usados en la tasa base ({n} casos, {successes} resultados observados):',
  'explainer_registry_cases_empty':
      'Ningún caso histórico exacto coincidió con este filtro; la tasa base usa el prior semilla Chronoflux hasta que haya filas alineadas.',
  'registry_case_line':
      '{id}: {event_class} en {region}, horizonte {horizon}d, planteado {year} — {outcome} (fuente: {source})',
  'registry_case_occurred': 'resultado observado',
  'registry_case_not_occurred': 'resultado no observado',
  'explainer_how_read': 'Cómo leer esta conclusión',
  'cohesion_part_one': '## Parte Uno: Mapeo de parámetros base',
  'cohesion_part_two': '## Parte Dos: Integración del continuo político',
  'cohesion_part_three': '## Parte Tres: Palancas de reducción de fricción',
  'cohesion_title': '# Análisis SSUCF: {title}',
  'cohesion_baseline': 'Puntuación de cohesión base: ~{scs}/100',
  'cohesion_refined': 'Puntuación de cohesión refinada: ~{scs}/100',
  'cohesion_refined_panel':
      'Puntuación refinada\nPARTE UNO / DOS / TRES (~{scs}/100)',
  'cohesion_continuum_subtitle': '{lean} — {pct}%',
  'cohesion_subtitle':
      'Análisis de cohesión social bajo continuidad covariante derivada de Chronoflux',
  'cohesion_topic': 'Tema: {topic}',
  'cohesion_vortex': '### Vórtice (condiciones iniciales)',
  'cohesion_shear': '### Cizalla (fuerzas sociales)',
  'cohesion_resistance': '### Resistencia',
  'cohesion_flow': '### Flujo',
  'cohesion_weighted': 'SCS global ponderado: ~{scs}/100',
  'cohesion_split': 'Regresivo: ~{reg}% | Progresivo: ~{prog}%',
  'cohesion_expanded_vortex': '### Vórtice ampliado',
  'cohesion_shear_refine': '### Refinamiento de cizalla',
  'cohesion_resistance_flow': '### Resistencia y flujo',
  'cohesion_interventions': '### Intervenciones dirigidas',
  'cohesion_outcomes': '### Resultados proyectados',
  'cohesion_without':
      'Sin palancas: continúa ~{scs}/100 con riesgo de recurrencia.',
  'cohesion_with': 'Con palancas: {min}–{max}/100 en 3 meses.',
  'cohesion_conclusion_heading': '## Conclusión',
  'cohesion_weighted_panel': 'SCS global ponderado',
  'cohesion_final_text':
      'Resumen final: pasar de la compresión narrativa a respuestas diferenciadas basadas en datos para reconstruir la continuidad covariante.',
  'cohesion_final_dynamic':
      'Resumen final: pasar de la compresión narrativa sobre «{subject}» a respuestas diferenciadas basadas en datos para reconstruir la continuidad covariante y reducir la fricción social.',
  'synopsis_export_title': 'Exportar sinopsis completa',
  'synopsis_export_hint':
      'Descargue como PDF o texto Markdown, o abra el informe completo en el navegador — basado en su escenario planteado.',
  'synopsis_export_button': 'Exportar sinopsis',
  'synopsis_export_pdf': 'PDF',
  'synopsis_export_text': 'Texto (.md)',
  'synopsis_export_browser': 'Ver en navegador',
  'synopsis_copy_button': 'Copiar al portapapeles',
  'synopsis_saved_pdf': 'PDF de sinopsis guardado',
  'synopsis_saved_text': 'Archivo de texto guardado',
  'synopsis_copied': 'Sinopsis completa copiada al portapapeles',
  'synopsis_percent_header': '## Probabilidad calibrada',
  'synopsis_cohesion_header': '## Resultado de cohesión social',
  'synopsis_cohesion_line': 'Puntuación de cohesión refinada: **~{scs}/100**',
  'synopsis_agent_actions': '## Acciones recomendadas específicas del agente',
  'synopsis_created': 'Creado: {date}',
  'synopsis_region': 'Enfoque de región (ω): {region}',
  'synopsis_mode_percent': 'Modo de análisis: Probabilidad %',
  'synopsis_mode_cohesion': 'Modo de análisis: Cohesión social',
  'synopsis_footer':
      'Exportado desde Evolve Chronoflux — pegue en MarkdownBin o cualquier editor Markdown.',
  'party_response_section': '## SCS de respuestas de partes — análisis de atribución individual',
  'party_response_panel_title': 'SCS de respuestas de partes (narrativa vinculada)',
  'party_refinement_summary':
      'La narrativa depende de {count} respuesta(s) atribuida(s). Las puntuaciones SCS individuales refinan la narrativa global de ~{before}/100 a ~{after}/100 (peso {weight}%).',
  'party_response_line': '### {party}',
  'party_response_scs':
      'SCS individual: ~{scs}/100 · Regresivo: ~{reg}% | Progresivo: ~{prog}% → {lean}',
  'party_response_refined':
      'SCS narrativo refinado (ponderado por partes): ~{before}/100 → ~{after}/100',
  'obs_vortex':
      'Vórtice observado (ω): circulación para "{subject}" en {region} (SCS {scs}/100).',
  'obs_vortex_relative':
      'Vórtice observado (ω): "{vortex}" relativo a "{subject}" en {region} (SCS {scs}/100).',
  'obs_shear':
      'Cizalla observada (σ): capa de sesgo sobre "{subject}" en {region} (SCS {scs}/100).',
  'obs_resistance':
      'Resistencia observada (Iτ): tensión institucional sobre "{subject}" en {region} (SCS {scs}/100).',
  'obs_flow':
      'Flujo observado (Jμ): transporte de confianza sobre "{subject}" en {region} (SCS {scs}/100).',
  'part_two_vortex_question':
      'Encuadre de élite sobre «{subject}» comprime lecturas competidoras (ω {scs}/100).',
  'part_two_vortex_topic':
      'Narrativa institucional unificada sobre «{topic}» estrecha el debate público (ω {scs}/100).',
  'part_two_shear_question':
      'Polarización sobre «{subject}» — {polarity} (σ {scs}/100).',
  'part_two_resistance_flow_question':
      '{transport}; inclinación neta {lean} (Iτ {res_scs}/100, Jμ {flow_scs}/100).',
  'part_two_hint_suffix': 'Señal del escenario: {hint}.',
  'part_two_frame_probability': 'marco probabilístico',
  'part_two_frame_predictive': 'trayectoria predictiva',
  'part_two_frame_magnitude': 'estimación de magnitud',
  'part_two_frame_descriptive': 'escenario',
  'part_two_polarity_adverse': 'eleva la fricción en resultados adversos',
  'part_two_polarity_favourable': 'favorece vías de reparación de cohesión',
  'part_two_polarity_open': 'equilibra lecturas de élite y público',
  'part_two_transport_flow_dominant':
      'el transporte de confianza supera el arrastre institucional en este escenario',
  'part_two_transport_resistance_dominant':
      'el arrastre institucional domina el transporte de confianza en este escenario',
  'part_two_transport_contested_adverse':
      'transporte disputado con sesgo de fricción hacia resolución adversa',
  'part_two_transport_contested':
      'transporte disputado — ni arrastre ni flujo dominan claramente',
  'intervention_1':
      'Diferenciación granular — reconocer eventos pacíficos por separado del desorden.',
  'intervention_2':
      'Participación transparente con datos — paneles públicos y foros comunitarios.',
  'intervention_3':
      'Condena equilibrada — abordar preocupaciones de todos los bandos con datos.',
  'intervention_4':
      'Ajustes de política — revisar programas con aportación local.',
  ...discourseStringsEs,
  ...leanMitigateVariants(discourseStringsEs),
  ...sharedInfoStringsEs,
  ...partThreeSlimEs,
  ...weightConstrualEs,
  ...walletStringsEs,
  ...walletStringsProviderEs,
};

final _fr = {
  ..._en,
  'app_subtitle': 'Cadre chronoflux des sciences sociales',
  'region_label': 'Région',
  'language_label': 'Langue',
  'mode_percent': 'Probabilité %',
  'mode_cohesion': 'Cohésion sociale',
  'calc_percent': 'Calculer la probabilité',
  'calc_cohesion': 'Calculer la cohésion sociale',
  'part3_headline_pct': 'PARTIE TROIS — Actions recommandées pour le/la {agent}',
  'part3_headline_scs': 'PARTIE TROIS — Actions du/de la {agent} pour renforcer la cohésion',
  'part3_context': 'Le/La {agent} — mesures liées à ce scénario : {binding}',
  'part3_input_binding': 'Lié à vos entrées : {binding}',
  'grok_conclusion_marker': 'CONCLUSION - LE CONTINUUM :',
  'pct_probability': '~{n}% de chance de {subject}',
  'pct_predictive': '~{n}% de probabilité que {subject}',
  'cohesion_final_summary': 'Résumé final :',
  'explainer_how_read': 'Comment lire cette conclusion',
  'part3_action_1':
      '{agent} : Tenir un point presse ouvert sur {subject}{topic_suffix} {shear_hook}',
  'part3_action_2':
      '{agent} : Réunir les parties concernées sur {subject}{topic_suffix} sous deux semaines. {resistance_hook}',
  'part3_action_3':
      '{agent} : Annoncer des mesures datées sur {subject}{topic_suffix} avec suivi public. {flow_hook}',
  ...sharedInfoStringsFr,
  ...discourseStringsFr,
  ...leanMitigateVariants(discourseStringsFr),
  ...partThreeSlimFr,
  ...weightConstrualFr,
  ...analysisUiStringsFr,
  ...fcgStringsFr,
  ...resultsUiStringsFr,
  ...walletStringsFr,
  ...walletStringsProviderFr,
};

final _de = {
  ..._en,
  'app_subtitle': 'Chronoflux-Rahmen für Sozialwissenschaften',
  'region_label': 'Region',
  'language_label': 'Sprache',
  'mode_percent': 'Wahrscheinlichkeit %',
  'mode_cohesion': 'Soziale Kohäsion',
  'calc_percent': 'Wahrscheinlichkeit berechnen',
  'calc_cohesion': 'Kohäsion berechnen',
  'part3_headline_pct': 'TEIL DREI — Empfohlene Maßnahmen für {agent}',
  'part3_headline_scs': 'TEIL DREI — Maßnahmen für {agent} zur Stärkung der Kohäsion',
  'part3_context': '{agent} — Maßnahmen für dieses Szenario: {binding}',
  'part3_input_binding': 'Gebunden an Ihre Eingaben: {binding}',
  'grok_conclusion_marker': 'FAZIT - DAS CONTINUUM:',
  'pct_probability': '~{n}% Wahrscheinlichkeit für {subject}',
  'explainer_how_read': 'So lesen Sie diese Schlussfolgerung',
  ...sharedInfoStringsDe,
  ...discourseStringsDe,
  ...leanMitigateVariants(discourseStringsDe),
  ...partThreeSlimDe,
  ...weightConstrualDe,
  ...analysisUiStringsDe,
  ...fcgStringsDe,
  ...resultsUiStringsDe,
  ...walletStringsDe,
  ...walletStringsProviderDe,
};

final _pt = {
  ..._en,
  'app_subtitle': 'Framework cronoflux de ciências sociais',
  'region_label': 'Região',
  'language_label': 'Idioma',
  'mode_percent': 'Probabilidade %',
  'mode_cohesion': 'Coesão social',
  'calc_percent': 'Calcular probabilidade',
  'calc_cohesion': 'Calcular coesão social',
  'part3_headline_pct': 'PARTE TRÊS — Ações recomendadas para o/a {agent}',
  'part3_headline_scs': 'PARTE TRÊS — Ações do/a {agent} para elevar a coesão',
  'part3_context': 'O/A {agent} — ações ligadas a este cenário: {binding}',
  'part3_input_binding': 'Ligado às suas entradas: {binding}',
  ...sharedInfoStringsPt,
  ...discourseStringsPt,
  ...leanMitigateVariants(discourseStringsPt),
  ...partThreeSlimPt,
  ...weightConstrualPt,
  ...analysisUiStringsPt,
  ...fcgStringsPt,
  ...resultsUiStringsPt,
  ...walletStringsPt,
  ...walletStringsProviderPt,
};

final _ar = {
  ..._en,
  'app_subtitle': 'إطار زمن التدفق للعلوم الاجتماعية',
  'region_label': 'المنطقة',
  'language_label': 'اللغة',
  'mode_percent': 'احتمال النسبة',
  'mode_cohesion': 'درجة التماسك الاجتماعي',
  'calc_percent': 'احسب احتمال النسبة',
  'calc_cohesion': 'احسب درجة التماسك',
  'part3_headline_pct': 'الجزء الثالث — إجراءات موصى بها لـ{agent}',
  'part3_headline_scs': 'الجزء الثالث — إجراءات {agent} لرفع التماسك',
  'part3_context': '{agent} — إجراءات مرتبطة بهذا السيناريو: {binding}',
  'part3_input_binding': 'مرتبط بمدخلاتك: {binding}',
  'grok_conclusion_marker': 'الخلاصة - الcontinuum:',
  'pct_probability': '~{n}% احتمال {subject}',
  'explainer_how_read': 'كيفية قراءة هذه الخلاصة',
  ...sharedInfoStringsAr,
  ...discourseStringsAr,
  ...leanMitigateVariants(discourseStringsAr),
  ...partThreeSlimAr,
  ...weightConstrualAr,
  ...analysisUiStringsAr,
  ...fcgStringsAr,
  ...resultsUiStringsAr,
  ...walletStringsAr,
  ...walletStringsProviderAr,
};

final _zh = {
  ..._en,
  'app_subtitle': '社会科学时流框架',
  'region_label': '地区',
  'language_label': '语言',
  'mode_percent': '概率百分比',
  'mode_cohesion': '社会凝聚力评分',
  'calc_percent': '计算概率',
  'calc_cohesion': '计算社会凝聚力',
  'part3_headline_pct': '第三部分 — 建议{agent}采取的行动',
  'part3_headline_scs': '第三部分 — {agent}提升凝聚力的行动',
  'part3_context': '{agent} — 与此情景相关的行动：{binding}',
  'part3_input_binding': '绑定到您的输入：{binding}',
  'grok_conclusion_marker': '结论 - 连续体：',
  'pct_probability': '~{n}% 的可能性：{subject}',
  'pct_predictive': '~{n}% 的可能性：{subject}',
  'cohesion_final_summary': '最终总结：',
  'explainer_how_read': '如何理解此结论',
  'region_focus_banner': 'ω 焦点：{region} — 请针对该地区提出问题',
  ...sharedInfoStringsZh,
  ...discourseStringsZh,
  ...leanMitigateVariants(discourseStringsZh),
  ...partThreeSlimZh,
  ...weightConstrualZh,
  ...analysisUiStringsZh,
  ...fcgStringsZh,
  ...resultsUiStringsZh,
  ...walletStringsZh,
  ...walletStringsProviderZh,
};

final _hi = {
  ..._en,
  'app_subtitle': 'सामाजिक विज्ञान क्रोनोफ्लक्स ढांचा',
  'region_label': 'क्षेत्र',
  'language_label': 'भाषा',
  'mode_percent': 'प्रतिशत संभावना',
  'mode_cohesion': 'सामाजिक सामंजस्य स्कोर',
  'calc_percent': 'प्रतिशत संभावना गणना',
  'calc_cohesion': 'सामंजस्य स्कोर गणना',
  'part3_headline_pct': 'भाग तीन — {agent} के लिए अनुशंसित कार्य',
  'part3_headline_scs': 'भाग तीन — सामंजस्य बढ़ाने के लिए {agent} के कार्य',
  'part3_context': '{agent} — इस परिदृश्य से जुड़े कार्य: {binding}',
  'part3_input_binding': 'आपके इनपुट से बंधा: {binding}',
  ...sharedInfoStringsHi,
  ...discourseStringsHi,
  ...leanMitigateVariants(discourseStringsHi),
  ...partThreeSlimHi,
  ...weightConstrualHi,
  ...analysisUiStringsHi,
  ...fcgStringsHi,
  ...resultsUiStringsHi,
  ...walletStringsHi,
  ...walletStringsProviderHi,
};

final _ja = {
  ..._en,
  'app_subtitle': '社会科学クロノフラックス・フレームワーク',
  'region_label': '地域',
  'language_label': '言語',
  'mode_percent': '確率パーセント',
  'mode_cohesion': '社会結束スコア',
  'calc_percent': '確率を計算',
  'calc_cohesion': '結束スコアを計算',
  'part3_headline_pct': 'パートスリー — {agent}への推奨アクション',
  'part3_headline_scs': 'パートスリー — 結束向上のための{agent}のアクション',
  'part3_context': '{agent} — このシナリオに紐づくアクション：{binding}',
  'part3_input_binding': '入力に紐づけ：{binding}',
  'grok_conclusion_marker': '結論 - 連続体：',
  'pct_probability': '~{n}% の確率：{subject}',
  'explainer_how_read': 'この結論の読み方',
  ...sharedInfoStringsJa,
  ...discourseStringsJa,
  ...leanMitigateVariants(discourseStringsJa),
  ...partThreeSlimJa,
  ...weightConstrualJa,
  ...analysisUiStringsJa,
  ...fcgStringsJa,
  ...resultsUiStringsJa,
  ...walletStringsJa,
  ...walletStringsProviderJa,
};