import 'package:flutter/material.dart';

/// Beam Wallet localapp kinds — mirrored for the Perccent dapp suite.
enum PercDappKind {
  communityWardVoting,
  sendReceive,
  sideChain,
  explorer,
  governance,
  analysisGallery,
  sideChainBridge,
  meshBridge,
  nameService,
  assetMinter,
}

/// Manifest entry matching Beam Wallet `localapps/*/manifest.json` structure.
class PercDappSpec {
  const PercDappSpec({
    required this.guid,
    required this.name,
    required this.description,
    required this.kind,
    required this.icon,
    required this.color,
    this.featured = false,
  });

  final String guid;
  final String name;
  final String description;
  final PercDappKind kind;
  final IconData icon;
  final Color color;
  final bool featured;

  /// v2.0 main dapp — community ward voting portal.
  static const PercDappSpec featuredDapp = PercDappSpec(
    guid: 'perc-ward-voting-000',
    name: 'Community Ward Voting',
    description:
        'Cast comment and vote on ward proposals — open scenario % chance & SCS checker',
    kind: PercDappKind.communityWardVoting,
    icon: Icons.ballot_outlined,
    color: Color(0xFF22C55E),
    featured: true,
  );

  /// Full Beam-suite equivalent catalog for Perccent.
  static const List<PercDappSpec> beamSuite = [
    featuredDapp,
    PercDappSpec(
      guid: 'perc-send-receive-001',
      name: 'Send / Receive',
      description: 'Transfer PERC between every mesh wallet',
      kind: PercDappKind.sendReceive,
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFF00D9C0),
    ),
    PercDappSpec(
      guid: 'perc-sidechain-002',
      name: 'Chronoflux Side Chain',
      description: 'Microblock side chain — 100M microblocks seal a main block',
      kind: PercDappKind.sideChain,
      icon: Icons.account_tree_outlined,
      color: Color(0xFF6C63FF),
    ),
    PercDappSpec(
      guid: 'perc-explorer-003',
      name: 'Blockchain Explorer',
      description: 'Graph-based Perccent main-chain dapp',
      kind: PercDappKind.explorer,
      icon: Icons.hub_outlined,
      color: Color(0xFF60A5FA),
    ),
    PercDappSpec(
      guid: 'perc-governance-004',
      name: 'Perccent Governance',
      description: 'Staking rewards and treasury DAO',
      kind: PercDappKind.governance,
      icon: Icons.how_to_vote_outlined,
      color: Color(0xFFFFB347),
    ),
    PercDappSpec(
      guid: 'perc-analysis-005',
      name: 'Analysis Gallery',
      description: 'Scenario analysis faucet and Chronoflux outcomes',
      kind: PercDappKind.analysisGallery,
      icon: Icons.collections_outlined,
      color: Color(0xFFE879F9),
    ),
    PercDappSpec(
      guid: 'perc-bridge-006',
      name: 'Side Chain Bridge',
      description: 'Bridge Chronoflux microblocks to main-chain blocks',
      kind: PercDappKind.sideChainBridge,
      icon: Icons.compare_arrows_rounded,
      color: Color(0xFF34D399),
    ),
    PercDappSpec(
      guid: 'perc-mesh-bridge-007',
      name: 'Wallet Mesh Bridges',
      description: 'Concurrent peer bridges between every wallet',
      kind: PercDappKind.meshBridge,
      icon: Icons.device_hub,
      color: Color(0xFF818CF8),
    ),
    PercDappSpec(
      guid: 'perc-bans-008',
      name: 'Perccent Name Service',
      description: 'Decentralized usernames for all registered wallets',
      kind: PercDappKind.nameService,
      icon: Icons.badge_outlined,
      color: Color(0xFF38BDF8),
    ),
    PercDappSpec(
      guid: 'perc-minter-009',
      name: 'Asset Minter',
      description: 'Treasury emission and genesis pool renewal',
      kind: PercDappKind.assetMinter,
      icon: Icons.precision_manufacturing_outlined,
      color: Color(0xFFF472B6),
    ),
  ];
}