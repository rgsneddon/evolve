/// Every network action is a confirmable block (tab click, keystroke, …).
library;

enum PercActionKind {
  tabClick,
  keystroke,
  vote,
  other,
}

class PercActionBlock {
  const PercActionBlock({
    required this.id,
    required this.kind,
    required this.detail,
    required this.index,
    required this.timestamp,
  });

  final String id;
  final PercActionKind kind;
  final String detail;
  final int index;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'detail': detail,
        'index': index,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}

class PercBlockConfirmResult {
  const PercBlockConfirmResult({
    required this.id,
    required this.status,
    this.block,
    this.reason,
  });

  /// `confirmed` | `not_found` | `rejected`
  final String status;
  final String id;
  final PercActionBlock? block;
  final String? reason;

  bool get isConfirmed => status == 'confirmed';

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        if (block != null) 'block': block!.toJson(),
        if (reason != null) 'reason': reason,
        'confirmed': isConfirmed,
      };
}

/// In-memory action chain. Same recorder the wallet, Mishi GUI, and tests use.
class PercActionChain {
  PercActionChain();

  final List<PercActionBlock> _blocks = [];
  int _seq = 0;

  List<PercActionBlock> get blocks =>
      List<PercActionBlock>.unmodifiable(_blocks);

  int get height => _blocks.length;

  PercActionBlock record({
    required PercActionKind kind,
    required String detail,
    DateTime? now,
  }) {
    _seq += 1;
    final block = PercActionBlock(
      id: 'act-$_seq',
      kind: kind,
      detail: detail,
      index: _seq,
      timestamp: (now ?? DateTime.now()).toUtc(),
    );
    _blocks.add(block);
    return block;
  }

  PercActionBlock recordTabClick(String tab, {DateTime? now}) =>
      record(kind: PercActionKind.tabClick, detail: tab, now: now);

  PercActionBlock recordKeystroke(String key, {DateTime? now}) =>
      record(kind: PercActionKind.keystroke, detail: key, now: now);

  /// Never throws. Unknown ids are `not_found`; empty ids are `rejected`.
  PercBlockConfirmResult confirm(String? id) {
    final needle = (id ?? '').trim();
    if (needle.isEmpty) {
      return PercBlockConfirmResult(
        id: '',
        status: 'rejected',
        reason: 'missing_id',
      );
    }
    for (final b in _blocks) {
      if (b.id == needle || '${b.index}' == needle) {
        return PercBlockConfirmResult(
          id: needle,
          status: 'confirmed',
          block: b,
        );
      }
    }
    return PercBlockConfirmResult(
      id: needle,
      status: 'not_found',
      reason: 'unknown_block',
    );
  }
}

final PercActionChain percActionChain = PercActionChain();
