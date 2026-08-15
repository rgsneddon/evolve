import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../fcg/mishi/mishi_approve.dart';
import '../fcg/mishi/mishi_credentials.dart';
import '../fcg/mishi/mishi_first_run.dart';
import '../fcg/mishi/mishi_rpai.dart';
import '../fcg/mishi/mishi_surface.dart';
import '../perc/services/perc_action_block.dart';
import '../perc/services/perc_explorer_confirm.dart';
import '../perc/services/perc_voting_epoch_wards.dart';

/// Desktop-only Mishi moderator shell. Always dark grey/black, yellow text.
class MishiApp extends StatelessWidget {
  const MishiApp({
    super.key,
    this.credentialFile,
    this.book,
    this.learner,
    this.chain,
    this.explorer,
  });

  final File? credentialFile;
  final MishiAccessBook? book;
  final RpaiLearner? learner;
  final PercActionChain? chain;
  final PercExplorerConfirm? explorer;

  static const Color bg = Color(MishiThemeTokens.backgroundBlack);
  static const Color panel = Color(MishiThemeTokens.panelGrey);
  static const Color chrome = Color(MishiThemeTokens.chromeGrey);
  static const Color border = Color(MishiThemeTokens.borderGrey);
  static const Color yellow = Color(MishiThemeTokens.textYellow);
  static const Color dim = Color(MishiThemeTokens.dimYellow);

  /// Named mono font is skipped in flutter_test (asset fonts are disabled).
  static bool get inWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');

  static String? get monoFont => inWidgetTest ? null : 'Menlo';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MISHI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: yellow,
          onPrimary: bg,
          surface: panel,
          onSurface: yellow,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            color: yellow,
            fontFamily: MishiApp.monoFont,
            fontSize: 13,
          ),
        ),
      ),
      home: MishiHome(
        credentialFile: credentialFile,
        book: book,
        learner: learner,
        chain: chain,
        explorer: explorer,
      ),
    );
  }
}

class MishiHome extends StatefulWidget {
  const MishiHome({
    super.key,
    this.credentialFile,
    this.book,
    this.learner,
    this.chain,
    this.explorer,
  });

  final File? credentialFile;
  final MishiAccessBook? book;
  final RpaiLearner? learner;
  final PercActionChain? chain;
  final PercExplorerConfirm? explorer;

  @override
  State<MishiHome> createState() => _MishiHomeState();
}

