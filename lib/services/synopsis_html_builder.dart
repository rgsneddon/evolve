/// Minimal Markdown-ish → HTML for browser synopsis view.
class SynopsisHtmlBuilder {
  const SynopsisHtmlBuilder._();

  static String document(String markdown, {required String title}) {
    final safeTitle = _escape(title);
    final body = markdown.split('\n').map(_lineToHtml).join('\n');
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$safeTitle</title>
  <style>
    body {
      font-family: system-ui, -apple-system, Segoe UI, sans-serif;
      background: #0a0e18;
      color: #b8bfd0;
      padding: 28px 24px 48px;
      max-width: 920px;
      margin: 0 auto;
      line-height: 1.55;
    }
    h1 { color: #00d9c0; font-size: 1.5rem; margin: 0 0 1.25rem; }
    h2 { color: #00d9c0; font-size: 1.15rem; margin: 1.35rem 0 0.5rem; }
    h3 { color: #b8b5ff; font-size: 1rem; margin: 1rem 0 0.35rem; }
    p { margin: 0.35rem 0; font-size: 0.92rem; }
    hr { border: none; border-top: 1px solid #1e2433; margin: 1.25rem 0; }
    strong { color: #e8eaf0; }
    em { color: #9ba3b8; }
    .meta { color: #7a8296; font-size: 0.82rem; margin-top: 2rem; }
  </style>
</head>
<body>
  <h1>$safeTitle</h1>
  $body
</body>
</html>''';
  }

  static String _lineToHtml(String line) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) return '<p>&nbsp;</p>';
    if (trimmed == '---') return '<hr>';
    if (trimmed.startsWith('### ')) {
      return '<h3>${_inline(trimmed.substring(4))}</h3>';
    }
    if (trimmed.startsWith('## ')) {
      return '<h2>${_inline(trimmed.substring(3))}</h2>';
    }
    if (trimmed.startsWith('# ')) {
      return '<h2>${_inline(trimmed.substring(2))}</h2>';
    }
    if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
      return '<p>${_inline(trimmed)}</p>';
    }
    if (trimmed.startsWith('* ') && trimmed.endsWith('*')) {
      return '<p><em>${_inline(trimmed.substring(2, trimmed.length - 1))}</em></p>';
    }
    return '<p>${_inline(trimmed)}</p>';
  }

  static String _inline(String text) {
    var out = _escape(text);
    out = out.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m.group(1)}</strong>',
    );
    out = out.replaceAllMapped(
      RegExp(r'🌀'),
      (_) => '🌀',
    );
    return out;
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}