import 'package:flutter/material.dart';
import '../models/book.dart';

class BookCover extends StatelessWidget {
  final Book book;
  final double width;
  final double height;

  const BookCover({
    super.key,
    required this.book,
    this.width = 56,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: hasCover
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(book.coverPath!, fit: BoxFit.cover),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  _firstTwoChars(book.title),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }

  String _firstTwoChars(String s) {
    final t = s.trim();
    if (t.isEmpty) return '?';
    if (t.runes.length <= 2) return t;
    return String.fromCharCodes(t.runes.take(2));
  }
}
