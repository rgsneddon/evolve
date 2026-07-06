import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/locale_config.dart';
import '../providers/evolve_provider.dart';
import '../providers/locale_provider.dart';

/// Keeps [EvolveProvider] locale aligned with the global [LocaleProvider].
class LocaleSync extends StatefulWidget {
  const LocaleSync({super.key, required this.child});

  final Widget child;

  @override
  State<LocaleSync> createState() => _LocaleSyncState();
}

class _LocaleSyncState extends State<LocaleSync> {
  LocaleProvider? _locale;
  LocaleConfig? _lastSynced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.read<LocaleProvider>();
    if (!identical(_locale, locale)) {
      _locale?.removeListener(_sync);
      _locale = locale;
      _locale!.addListener(_sync);
    }
    _sync();
  }

  void _sync() {
    final locale = _locale;
    if (locale == null || !mounted) return;
    final config = locale.config;
    if (_lastSynced == config) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = _locale?.config;
      if (latest == null || _lastSynced == latest) return;
      _lastSynced = latest;
      context.read<EvolveProvider>().setLocale(latest);
    });
  }

  @override
  void dispose() {
    _locale?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}