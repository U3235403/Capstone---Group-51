import 'dart:convert';
import 'dart:js_interop';

@JS('pilotServices')
external JSPromise<JSString> _call(JSString action, JSString payload);

Future<Map<String, dynamic>> pilotCall(
  String action,
  Map<String, dynamic> input,
) async {
  final result = jsonDecode(
    (await _call(action.toJS, jsonEncode(input).toJS).toDart).toDart,
  ) as Map<String, dynamic>;
  if (result['ok'] != true) throw StateError(result['error'] as String);
  return result;
}
