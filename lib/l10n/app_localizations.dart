import '../models/locale_config.dart';
import '../services/scenario_input_profile.dart';
import '../services/scenario_lean_context.dart';
import 'discourse_strings.dart';
import 'part_three_slim_strings.dart';
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
  'nav_analysis': 'Analysis',
  'nav_wallet': 'Wallet',
  'wallet_title': 'Evolve Wallet',
  'wallet_subtitle': 'PERC chain · scenario-driven treasury',
  'wallet_balance_label': 'Available balance',
  'wallet_signed_in_as': 'Signed in as {user}',
  'wallet_logout': 'Sign out',
  'wallet_treasury_title': 'Treasury emission',
  'wallet_treasury_note':
      'Chain advances only when scenarios run. Treasury earns 1 PERC per elapsed second (first block: 1 PERC) until ~286M cap.',
  'wallet_treasury_minted': '{minted} / {cap} PERC minted ({pct}%)',
  'wallet_treasury_remaining': 'Treasury remaining: {amount} PERC',
  'wallet_treasury_pool': 'Treasury pool (faucet): {amount} PERC',
  'wallet_block_height': 'Block height: {height}',
  'wallet_faucet_title': 'Scenario faucet',
  'wallet_faucet_note':
      'Any signed-in wallet may draw 0.00000050 PERC (plus outcome bonus) from treasury once every 450 minutes when a scenario completes.',
  'wallet_faucet_cooldown': 'Next treasury draw in approximately {wait}',
  'wallet_explorer_link': 'the blockchain explorer',
  'wallet_explorer_block_current': 'Block #{height}',
  'wallet_explorer_title': 'the blockchain explorer',
  'wallet_explorer_subtitle': 'Graph-based PERC chain dapp',
  'wallet_explorer_block_label': 'Current block',
  'wallet_explorer_empty': 'No blocks yet — run a scenario to advance the chain.',
  'wallet_explorer_emission_chart': 'Treasury emission per block',
  'wallet_explorer_cumulative_chart': 'Cumulative treasury minted',
  'wallet_explorer_legend_emission': 'Treasury PERC',
  'wallet_explorer_legend_txs': 'Transactions',
  'wallet_explorer_history': 'BLOCK HISTORY',
  'wallet_explorer_trigger': 'Triggered by {user}',
  'wallet_explorer_tx_count': '{count} transaction(s)',
  'wallet_cooldown_popup_title': 'Treasury draw on cooldown',
  'wallet_cooldown_popup_body':
      'Your wallet already drew from treasury within the last 450 minutes. The blockchain advances on scenarios — your next eligible draw (and block) is in approximately {blockWait}. You can draw 0.00000050 PERC again after {wait}.',
  'wallet_cooldown_popup_ok': 'OK',
  'wallet_faucet_base': 'Base reward',
  'wallet_faucet_bonus': 'Outcome bonus',
  'wallet_faucet_total': 'Total credited',
  'wallet_address_label': 'Your PERC address',
  'wallet_copy_address': 'Copy address',
  'wallet_address_copied': 'Address copied',
  'wallet_transactions_title': 'RECENT TRANSACTIONS',
  'wallet_transactions_empty':
      'Run a scenario on the Analysis tab to receive your first PERC faucet payout.',
  'wallet_treasury_setup_title': 'Secure treasury account',
  'wallet_treasury_setup_note':
      'Treasury holder rgsneddon receives all scenario-driven emissions. Create your password now (first use only).',
  'wallet_treasury_username': 'Treasury username',
  'wallet_password': 'Password',
  'wallet_password_confirm': 'Confirm password',
  'wallet_create_password': 'Create password',
  'wallet_login_title': 'Evolve Wallet sign-in',
  'wallet_login_note':
      'Each app install keeps local accounts. Sign in or register a new username.',
  'wallet_username': 'Username',
  'wallet_sign_in': 'Sign in',
  'wallet_register': 'Create account',
  'wallet_send': 'Send',
  'wallet_receive': 'Receive',
  'wallet_send_title': 'Send PERC',
  'wallet_send_to': 'To username',
  'wallet_send_amount': 'Amount (PERC)',
  'wallet_send_memo': 'Memo (optional)',
  'wallet_send_confirm': 'Send PERC',
  'wallet_receive_title': 'Receive PERC',
  'wallet_receive_note': 'Share your username or address so others can send PERC to you.',
  'wallet_tx_treasury': 'Treasury emission',
  'wallet_tx_reward': 'Scenario reward',
  'wallet_tx_sent': 'Sent to {user}',
  'wallet_tx_received': 'Received from {user}',
  'license_panel_title': 'License & Chronoflux attribution',
  'license_dialog_title': 'Evolve License',
  'license_chronoflux_attribution':
      'The Chronoflux Principia, realised by Roy D Herbert, is a core mechanical part of the Evolve framework. The hydrodynamic constructs, continuum mechanics, and analysis pipeline derive from and operate through that Principia.',
  'license_copyright': 'Copyright (c) 2026 rgsneddon. All rights reserved.',
  'license_dual_summary':
      'Proprietary / dual license: personal non-commercial use permitted under LICENSE; commercial use requires a separate Commercial License (ra5kul@protonmail.com).',
  'license_view_full': 'View full license',
  'grok_construe_label': 'GROK CONSTRUE',
  'grok_bar_hint':
      'Requires X Premium. Pose your full question, then tap BEGIN GROK CONSTRUE — Grok fills blank ω/σ/Iτ/Jμ from live discourse and data (not by repeating your question). Your field text is never overwritten.',
  'grok_sign_in_x': 'SIGN IN WITH X',
  'grok_preparing_sign_in': 'Preparing X sign-in…',
  'grok_open_x_tab': 'OPEN X SIGN-IN (NEW TAB)',
  'grok_open_x_body':
      'Tap the button below to open X login in a new tab. '
      'This works with DuckDuckGo, Chrome, Edge, Firefox, and your default browser. '
      'The X permission screen should say Evolve wants to access your account. '
      'If it still shows SSUCF, rename your app at console.x.com (see checklist below). '
      'After you sign in, return here — Evolve will detect your Premium account.',
  'grok_oauth_redirect_hint':
      'If X says “Something went wrong”, register this exact callback in console.x.com → your app → OAuth 2.0 → Callback URLs (use 127.0.0.1, not localhost):',
  'grok_oauth_portal_checklist':
      'X Developer Portal checklist:\n'
      '1. console.x.com → your app → App settings → App name: Evolve (replaces SSUCF in the sign-in popup)\n'
      '2. User authentication settings → OAuth 2.0 enabled\n'
      '3. App type: Native App (desktop) or Web App with the callback below\n'
      '4. Callback URL exactly: http://127.0.0.1:8787/auth/callback\n'
      '5. Scopes allowed: tweet.read, users.read, offline.access\n'
      '6. Copy Client ID into grok_proxy.local.env next to evolve.exe (Windows) or project root',
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
  'grok_construing': 'Grok is reading your question and filling blank ω/σ/Iτ/Jμ fields…',
  'grok_fields_populated': 'Grok filled blank variables from your posed question.',
  'grok_fields_ready': 'All ω/σ/Iτ/Jμ variables are ready — tap Calculate when you are.',
  'grok_filled_badge': 'Grok',
  'constructs_section_title': 'CHRONOFLUX VARIABLES (ω · σ · Iτ · Jμ)',
  'constructs_section_grok':
      'Tap BEGIN GROK CONSTRUE (above) after your full question is written — blank ω/σ/Iτ/Jμ fill from live discourse, establishment framing, and pertinent data (not by repeating your question).',
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
      'Grok construe is not active on the web version of Evolve. Download the Windows or Android app for full capabilities, or run the calculation with manual inputs.',
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
  'outcome_context_hint': 'e.g. to end the recession, to win the election',
  'outcome_part_label': 'Pathway {n}',
  'outcome_part_hint': 'e.g. austerity, stimulus, status quo',
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
  'mode_percent': 'Percent Chance',
  'mode_cohesion': 'Social Cohesion Score',
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
  'cohesion_cycle_complete': '🌀 Evolve Cycle Complete.',
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
      'Continuum vortex on "{question}": {frame} authority compression on "{subject}" (ω {weight}% salience, SCS {scs}/100).',
  'part_two_vortex_topic':
      'Continuum vortex on "{question}": elite framing of "{topic}" compresses "{subject}" into one narrative lane (ω {weight}% salience, SCS {scs}/100).',
  'part_two_shear_question':
      'Shear on "{question}": {frame} polarisation on "{subject}" — {polarity} (σ {weight}% salience, SCS {scs}/100).',
  'part_two_resistance_flow_question':
      'Resistance & flow for "{question}": Iτ drag ({res_weight}% salience, SCS {res_scs}/100) vs Jμ transport ({flow_weight}% salience, SCS {flow_scs}/100) — {transport}; net lean {lean}.',
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
  'cohesion_title': 'Evolve Analysis: {title}',
  'cohesion_subtitle': 'Social cohesion under Chronoflux covariant continuity',
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
  'cohesion_expanded_vortex': '### Expanded Vortex',
  'cohesion_shear_refine': '### Shear Refinement',
  'cohesion_resistance_flow': '### Resistance & Flow',
  'cohesion_refined': 'Refined Cohesion Score: ~{scs}/100',
  'cohesion_interventions': '### Targeted Interventions',
  'cohesion_outcomes': '### Projected Outcomes',
  'cohesion_without': 'Without levers: Continued ~{scs}/100 with recurrence risk.',
  'cohesion_with': 'With levers: {min}–{max}/100 within 3 months.',
  'cohesion_final_text':
      'Final Summary: Move from narrative compression to differentiated, data-driven responses to rebuild covariant continuity.',
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
      'Refined cohesion score\nPART ONE / TWO / THREE complete (~{scs}/100)',
  'cohesion_continuum_subtitle': '{lean} — {pct}%',
  ...discourseStringsEn,
  ...leanMitigateVariants(discourseStringsEn),
  ...sharedInfoStringsEn,
  ...partThreeSlimEn,
  ...weightConstrualEn,
};

