const double kNeutralScs = 50.0;

class ConstructInput {
  const ConstructInput({this.scs = kNeutralScs, this.weight = 0.2});

  final double scs;
  final double weight;

  ConstructInput copyWith({double? scs, double? weight}) => ConstructInput(
        scs: scs ?? this.scs,
        weight: weight ?? this.weight,
      );
}