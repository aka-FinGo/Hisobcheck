import 'dart:html' as html;

bool isStandaloneMode() {
  return html.window.matchMedia('(display-mode: standalone)').matches;
}
