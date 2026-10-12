import 'dart:js_interop';

@JS('isGoogleMapsLoaded')
external JSBoolean? _isGoogleMapsLoaded();

/// Web implementation: checks window.isGoogleMapsLoaded() safely
bool isGoogleMapsWebReady() {
  try {
    final result = _isGoogleMapsLoaded();
    return result?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
