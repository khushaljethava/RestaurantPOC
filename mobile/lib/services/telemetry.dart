/// Lightweight event sink — wire PostHog/Sentry later; no-op safe default.
class Telemetry {
  static void event(String name, [Map<String, Object?> props = const {}]) {
    // ignore: avoid_print
    assert(() {
      // ignore: avoid_print
      print('telemetry:$name $props');
      return true;
    }());
  }
}
