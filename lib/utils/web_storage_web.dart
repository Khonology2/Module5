import 'package:web/web.dart' as web;

String? readWebStorage(String key) {
  return web.window.localStorage.getItem(key);
}

void writeWebStorage(String key, String value) {
  web.window.localStorage.setItem(key, value);
}
