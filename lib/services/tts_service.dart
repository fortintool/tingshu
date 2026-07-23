import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';

/// TTS 引擎封装。
class TtsService {
  static final TtsService instance = TtsService._init();
  TtsService._init();

  FlutterTts tts = FlutterTts();
  final DatabaseHelper _db = DatabaseHelper.instance;

  String _currentText = '';
  int _currentCharPosition = 0;
  int _chapterCharStart = 0;
  String? _voice;
  double _speed = 1.0;
  double _pitch = 1.0;
  int? _currentBookId;
  int? _currentChapterId;
  String? _detectedLanguage;

  final StreamController<({int chapter, int book})> _progressController =
      StreamController<({int chapter, int book})>.broadcast();
  Stream<({int chapter, int book})> get progressStream => _progressController.stream;

  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  Stream<void> get completionStream => _completionController.stream;

  bool _initialized = false;
  bool _initFailed = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (_initFailed) return;

    try {
      // 先获取可用语言，找到最合适的中文语音
      dynamic languages;
      try {
        languages = await tts.getLanguages.timeout(const Duration(seconds: 2));
      } catch (_) {}

      String? bestLang;
      if (languages is List) {
        for (final lang in languages) {
          final l = lang.toString().toLowerCase();
          if (l.startsWith('zh') || l.contains('chinese')) {
            bestLang = lang.toString();
            break;
          }
        }
      }

      // 先尝试设置检测到的中文语言，失败则用 zh-CN
      if (bestLang != null) {
        try {
          await tts.setLanguage(bestLang).timeout(const Duration(seconds: 2));
          _detectedLanguage = bestLang;
        } catch (_) {
          try {
            await tts.setLanguage('zh-CN').timeout(const Duration(seconds: 2));
            _detectedLanguage = 'zh-CN';
          } catch (_) {}
        }
      } else {
        try {
          await tts.setLanguage('zh-CN').timeout(const Duration(seconds: 2));
          _detectedLanguage = 'zh-CN';
        } catch (_) {}
      }

      try {
        await tts.awaitSpeakCompletion(true).timeout(const Duration(seconds: 1));
      } catch (_) {}
      try {
        await tts.setSpeechRate(1.0).timeout(const Duration(seconds: 1));
      } catch (_) {}
      try {
        await tts.setPitch(1.0).timeout(const Duration(seconds: 1));
      } catch (_) {}

      // 注册回调
      tts.setStartHandler(() {
        _onStart();
      });
      tts.setProgressHandler((String text, int start, int end, String word) {
        _currentCharPosition = end;
        _progressController.add((
          chapter: end,
          book: _chapterCharStart + end,
        ));
      });
      tts.setCompletionHandler(() {
        _completionController.add(null);
      });
      tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        _completionController.add(null);
      });
      tts.setCancelHandler(() {
        _completionController.add(null);
      });

      _initialized = true;
      debugPrint('TTS initialized, language: $_detectedLanguage');
    } catch (e) {
      _initFailed = true;
      debugPrint('TTS init failed: $e');
    }
  }

  void _onStart() {
    // 播放开始时重置进度回调（某些设备需要在 start 后重新设置）
    tts.setProgressHandler((String text, int start, int end, String word) {
      _currentCharPosition = end;
      _progressController.add((
        chapter: end,
        book: _chapterCharStart + end,
      ));
    });
  }

  /// 应用设置（单本书覆盖全局）
  Future<void> _applySettings(int? bookId) async {
    final global = await _db.getUserSettings();
    BookSettings? bookOverride;
    if (bookId != null) {
      bookOverride = await _db.getBookSettings(bookId);
    }

    final voice = bookOverride?.voice ?? global.defaultVoice;
    final speed = bookOverride?.speed ?? global.defaultSpeed;
    final pitch = bookOverride?.pitch ?? global.defaultPitch;

    try {
      if (voice != null && voice.isNotEmpty) {
        await tts.setVoice({'name': voice, 'locale': _detectedLanguage ?? 'zh-CN'}).timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('setVoice failed: $e');
    }
    try {
      await tts.setSpeechRate(speed).timeout(const Duration(seconds: 1));
    } catch (_) {}
    try {
      await tts.setPitch(pitch).timeout(const Duration(seconds: 1));
    } catch (_) {}

    _voice = voice;
    _speed = speed;
    _pitch = pitch;
  }

  /// 获取设备支持的语音列表
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final list = await tts.getVoices.timeout(
        const Duration(seconds: 3),
        onTimeout: () => <dynamic>[],
      );
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList();
      }
    } catch (e) {
      debugPrint('getVoices error: $e');
    }
    return [];
  }

  /// 获取检测到的语言
  String? get detectedLanguage => _detectedLanguage;

  /// 朗读指定文本
  Future<void> speak({
    required String text,
    required int bookId,
    required int chapterId,
    required int chapterCharStart,
    int startOffset = 0,
  }) async {
    try {
      await _ensureInit();
      await stop();

      _currentText = text;
      _chapterCharStart = chapterCharStart;
      _currentCharPosition = startOffset;
      _currentBookId = bookId;
      _currentChapterId = chapterId;

      await _applySettings(bookId);

      final subText = startOffset > 0 && startOffset < text.length
          ? text.substring(startOffset)
          : text;

      if (subText.trim().isEmpty) {
        _completionController.add(null);
        return;
      }

      await tts.speak(subText).timeout(const Duration(seconds: 5));
    } catch (e, st) {
      debugPrint('TTS speak error: $e\n$st');
      _completionController.add(null);
    }
  }

  Future<void> pause() async {
    try {
      await _ensureInit();
      await tts.pause().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('TTS pause error: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _ensureInit();
      await tts.speak(_currentText.substring(_currentCharPosition)).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('TTS resume error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _ensureInit();
      await tts.stop().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  int get currentCharPosition => _currentCharPosition;
  int? get currentBookId => _currentBookId;
  int? get currentChapterId => _currentChapterId;

  Future<void> dispose() async {
    await tts.stop();
    await _progressController.close();
    await _completionController.close();
  }
}
