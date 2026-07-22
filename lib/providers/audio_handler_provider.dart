import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_handler.dart';
import '../services/tts_service.dart';

/// 全局持有 audio_handler 引用。
/// main.dart 中通过 overrideWithValue 注入。
final audioHandlerProvider = Provider<TtsAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main.dart');
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService.instance;
});
