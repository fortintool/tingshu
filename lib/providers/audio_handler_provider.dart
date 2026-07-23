import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_handler.dart';
import '../services/tts_service.dart';

final audioHandlerProvider = Provider<TtsAudioHandler?>((ref) {
  return null;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService.instance;
});
