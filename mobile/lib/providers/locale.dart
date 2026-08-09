import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString('settings_lang') ?? 'en';
    state = Locale(code);
  }

  Future<void> setLang(String code) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('settings_lang', code);
    state = Locale(code);
  }
}
