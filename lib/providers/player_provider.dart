import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class PlayerState {
  final Book? book;
  final Chapter? chapter;
  final bool isPlaying;
  const PlayerState({this.book, this.chapter, this.isPlaying = false});
}

class PlayerStateNotifier extends StateNotifier<PlayerState> {
  PlayerStateNotifier() : super(const PlayerState());

  void setPlaying({
    required Book? book,
    Chapter? chapter,
    required bool isPlaying,
  }) {
    state = PlayerState(
      book: book ?? state.book,
      chapter: chapter ?? state.chapter,
      isPlaying: isPlaying,
    );
  }

  void clear() {
    state = const PlayerState();
  }
}

final playerStateProvider =
    StateNotifierProvider<PlayerStateNotifier, PlayerState>(
  (ref) => PlayerStateNotifier(),
);
