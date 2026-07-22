import 'package:path/path.dart' as p;
import '../utils/chapter_splitter.dart';

class PdfParseResult {
  final String title;
  final List<SplitResult> chapters;
  const PdfParseResult({required this.title, required this.chapters});
}

class PdfParserService {
  static Future<PdfParseResult> parse(String filePath) async {
    // PDF 暂不支持，待后续替换为可用的 PDF 文本提取库
    final fileName = p.basenameWithoutExtension(filePath);
    return PdfParseResult(title: fileName, chapters: []);
  }
}