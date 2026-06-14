import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/construct_meta.dart';
import '../models/scenario_input.dart';

/// Holds shared controllers for posed-question and construct fields.
class FrameworkFieldsHost extends StatefulWidget {
  const FrameworkFieldsHost({
    super.key,
    required this.input,
    required this.onChanged,
    required this.child,
    this.onRegisterFlush,
  });

  final ScenarioInput input;
  final ValueChanged<ScenarioInput> onChanged;
  final ValueChanged<VoidCallback?>? onRegisterFlush;
  final Widget child;

  static _FrameworkFieldsScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FrameworkFieldsScope>();
    assert(scope != null, 'FrameworkFieldsHost not found above this context');
    return scope!;
  }

  @override
  State<FrameworkFieldsHost> createState() => _FrameworkFieldsHostState();
}

class _FrameworkFieldsHostState extends State<FrameworkFieldsHost> {
  late final TextEditingController _posedQuestion;
  late final TextEditingController _topic;
  late final TextEditingController _vortex;
  late final TextEditingController _shear;
  late final TextEditingController _resistance;
  late final TextEditingController _flow;
  late final FocusNode _posedQuestionFocus;
  Timer? _debounce;
  String? _regionFocusBanner;

  @override
  void initState() {
    super.initState();
    _posedQuestion = TextEditingController(text: widget.input.posedQuestion);
    _topic = TextEditingController(text: widget.input.topic);
    _vortex = TextEditingController(text: widget.input.vortexText);
    _shear = TextEditingController(text: widget.input.shearText);
    _resistance = TextEditingController(text: widget.input.resistanceText);
    _flow = TextEditingController(text: widget.input.flowText);
    _posedQuestionFocus = FocusNode();
    widget.onRegisterFlush?.call(_push);
  }

