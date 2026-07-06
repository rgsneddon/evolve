/// Result of advancing the microblock chain on a keystroke.
class PercMicroblockRecordResult {
  const PercMicroblockRecordResult({
    this.recorded = false,
    this.blockSealed = false,
    this.microblockCount = 0,
    this.selfConsistent = false,
    this.blockIndex,
    this.wardAdvanced = false,
  });

  final bool recorded;
  final bool blockSealed;
  final int microblockCount;
  final bool selfConsistent;
  final int? blockIndex;
  final bool wardAdvanced;

  static const skipped = PercMicroblockRecordResult();
}