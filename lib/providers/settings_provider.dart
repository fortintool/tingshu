import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/app_settings.dart';

class SettingsNotifier extends StateNotifier<UserSettings> {
  SettingsNotifier() : super(const UserSettings()) {
    _load();
  }

  final _db = DatabaseHelper.instance;

  Future<void> _load() async {
    state = await _db.getUserSettings();
  }

  Future<void> setThemeMode(String mode) async {
    state = state.copyWith(themeMode: mode);
    await _db.updateUserSettings(state);
  }

  Future<void> setDefaultSpeed(double speed) async {
    state = state.copyWith(defaultSpeed: speed);
    await _db.updateUserSettings(state);
  }

  Future<void> setDefaultVoice(String? voice) async {
    state = state.copyWith(defaultVoice: voice);
    await _db.updateUserSettings(state);
  }

  Future<void> setDefaultPitch(double pitch) async {
    state = state.copyWith(defaultPitch: pitch);
    await _db.updateUserSettings(state);
  }

  Future<void> setSyncHighlightEnabled(bool enabled) async {
    state = state.copyWith(syncHighlightEnabled: enabled);
    await _db.updateUserSettings(state);
  }
}

ThemeMode toThemeMode(String s) {
  switch (s) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserSettings>(
  (ref) => SettingsNotifier(),
);
