class OcrScanResult {
  const OcrScanResult({
    required this.expiryDate,
    required this.productNameCandidates,
  });

  final DateTime? expiryDate;
  final List<String> productNameCandidates;
}