  @override
  void didUpdateWidget(FrameworkFieldsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_posedQuestion, widget.input.posedQuestion, oldWidget.input.posedQuestion);
    _syncController(_topic, widget.input.topic, oldWidget.input.topic);
    _syncController(_vortex, widget.input.vortexText, oldWidget.input.vortexText);
    _syncController(_shear, widget.input.shearText, oldWidget.input.shearText);
    _syncController(_resistance, widget.input.resistanceText, oldWidget.input.resistanceText);
    _syncController(_flow, widget.input.flowText, oldWidget.input.flowText);
  }

  void _syncController(TextEditingController c, String next, String prev) {
    if (next != prev && next != c.text) {
      c.text = next;
    }
  }

  void focusPosedQuestionIfBannerChanged(String? banner) {
    if (banner == null || banner.isEmpty || banner == _regionFocusBanner) return;
    _regionFocusBanner = banner;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _posedQuestionFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.onRegisterFlush?.call(null);
    _debounce?.cancel();
    _posedQuestionFocus.dispose();
    _posedQuestion.dispose();
    _topic.dispose();
    _vortex.dispose();
    _shear.dispose();
    _resistance.dispose();
    _flow.dispose();
    super.dispose();
  }

  void schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _push);
  }

  void _push() {
    _debounce?.cancel();
    widget.onChanged(
      ScenarioInput(
        posedQuestion: ScenarioInput.clamp(_posedQuestion.text),
        topic: ScenarioInput.clamp(_topic.text),
        sourceUrl: widget.input.sourceUrl,
        vortexText: ScenarioInput.clamp(_vortex.text),
        shearText: ScenarioInput.clamp(_shear.text),
        resistanceText: ScenarioInput.clamp(_resistance.text),
        flowText: ScenarioInput.clamp(_flow.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FrameworkFieldsScope(
      host: this,
      child: widget.child,
    );
  }
}

class _FrameworkFieldsScope extends InheritedWidget {
  const _FrameworkFieldsScope({
    required this.host,
    required super.child,
  });

  final _FrameworkFieldsHostState host;

  @override
  bool updateShouldNotify(_FrameworkFieldsScope oldWidget) => false;
}

/// Posed question + optional topic — placed above Grok construal.
class PosedQuestionFields extends StatefulWidget {
  const PosedQuestionFields({
    super.key,
    this.posedQuestionLabel,
    this.posedQuestionHint,
    this.topicHint,
    this.regionFocusBanner,
  });

  final String? posedQuestionLabel;
  final String? posedQuestionHint;
  final String? topicHint;
  final String? regionFocusBanner;

  @override
  State<PosedQuestionFields> createState() => _PosedQuestionFieldsState();
}

class _PosedQuestionFieldsState extends State<PosedQuestionFields> {
  @override
  void didUpdateWidget(PosedQuestionFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.regionFocusBanner != oldWidget.regionFocusBanner) {
      FrameworkFieldsHost.of(context).host.focusPosedQuestionIfBannerChanged(
        widget.regionFocusBanner,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = FrameworkFieldsHost.of(context).host;
    const posedAccent = Color(0xFF00D9C0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: host._posedQuestion,
          focusNode: host._posedQuestionFocus,
          minLines: 2,
          maxLines: null,
          maxLength: kFieldMaxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: widget.posedQuestionLabel ?? 'POSE YOUR QUESTION HERE',
            labelStyle: const TextStyle(
              color: posedAccent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
            hintText: widget.posedQuestionHint,
            alignLabelWithHint: true,
            filled: true,
            fillColor: posedAccent.withOpacity(0.08),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: posedAccent.withOpacity(0.45)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: posedAccent.withOpacity(0.35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: posedAccent, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w600),
          onChanged: (_) => host.schedulePush(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: host._topic,
          decoration: InputDecoration(
            labelText: widget.topicHint ?? 'Scenario topic (optional)',
            hintText: widget.topicHint,
          ),
          onChanged: (_) => host.schedulePush(),
        ),
        if (widget.regionFocusBanner != null && widget.regionFocusBanner!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: posedAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: posedAccent.withOpacity(0.25)),
            ),
            child: Text(
              widget.regionFocusBanner!,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8BDFD4)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Chronoflux construct variables (ω, σ, Iτ, Jμ).
class ConstructVariableFields extends StatelessWidget {
  const ConstructVariableFields({
    super.key,
    this.vortexHint,
    this.constructLabels,
    this.constructHints,
    this.constructsSectionTitle,
    this.constructsSectionSubtitle,
    this.grokEnabled = false,
    this.grokFilledFields = const {},
    this.highlightMissing = false,
    this.grokFilledLabel = 'Grok',
  });

  final String? vortexHint;
  final Map<String, String>? constructLabels;
  final Map<String, String>? constructHints;
  final String? constructsSectionTitle;
  final String? constructsSectionSubtitle;
  final bool grokEnabled;
  final Set<String> grokFilledFields;
  final bool highlightMissing;
  final String grokFilledLabel;

  @override
  Widget build(BuildContext context) {
    final host = FrameworkFieldsHost.of(context).host;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          constructsSectionTitle ?? 'Chronoflux variables',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF9BA3B8),
          ),
        ),
        if (constructsSectionSubtitle != null && constructsSectionSubtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            constructsSectionSubtitle!,
            style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF6B7280)),
          ),
        ],
        const SizedBox(height: 12),
        _field(
          host,
          ConstructMeta.all[0],
          host._vortex,
          constructKey: 'vortex',
          hint: vortexHint ?? constructHints?['vortex'],
          label: constructLabels?['vortex'],
        ),
        const SizedBox(height: 10),
        _field(
          host,
          ConstructMeta.all[1],
          host._shear,
          constructKey: 'shear',
          hint: constructHints?['shear'],
          label: constructLabels?['shear'],
        ),
        const SizedBox(height: 10),
        _field(
          host,
          ConstructMeta.all[2],
          host._resistance,
          constructKey: 'resistance',
          hint: constructHints?['resistance'],
          label: constructLabels?['resistance'],
        ),
        const SizedBox(height: 10),
        _field(
          host,
          ConstructMeta.all[3],
          host._flow,
          constructKey: 'flow',
          hint: constructHints?['flow'],
          label: constructLabels?['flow'],
        ),
      ],
    );
  }

  Widget _field(
    _FrameworkFieldsHostState host,
    ConstructMeta meta,
    TextEditingController controller, {
    required String constructKey,
    String? hint,
    String? label,
  }) {
    final isGrokFilled = grokFilledFields.contains(constructKey);
    final isMissing = highlightMissing && controller.text.trim().isEmpty;
    final borderColor = isMissing
        ? const Color(0xFFEF4444)
        : isGrokFilled
            ? const Color(0xFFF59E0B)
            : meta.color.withOpacity(0.35);

    return TextFormField(
      controller: controller,
      minLines: 2,
      maxLines: null,
      maxLength: kFieldMaxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        labelText: label ?? '${meta.name} (${meta.symbol})',
        labelStyle: TextStyle(
          color: isMissing ? const Color(0xFFEF4444) : meta.color,
          fontWeight: isMissing ? FontWeight.w800 : FontWeight.w600,
        ),
        hintText: hint ?? meta.hint,
        alignLabelWithHint: true,
        filled: true,
        fillColor: isMissing
            ? const Color(0xFFEF4444).withOpacity(0.06)
            : isGrokFilled
                ? const Color(0xFFF59E0B).withOpacity(0.06)
                : meta.color.withOpacity(0.06),
        counterText: '',
        helperText: isGrokFilled ? grokFilledLabel : null,
        helperStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFFF59E0B),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isMissing ? const Color(0xFFEF4444) : meta.color,
            width: 1.5,
          ),
        ),
      ),
      style: const TextStyle(fontSize: 13, height: 1.45),
      onChanged: (_) => host.schedulePush(),
    );
  }
}