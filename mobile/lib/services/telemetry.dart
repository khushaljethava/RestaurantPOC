/// Lightweight event sink. Optional PostHog/Sentry via dart-define; else print in debug.
class Telemetry {
  static const _posthog = String.fromEnvironment('POSTHOG_API_KEY');
  static const _sentry = String.fromEnvironment('SENTRY_DSN');

  static void event(String name, [Map<String, Object?> props = const {}]) {
    // ignore: avoid_print
    assert(() {
      // ignore: avoid_print
      print('telemetry:$name $props');
      return true;
    }());
    if (_posthog.isNotEmpty || _sentry.isNotEmpty) {
      // Keys present — still log-only until SDKs are wired; no required vendor.
      // ignore: avoid_print
      print(
        'telemetry:sink name=$name keys=posthog:${_posthog.isNotEmpty} sentry:${_sentry.isNotEmpty}',
      );
    }
  }
}