class _MishiHomeState extends State<MishiHome> {
  late final MishiSurfaceModel _surface;
  late final MishiAccessBook _book;
  late final RpaiLearner _learner;
  late final PercActionChain _chain;
  late final PercExplorerConfirm _explorer;
  MishiCredentialStore? _creds;
  String _status = 'MISHI ready. Dark mode locked.';

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _grantUserCtrl = TextEditingController();
  final _forumCtrl = TextEditingController(text: '2026-08');
  final _epochCtrl = TextEditingController(text: 'epoch-2026-08-w1');
  final _cliCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _surface = MishiSurfaceModel();
    _book = widget.book ?? MishiAccessBook();
    _learner = widget.learner ?? rpaiNed;
    _chain = widget.chain ?? percActionChain;
    _explorer = widget.explorer ??
        PercExplorerConfirm(chain: _chain, learner: _learner);
    _bootCredentials();
  }

  void _bootCredentials() {
    final file = widget.credentialFile ??
        MishiCredentialStore.ensureOnDesktop();
    _creds = MishiCredentialStore(file: file);
    final existing = _creds!.read();
    if (!existing.isEmpty) {
      _userCtrl.text = existing.username;
      _passCtrl.text = existing.password;
      _status = 'Loaded credentials for ${existing.username} from Desktop';
    } else {
      _status = 'Setup strings on Desktop: ${file.path}';
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _grantUserCtrl.dispose();
    _forumCtrl.dispose();
    _epochCtrl.dispose();
    _cliCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _noteAction(String kind, String detail) {
    if (kind == 'tab') {
      _chain.recordTabClick(detail);
    } else if (kind == 'key') {
      _chain.recordKeystroke(detail);
    } else {
      _chain.record(kind: PercActionKind.other, detail: detail);
    }
    _learner.learn(RpaiEvent(
      source: rpaiSourceEvolveWallet,
      kind: kind == 'tab' ? 'tab_click' : (kind == 'key' ? 'keystroke' : kind),
      payload: detail,
    ));
  }

  void _selectTab(MishiTab tab) {
    setState(() {
      _surface.select(tab);
      _noteAction('tab', tab.label);
      _status = 'tab ${tab.label} → block ${_chain.height}';
    });
  }

  InputDecoration _cliDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: MishiApp.dim, fontFamily: MishiApp.monoFont),
      filled: true,
      fillColor: MishiApp.bg,
      border: InputBorder.none,
      isDense: true,
    );
  }

  Widget _cliField({
    required String prompt,
    required TextEditingController controller,
    bool obscure = false,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    return Row(
      children: [
        Text(prompt, style: TextStyle(color: MishiApp.dim, fontFamily: MishiApp.monoFont)),
        Expanded(
          child: MishiApp.inWidgetTest
              ? Text(
                  controller.text,
                  style: TextStyle(color: MishiApp.yellow, fontFamily: MishiApp.monoFont),
                )
              : TextField(
                  controller: controller,
                  obscureText: obscure,
                  cursorColor: MishiApp.yellow,
                  style: TextStyle(color: MishiApp.yellow, fontFamily: MishiApp.monoFont),
                  decoration: _cliDeco(''),
                  onChanged: (v) {
                    if (v.isNotEmpty) {
                      _noteAction('key', v.substring(v.length - 1));
                    }
                    onChanged?.call(v);
                  },
                  onSubmitted: onSubmitted,
                ),
        ),
      ],
    );
  }

  Widget _cliWindow({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MishiApp.bg,
        border: Border.all(color: MishiApp.yellow, width: 1),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: MishiApp.yellow,
          fontFamily: MishiApp.monoFont,
          fontSize: 13,
          height: 1.45,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('mishi@evolve — cli'),
              const Text('────────────────────────────────────────'),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MishiApp.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: MishiApp.chrome,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                MishiApp.inWidgetTest
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: ColoredBox(color: MishiApp.yellow),
                      )
                    : Image.asset(
                        'assets/brand/restore_privacy_logo.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 22,
                          height: 22,
                          child: ColoredBox(color: MishiApp.yellow),
                        ),
                      ),
                const SizedBox(width: 8),
                Text(
                  'MISHI',
                  style: TextStyle(
                    color: MishiApp.yellow,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontFamily: MishiApp.monoFont,
                  ),
                ),
                const SizedBox(width: 16),
                ...MishiSurfaceModel.tabs.map((tab) {
                  final on = _surface.active == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _selectTab(tab),
                      child: Container(
                        key: ValueKey('mishi-tab-${tab.name}'),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: on ? MishiApp.yellow : MishiApp.panel,
                        child: Text(
                          tab.label,
                          style: TextStyle(
                            color: on ? MishiApp.bg : MishiApp.yellow,
                            fontFamily: MishiApp.monoFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                Text(
                  'DARK LOCKED',
                  style: TextStyle(color: MishiApp.dim, fontFamily: MishiApp.monoFont, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: MishiApp.panel,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _body(),
              ),
            ),
          ),
          Container(
            color: MishiApp.chrome,
            padding: const EdgeInsets.all(8),
            child: Text(
              _status,
              style: TextStyle(color: MishiApp.yellow, fontFamily: MishiApp.monoFont, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_surface.active) {
      case MishiTab.login:
        return _login();
      case MishiTab.approve:
        return _approve();
      case MishiTab.votes:
        return _votes();
      case MishiTab.rpai:
        return _rpai();
      case MishiTab.chain:
        return _chainView();
    }
  }

  Widget _login() {
    final path = _creds?.file.path ?? MishiCredentialStore.desktopFile().path;
    final rec = _creds?.read() ?? const MishiCredentialRecord(username: '', password: '');
    final guide = MishiFirstRunGuide(record: rec, filePath: path);
    return _cliWindow(children: [
      const Text('FIRST OPEN — register from the Desktop txt'),
      Text(path),
      ...guide.steps.map((s) => Text(s)),
      const SizedBox(height: 8),
      _cliField(prompt: 'user> ', controller: _userCtrl),
      _cliField(prompt: 'pass> ', controller: _passCtrl, obscure: true),
      const SizedBox(height: 8),
      Row(children: [
        _cmdButton('WRITE CREDENTIALS', () {
          final rec = _creds?.write(
            username: _userCtrl.text,
            password: _passCtrl.text,
          );
          setState(() => _status = 'wrote ${rec?.username} to ${_creds?.file.path}');
        }),
        const SizedBox(width: 8),
        _cmdButton('READ BACK', () {
          final rec = _creds?.read();
          _userCtrl.text = rec?.username ?? '';
          _passCtrl.text = rec?.password ?? '';
          setState(() => _status = 'read ${rec?.username} from ${_creds?.file.path}');
        }),
        const SizedBox(width: 8),
        _cmdButton('COPY PATH', () {
          Clipboard.setData(ClipboardData(text: path));
          setState(() => _status = 'copied $path');
        }),
      ]),
    ]);
  }

  Widget _approve() {
    return _cliWindow(children: [
      const Text('approve access for monthly forum vote + voting epoch'),
      _cliField(prompt: 'voter> ', controller: _grantUserCtrl),
      _cliField(prompt: 'month> ', controller: _forumCtrl),
      _cliField(prompt: 'epoch> ', controller: _epochCtrl),
      const SizedBox(height: 8),
      Row(children: [
        _cmdButton('REQUEST', () {
          _book.requestAccess(
            username: _grantUserCtrl.text,
            forumMonth: _forumCtrl.text,
            votingEpoch: _epochCtrl.text,
          );
          setState(() => _status = 'pending ${_grantUserCtrl.text}');
        }),
        const SizedBox(width: 8),
        _cmdButton('APPROVE', () {
          _book.approve(
            username: _grantUserCtrl.text,
            forumMonth: _forumCtrl.text,
            votingEpoch: _epochCtrl.text,
          );
          _noteAction('vote', '${_forumCtrl.text}|${_epochCtrl.text}');
          setState(() => _status = 'approved ${_grantUserCtrl.text} for pair');
        }),
        const SizedBox(width: 8),
        _cmdButton('DENY', () {
          _book.deny(
            username: _grantUserCtrl.text,
            forumMonth: _forumCtrl.text,
            votingEpoch: _epochCtrl.text,
          );
          setState(() => _status = 'denied ${_grantUserCtrl.text}');
        }),
      ]),
      const SizedBox(height: 10),
      Text(
        'access=${_book.hasAccess(username: _grantUserCtrl.text, forumMonth: _forumCtrl.text, votingEpoch: _epochCtrl.text)}',
      ),
      ..._book.all.map(
        (r) => Text('${r.status.name.padRight(9)} ${r.username}  ${r.forumMonth}  ${r.votingEpoch}'),
      ),
    ]);
  }

  Widget _votes() {
    final wards = PercVotingEpochWards.wardsForEpoch(_epochCtrl.text);
    return _cliWindow(children: [
      const Text('voting epoch → wards'),
      _cliField(prompt: 'epoch> ', controller: _epochCtrl),
      const SizedBox(height: 8),
      Text('wards: ${wards.length}'),
      ...wards.map((w) => Text('  ${w.wardId}  ${w.label}')),
    ]);
  }

  Widget _rpai() {
    final s = _learner.stats();
    String bar(double v) {
      final n = (v * 20).round().clamp(0, 20);
      return '[${'#' * n}${'.' * (20 - n)}] ${(v * 100).toStringAsFixed(1)}%';
    }

    return SingleChildScrollView(
      child: _cliWindow(children: [
        Text('NED ${s.identity}  ·  oracle=${s.oracleSync}  ·  epochs=${s.learningEpochs}'),
        Text('learned=${s.learned}  rejected=${s.rejected}  wallet=${s.walletEvents}  vpn=${s.vpnEvents}'),
        const SizedBox(height: 8),
        const Text('-- learning benchmarks vs best-in-class --'),
        Text('accuracy    ${bar(s.accuracy)}  sota=${s.sotaAccuracy}'),
        Text('coverage    ${bar(s.coverage)}  sota=${s.sotaCoverage}'),
        Text('calibration ${bar(s.calibration)}  sota=${s.sotaCalibration}'),
        Text('latency_ms  ${s.latencyMs} (sota ${s.sotaLatencyMs})'),
        const SizedBox(height: 8),
        const Text('-- sources --'),
        ...s.bySource.entries.map((e) => Text('  ${e.key}=${e.value}')),
        const Text('-- kinds --'),
        ...s.byKind.entries.map((e) => Text('  ${e.key}=${e.value}')),
        const Text('-- capability matrix --'),
        ...s.capabilityMatrix.entries.map((e) => Text('  ${e.key.padRight(20)} ${e.value}')),
        const Text('-- recent --'),
        ...s.recent.take(12).map((e) => Text('  $e')),
        const SizedBox(height: 8),
        const Text('ingest from evolve-wallet + restore-privacy-vpn only'),
        _cliField(
          prompt: 'learn> ',
          controller: _cliCtrl,
          onSubmitted: (v) {
            final parts = v.split(RegExp(r'\s+'));
            final src = parts.isNotEmpty ? parts[0] : '';
            final kind = parts.length > 1 ? parts[1] : 'note';
            final payload = parts.length > 2 ? parts.sublist(2).join(' ') : v;
            final r = _learner.learn(RpaiEvent(source: src, kind: kind, payload: payload));
            _cliCtrl.clear();
            setState(() => _status = r.accepted ? 'learned ${r.eventId}' : 'rejected ${r.reason}');
          },
        ),
        const Text('format: <evolve-wallet|restore-privacy-vpn> <kind> <payload>'),
      ]),
    );
  }

  Widget _chainView() {
    final d = _explorer.diagrams(epochId: _epochCtrl.text);
    return _cliWindow(children: [
      Text('action blocks: ${_chain.height}'),
      Text('graphs blocks=${d.blockSeries}'),
      Text('graphs wards=${d.wardSeries}'),
      Text('graphs mint=${d.mintSeries}'),
      Text('graphs rpai=${d.rpaiSeries}'),
      _cliField(
        prompt: 'confirm> ',
        controller: _confirmCtrl,
        onSubmitted: (v) {
          final r = _explorer.confirm(v);
          setState(() => _status = '${r.status} ${r.id} ${r.reason ?? ''}');
        },
      ),
      ..._chain.blocks.reversed.take(16).map(
            (b) => Text('  ${b.id}  ${b.kind.name}  ${b.detail}'),
          ),
    ]);
  }

  Widget _cmdButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: MishiApp.yellow,
        child: Text(
          label,
          style: TextStyle(
            color: MishiApp.bg,
            fontFamily: MishiApp.monoFont,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
