import 'package:flutter/material.dart';

/// URL input for SCS mode — reads narrative data from a pasted link.
class NarrativeLinkField extends StatefulWidget {
  const NarrativeLinkField({
    super.key,
    required this.initialUrl,
    required this.isLoading,
    required this.onFetch,
    required this.strings,
  });

  final String initialUrl;
  final bool isLoading;
  final Future<void> Function(String url) onFetch;
  final dynamic strings;

  @override
  State<NarrativeLinkField> createState() => _NarrativeLinkFieldState();
}

class _NarrativeLinkFieldState extends State<NarrativeLinkField> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialUrl);
  }

  @override
  void didUpdateWidget(NarrativeLinkField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != oldWidget.initialUrl && widget.initialUrl != _url.text) {
      _url.text = widget.initialUrl;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: widget.strings.t('link_label'),
            hintText: widget.strings.t('link_hint'),
            prefixIcon: const Icon(Icons.link, size: 20),
          ),
          onFieldSubmitted: widget.isLoading ? null : (_) => _fetch(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: widget.isLoading ? null : _fetch,
            icon: widget.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(
              widget.isLoading
                  ? widget.strings.t('link_fetching')
                  : widget.strings.t('link_fetch'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _fetch() async {
    await widget.onFetch(_url.text.trim());
  }
}