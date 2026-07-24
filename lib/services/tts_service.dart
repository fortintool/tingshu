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

  final StreamController<({int chapter, int book})> _progressController =
      StreamController<({int chapter, int book})>.broadcast();
  Stream<({int chapter, int book})> get progressStream => _progressController.stream;

  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  Stream<void> get completionStream => _completionController.stream;

  bool _initialized = false;
  bool _isSpeaking = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;

    // 设置语言（必须在 speak 之前设置，否则 Android 无法朗读中文）
    try {
      await tts.setLanguage('zh-CN');
      debugPrint('TTS language set to zh-CN');
    } catch (e) {
      debugPrint('setLanguage zh-CN failed: $e, trying zh-Hans-CN');
      try {
        await tts.setLanguage('zh-Hans-CN');
        debugPrint('TTS language set to zh-Hans-CN');
      } catch (e2) {
        debugPrint('setLanguage zh-Hans-CN also failed: $e2');
      }
    }

    // 注册回调
    tts.setStartHandler(() {
      _isSpeaking = true;
      debugPrint('TTS onStart');
    });
    tts.setProgressHandler((String text, int start, int end, String word) {
      _currentCharPosition = end;
      _progressController.add((
        chapter: end,
        book: _chapterCharStart + end,
      ));
    });
    tts.setCompletionHandler(() {
      _isSpeaking = false;
      debugPrint('TTS onComplete');
      _completionController.add(null);
    });
    tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS onError: $msg');
      _completionController.add(null);
    });
    tts.setCancelHandler(() {
      _isSpeaking = false;
      debugPrint('TTS onCancel');
      _completionController.add(null);
    });

    _initialized = true;
    debugPrint('TTS initialized');
  }

  /// 应用设置
  Future<void> _applySettings(int? bookId) async {
    final global = await _db.getUserSettings();
    BookSettings? bookOverride;
    if (bookId != null && bookId > 0) {
      bookOverride = await _db.getBookSettings(bookId);
    }

    final voice = bookOverride?.voice ?? global.defaultVoice;
    final speed = bookOverride?.speed ?? global.defaultSpeed;
    final pitch = bookOverride?.pitch ?? global.defaultPitch;

    if (voice != null && voice.isNotEmpty) {
      try {
        await tts.setVoice({'name': voice, 'locale': 'zh-CN'});
      } catch (e) {
        debugPrint('setVoice failed: $e');
      }
    }

    try {
      await tts.setSpeechRate(speed);
    } catch (_) {}
    try {
      await tts.setPitch(pitch);
    } catch (_) {}

    _voice = voice;
    _speed = speed;
    _pitch = pitch;
  }

  /// 获取设备支持的语音列表
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final list = await tts.getVoices;
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

      // Android: speak() 会自动停止当前播放并开始新的，无需先调 stop()
      final result = await tts.speak(subText);
      debugPrint('TTS speak result: $result, textLen: ${subText.length}');
    } catch (e, st) {
      debugPrint('TTS speak error: $e\n$st');
    }
  }

  Future<void> pause() async {
    try {
      await tts.pause();
    } catch (e) {
      debugPrint('TTS pause error: $e');
    }
  }

  Future<void> resume() async {
    if (_currentText.isEmpty) return;
    try {
      final pos = _currentCharPosition;
      if (pos < _currentText.length) {
        await tts.speak(_currentText.substring(pos));
      }
    } catch (e) {
      debugPrint('TTS resume error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  bool get isSpeaking => _isSpeaking;
  int get currentCharPosition => _currentCharPosition;
  int? get currentBookId => _currentBookId;
  int? get currentChapterId => _currentChapterId;

  Future<void> dispose() async {
    await tts.stop();
    await _progressController.close();
    await _completionController.close();
  }
}