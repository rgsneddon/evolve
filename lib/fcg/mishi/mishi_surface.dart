/// Desktop Mishi surface model — tabs are fixed; dark mode is not optional.
enum MishiTab {
  login,
  approve,
  votes,
  rpai,
  chain,
}

extension MishiTabLabel on MishiTab {
  String get label {
    switch (this) {
      case MishiTab.login:
        return 'LOGIN';
      case MishiTab.approve:
        return 'APPROVE';
      case MishiTab.votes:
        return 'VOTES';
      case MishiTab.rpai:
        return 'rpAI';
      case MishiTab.chain:
        return 'CHAIN';
    }
  }
}

/// Theme tokens — grey/black dark-only, high-contrast yellow text.
class MishiThemeTokens {
  const MishiThemeTokens._();

  static const int backgroundBlack = 0xFF0A0A0A;
  static const int panelGrey = 0xFF1C1C1C;
  static const int chromeGrey = 0xFF2A2A2A;
  static const int borderGrey = 0xFF3A3A3A;
  static const int textYellow = 0xFFFFE14A;
  static const int dimYellow = 0xFFC7B020;
  static const bool darkOnly = true;
  static const bool themeToggleAllowed = false;
}

/// Shipped tab list the GUI renders. Includes the rpAI tab.
class MishiSurfaceModel {
  MishiSurfaceModel({this.active = MishiTab.login});

  MishiTab active;

  static const List<MishiTab> tabs = <MishiTab>[
    MishiTab.login,
    MishiTab.approve,
    MishiTab.votes,
    MishiTab.rpai,
    MishiTab.chain,
  ];

  bool get hasRpaiTab => tabs.contains(MishiTab.rpai);

  List<String> get tabLabels => tabs.map((t) => t.label).toList(growable: false);

  void select(MishiTab tab) {
    if (!tabs.contains(tab)) return;
    active = tab;
  }
}
