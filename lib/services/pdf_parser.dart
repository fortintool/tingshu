import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf_text/pdf_text.dart';
import '../utils/chapter_splitter.dart';

class PdfParseResult {
  final String title;
  final List<SplitResult> chapters;
  const PdfParseResult({required this.title, required this.chapters});
}

class PdfParserService {
  static Future<PdfParseResult> parse(String filePath) async {
    final doc = await PDFDoc.fromPath(filePath);
    final text = await doc.text;

    final fileName = p.basenameWithoutExtension(filePath);
    if (text.trim().isEmpty) {
      return PdfParseResult(title: fileName, chapters: []);
    }

    final chapters = ChapterSplitter.split(text);
    return PdfParseResult(title: fileName, chapters: chapters);
  }
}
