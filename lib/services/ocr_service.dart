import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  OcrService()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.korean);

  final TextRecognizer _recognizer;

  Future<String> recognize(InputImage image) async {
    final recognized = await _recognizer.processImage(image);
    return recognized.text;
  }

  Future<void> dispose() => _recognizer.close();
}

String formatDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

List<DateTime> extractDateCandidates(String text) {
  final normalized = text
      .replaceAll('년', '.')
      .replaceAll('월', '.')
      .replaceAll('일', ' ')
      .replaceAll('/', '.')
      .replaceAll('-', '.');
  final matches = RegExp(
    r'(?<!\d)(\d{2,4})\s*\.\s*(\d{1,2})\s*\.\s*(\d{1,2})(?!\d)',
  ).allMatches(normalized);
  final dates = <DateTime>{};

  for (final match in matches) {
    var year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    if (year < 2020 || year > DateTime.now().year + 10) continue;

    final candidate = DateTime(year, month, day);
    if (candidate.year == year &&
        candidate.month == month &&
        candidate.day == day) {
      dates.add(candidate);
    }
  }

  return dates.toList()..sort();
}

List<String> extractProductNameCandidates(String text) {
  final noiseWords = RegExp(
    r'소비기한|유통기한|제조|까지|영양|원재료|보관|주의|내용량|식품유형|품목보고|고객|문의|반품|교환|업소명|소재지|신고번호|칼로리|kcal|www\.|https?://|lot',
    caseSensitive: false,
  );
  final datePattern = RegExp(r'\d{2,4}\s*[.년/-]\s*\d{1,2}\s*[.월/-]\s*\d{1,2}');
  final onlyMeasurement = RegExp(
    r'^\s*\d+(?:[.,]\d+)?\s*(?:g|kg|ml|l|mg|kcal|%)\s*$',
    caseSensitive: false,
  );
  final candidates = <String>[];

  for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
    final line =
        rawLine
            .replaceAll(RegExp(r'^[\s•·|]+|[\s•·|]+$'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (line.length < 2 || line.length > 30) continue;
    if (!RegExp(r'[가-힣A-Za-z]').hasMatch(line)) continue;
    if (noiseWords.hasMatch(line) ||
        datePattern.hasMatch(line) ||
        onlyMeasurement.hasMatch(line)) {
      continue;
    }
    final digits = RegExp(r'\d').allMatches(line).length;
    if (digits > line.length * 0.6) continue;
    if (!candidates.any((item) => item.toLowerCase() == line.toLowerCase())) {
      candidates.add(line);
    }
  }

  return candidates.take(8).toList();
}

class ReceiptOcrItem {
  const ReceiptOcrItem({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

List<ReceiptOcrItem> extractReceiptItems(String text) {
  final noiseWords = RegExp(
    r'영수증|사업자|대표자|주소|전화|매장|고객|감사|문의|교환|환불|거래|승인|카드|현금|결제|합계|총액|금액|부가세|과세|면세|할인|잔돈|받을금액|수량|단가|상품명|품목|바코드|포인트',
    caseSensitive: false,
  );
  final dateOrTime = RegExp(r'\d{2,4}[./-]\d{1,2}[./-]\d{1,2}|\d{1,2}:\d{2}');
  final candidates = <ReceiptOcrItem>[];

  for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
    var line = rawLine.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isEmpty ||
        noiseWords.hasMatch(line) ||
        dateOrTime.hasMatch(line)) {
      continue;
    }
    line = line.replaceFirst(RegExp(r'^\d{1,3}[.)\-]?\s+'), '');
    final numericTail = RegExp(
      r'((?:\s+[-+]?\d[\d,]*(?:\.\d+)?(?:개|ea)?)+)\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    var quantity = 1;
    if (numericTail != null) {
      final values =
          RegExp(r'[-+]?\d[\d,]*(?:\.\d+)?')
              .allMatches(numericTail.group(1)!)
              .map((match) => match.group(0)!)
              .toList();
      if (values.length >= 2) {
        final possibleQuantity = int.tryParse(values.first.replaceAll(',', ''));
        if (possibleQuantity != null &&
            possibleQuantity > 0 &&
            possibleQuantity <= 99) {
          quantity = possibleQuantity;
        }
      }
      line = line.substring(0, numericTail.start);
    }
    line = line.replaceAll(RegExp(r'^[*#·•|\s]+|[*#·•|\s]+$'), '').trim();

    if (line.length < 2 || line.length > 40) continue;
    if (!RegExp(r'[가-힣A-Za-z]').hasMatch(line)) continue;
    final digits = RegExp(r'\d').allMatches(line).length;
    if (digits > line.length * 0.45) continue;
    if (!candidates.any(
      (item) => item.name.toLowerCase() == line.toLowerCase(),
    )) {
      candidates.add(ReceiptOcrItem(name: line, quantity: quantity));
    }
  }

  return candidates.take(30).toList();
}

List<String> extractReceiptItemCandidates(String text) =>
    extractReceiptItems(text).map((item) => item.name).toList();
