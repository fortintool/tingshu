import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/app_settings.dart';

class BookSettingsNotifier extends StateNotifier<BookSettings?> {
  final int bookId;
  BookSettingsNotifier(this.bookId) : super(null) {
    _load();
  }

  final _db = DatabaseHelper.instance;

  Future<void> _load() async {
    state = await _db.getBookSettings(bookId);
  }

  Future<void> setVoice(String? voice) async {
    state = BookSettings(bookId: bookId, voice: voice, speed: state?.speed, pitch: state?.pitch);
    await _db.upsertBookSettings(state!);
  }

  Future<void> setSpeed(double? speed) async {
    state = BookSettings(bookId: bookId, voice: state?.voice, speed: speed, pitch: state?.pitch);
    await _db.upsertBookSettings(state!);
  }

  Future<void> setPitch(double? pitch) async {
    state = BookSettings(bookId: bookId, voice: state?.voice, speed: state?.speed, pitch: pitch);
    await _db.upsertBookSettings(state!);
  }

  Future<void> clear() async {
    await _db.deleteBookSettings(bookId);
    state = null;
  }
}

final bookSettingsProvider = StateNotifierProvider.family<BookSettingsNotifier, BookSettings?, int>(
  (ref, bookId) => BookSettingsNotifier(bookId),
);