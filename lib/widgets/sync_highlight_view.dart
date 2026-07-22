import 'package:flutter/material.dart';

class SyncHighlightView extends StatelessWidget {
  final String text;
  final int currentPosition;
  final void Function(int) onTapPosition;

  const SyncHighlightView({
    super.key,
    required this.text,
    required this.currentPosition,
    required this.onTapPosition,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }

    final sentences = _splitIntoSentences(text);
    final currentSentenceIndex = _findCurrentSentenceIndex(sentences, currentPosition);

    return ListView.builder(
      itemCount: sentences.length,
      itemBuilder: (_, index) {
        final sentence = sentences[index];
        final isHighlighted = index == currentSentenceIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: GestureDetector(
            onTap: () => onTapPosition(sentence.charStart),
            child: Text(
              sentence.text,
              style: TextStyle(
                fontSize: 18,
                height: 1.6,
                color: isHighlighted
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
                backgroundColor: isHighlighted
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  List<_Sentence> _splitIntoSentences(String text) {
    final sentences = <_Sentence>[];
    final pattern = RegExp(r'([。！？；\n]+|[.!?;\n]+)');
    int lastEnd = 0;

    pattern.allMatches(text).forEach((match) {
      final sentenceText = text.substring(lastEnd, match.end);
      if (sentenceText.trim().isNotEmpty) {
        sentences.add(_Sentence(
          text: sentenceText,
          charStart: lastEnd,
          charEnd: match.end,
        ));
      }
      lastEnd = match.end;
    });

    if (lastEnd < text.length) {
      sentences.add(_Sentence(
        text: text.substring(lastEnd),
        charStart: lastEnd,
        charEnd: text.length,
      ));
    }

    return sentences;
  }

  int _findCurrentSentenceIndex(List<_Sentence> sentences, int position) {
    for (int i = 0; i < sentences.length; i++) {
      if (position >= sentences[i].charStart && position < sentences[i].charEnd) {
        return i;
      }
    }
    return sentences.isEmpty ? 0 : sentences.length - 1;
  }
}

class _Sentence {
  final String text;
  final int charStart;
  final int charEnd;

  _Sentence({
    required this.text,
    required this.charStart,
    required this.charEnd,
  });
}
