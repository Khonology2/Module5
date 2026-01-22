import 'dart:html' as html;

String? readWebStorage(String key) {
  return html.window.localStorage[key];
}

void writeWebStorage(String key, String value) {
  html.window.localStorage[key] = value;
}

