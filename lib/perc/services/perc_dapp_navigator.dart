import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../models/perc_dapp_spec.dart';
import '../providers/perc_wallet_provider.dart';
import '../screens/blockchain_explorer_screen.dart';
import '../screens/community_ward_voting_screen.dart';
import '../screens/perc_dapp_screens.dart';


/// Opens Beam-suite dapps — shared by wallet and blockchain explorer.
class PercDappNavigator {
  const PercDappNavigator._();

  static void open(
    BuildContext context, {
    required PercDappSpec spec,
    required PercWalletProvider wallet,
    required AppLocalizations strings,
    required VoidCallback onSend,
    required VoidCallback onReceive,
  }) {
    switch (spec.kind) {
      case PercDappKind.communityWardVoting:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityWardVotingScreen(strings: strings),
          ),
        );
      case PercDappKind.sendReceive:
        onSend();
      case PercDappKind.sideChain:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PercSideChainScreen(strings: strings),
          ),
        );
      case PercDappKind.explorer:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BlockchainExplorerScreen(),
          ),
        );
      case PercDappKind.governance:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PercGovernanceScreen(strings: strings),
          ),
        );
      case PercDappKind.analysisGallery:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PercAnalysisGalleryScreen(strings: strings),
          ),
        );
      case PercDappKind.sideChainBridge:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PercSideChainBridgeScreen(strings: strings),
          ),
        );
      case PercDappKind.meshBridge:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PercMeshBridgeScreen(strings: strings),
          ),
        );
      case PercDappKind.nameService:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PercNameServiceScreen(strings: strings),
          ),
        );
      case PercDappKind.assetMinter:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PercAssetMinterScreen(strings: strings),
          ),
        );
    }
  }

  /// Send/receive entry from dapp tile when user is not on wallet home.
  static void openSendReceiveHub(
    BuildContext context, {
    required PercWalletProvider wallet,
    required AppLocalizations strings,
    required VoidCallback onSend,
    required VoidCallback onReceive,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PercSendReceiveHubScreen(
          strings: strings,
          onSend: onSend,
          onReceive: onReceive,
        ),
      ),
    );
  }
}