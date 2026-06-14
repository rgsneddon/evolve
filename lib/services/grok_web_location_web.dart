import 'dart:html' as html;

bool grokPageIsHttps() => html.window.location.protocol == 'https:';