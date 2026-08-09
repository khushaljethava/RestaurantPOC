// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Stall Manager';

  @override
  String get newOrder => 'New order';

  @override
  String get placeOrder => 'Place order';

  @override
  String get hold => 'Hold';

  @override
  String get checkout => 'Checkout';

  @override
  String get openShift => 'Open shift';

  @override
  String get stallOrders => 'Stall orders';

  @override
  String get acknowledge => 'Acknowledge';

  @override
  String get ready => 'Ready';

  @override
  String get pickupBoard => 'Pickup board';

  @override
  String get offlineWritesPaused => 'Offline — writes paused; cart draft OK';

  @override
  String get retry => 'Retry';
}