final _es = {
  ..._en,
  'app_subtitle': 'Marco cronoflux de ciencias sociales',
  'nav_analysis': 'Análisis',
  'nav_wallet': 'Monedero',
  'wallet_title': 'Monedero Evolve',
  'wallet_subtitle': 'Cadena PERC · tesorería por escenarios',
  'wallet_balance_label': 'Saldo disponible',
  'wallet_signed_in_as': 'Sesión: {user}',
  'wallet_logout': 'Cerrar sesión',
  'wallet_treasury_title': 'Emisión de tesorería',
  'wallet_treasury_note':
      'La cadena avanza solo al ejecutar escenarios. Tesorería gana 1 PERC por segundo transcurrido (primer bloque: 1 PERC) hasta ~286M.',
  'wallet_treasury_minted': '{minted} / {cap} PERC acuñados ({pct}%)',
  'wallet_treasury_remaining': 'Tesorería restante: {amount} PERC',
  'wallet_treasury_pool': 'Fondo de tesorería (grifo): {amount} PERC',
  'wallet_block_height': 'Altura de bloque: {height}',
  'wallet_faucet_title': 'Grifo de escenarios',
  'wallet_faucet_note':
      'Cualquier monedero conectado puede retirar 0,00000050 PERC (más bono) de la tesorería una vez cada 450 minutos al completar un escenario.',
  'wallet_faucet_cooldown': 'Próximo retiro en aproximadamente {wait}',
  'wallet_explorer_link': 'the blockchain explorer',
  'wallet_explorer_block_current': 'Bloque #{height}',
  'wallet_explorer_title': 'the blockchain explorer',
  'wallet_explorer_subtitle': 'Dapp gráfica de la cadena PERC',
  'wallet_explorer_block_label': 'Bloque actual',
  'wallet_explorer_empty': 'Sin bloques — ejecute un escenario para avanzar la cadena.',
  'wallet_explorer_emission_chart': 'Emisión de tesorería por bloque',
  'wallet_explorer_cumulative_chart': 'Acuñación acumulada de tesorería',
  'wallet_explorer_legend_emission': 'PERC tesorería',
  'wallet_explorer_legend_txs': 'Transacciones',
  'wallet_explorer_history': 'HISTORIAL DE BLOQUES',
  'wallet_explorer_trigger': 'Activado por {user}',
  'wallet_explorer_tx_count': '{count} transacción(es)',
  'wallet_cooldown_popup_title': 'Retiro de tesorería en espera',
  'wallet_cooldown_popup_body':
      'Su monedero ya retiró de la tesorería en los últimos 450 minutos. La cadena avanza con escenarios — su próximo retiro (y bloque) es en aproximadamente {blockWait}. Puede retirar 0,00000050 PERC de nuevo tras {wait}.',
  'wallet_cooldown_popup_ok': 'OK',
  'wallet_faucet_base': 'Recompensa base',
  'wallet_faucet_bonus': 'Bono por resultado',
  'wallet_faucet_total': 'Total acreditado',
  'wallet_address_label': 'Tu dirección PERC',
  'wallet_copy_address': 'Copiar dirección',
  'wallet_address_copied': 'Dirección copiada',
  'wallet_transactions_title': 'TRANSACCIONES RECIENTES',
  'wallet_transactions_empty':
      'Ejecuta un escenario en Análisis para recibir tu primer pago PERC.',
  'wallet_treasury_setup_title': 'Proteger cuenta de tesorería',
  'wallet_treasury_setup_note':
      'La tesorería rgsneddon recibe todas las emisiones. Cree su contraseña ahora (solo la primera vez).',
  'wallet_treasury_username': 'Usuario de tesorería',
  'wallet_password': 'Contraseña',
  'wallet_password_confirm': 'Confirmar contraseña',
  'wallet_create_password': 'Crear contraseña',
  'wallet_login_title': 'Inicio de sesión Evolve Wallet',
  'wallet_login_note':
      'Cada instalación guarda cuentas locales. Inicie sesión o registre un usuario nuevo.',
  'wallet_username': 'Usuario',
  'wallet_sign_in': 'Iniciar sesión',
  'wallet_register': 'Crear cuenta',
  'wallet_send': 'Enviar',
  'wallet_receive': 'Recibir',
  'wallet_send_title': 'Enviar PERC',
  'wallet_send_to': 'Usuario destino',
  'wallet_send_amount': 'Cantidad (PERC)',
  'wallet_send_memo': 'Nota (opcional)',
  'wallet_send_confirm': 'Enviar PERC',
  'wallet_receive_title': 'Recibir PERC',
  'wallet_receive_note':
      'Comparta su usuario o dirección para que otros le envíen PERC.',
  'wallet_tx_treasury': 'Emisión de tesorería',
  'wallet_tx_reward': 'Recompensa de escenario',
  'wallet_tx_sent': 'Enviado a {user}',
  'wallet_tx_received': 'Recibido de {user}',
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
      'Si X muestra un error, registre esta URL de retorno en console.x.com → su app → OAuth 2.0 (use 127.0.0.1, no localhost):',
  'grok_oauth_portal_checklist':
      'Lista en el portal de X:\n'
      '1. console.x.com → su app → App settings → App name: Evolve\n'
      '2. OAuth 2.0 activado en la app\n'
      '3. Tipo Native App o Web App con la URL de retorno indicada\n'
      '4. URL exacta: http://127.0.0.1:8787/auth/callback\n'
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
  'mode_percent': 'Probabilidad %',
  'mode_cohesion': 'Cohesión social',
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
  'cohesion_cycle_complete': '🌀 Ciclo Evolve completo.',
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
  'cohesion_title': 'Análisis Evolve: {title}',
  'cohesion_baseline': 'Puntuación de cohesión base: ~{scs}/100',
  'cohesion_refined': 'Puntuación de cohesión refinada: ~{scs}/100',
  'cohesion_refined_panel':
      'Puntuación refinada\nPARTE UNO / DOS / TRES (~{scs}/100)',
  'cohesion_continuum_subtitle': '{lean} — {pct}%',
  'cohesion_subtitle': 'Cohesión social bajo continuidad covariante Chronoflux',
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
  'cohesion_final_text':
      'Resumen final: pasar de la compresión narrativa a respuestas diferenciadas basadas en datos para reconstruir la continuidad covariante.',
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
      'Vórtice del continuo sobre «{question}»: compresión de autoridad {frame} en «{subject}» (ω {weight}% de saliencia, SCS {scs}/100).',
  'part_two_vortex_topic':
      'Vórtice del continuo sobre «{question}»: el encuadre de «{topic}» comprime «{subject}» en un solo carril narrativo (ω {weight}% de saliencia, SCS {scs}/100).',
  'part_two_shear_question':
      'Cizalla sobre «{question}»: polarización {frame} en «{subject}» — {polarity} (σ {weight}% de saliencia, SCS {scs}/100).',
  'part_two_resistance_flow_question':
      'Resistencia y flujo para «{question}»: arrastre Iτ ({res_weight}% de saliencia, SCS {res_scs}/100) frente a transporte Jμ ({flow_weight}% de saliencia, SCS {flow_scs}/100) — {transport}; inclinación neta {lean}.',
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
};