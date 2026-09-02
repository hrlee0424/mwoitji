import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_item.dart';
import '../services/ocr_service.dart';

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key, required this.startingId});

  final int startingId;

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final List<_ReceiptItemDraft> _items = [];
  DateTime _purchaseDate = DateUtils.dateOnly(DateTime.now());
  StorageType _storage = StorageType.fridge;
  bool _isScanning = false;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    '영수증 가져오기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('영수증 촬영'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('사진에서 선택'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
    );
    if (source != null) await _scanReceipt(source);
  }

  Future<void> _scanReceipt(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (image == null || !mounted) return;

    setState(() => _isScanning = true);
    final ocr = OcrService();
    try {
      final text = await ocr.recognize(InputImage.fromFilePath(image.path));
      final recognizedItems = extractReceiptItems(text);
      final today = DateUtils.dateOnly(DateTime.now());
      final receiptDates =
          extractDateCandidates(
            text,
          ).where((date) => !date.isAfter(today)).toList();
      if (!mounted) return;

      for (final item in _items) {
        item.dispose();
      }
      setState(() {
        _items
          ..clear()
          ..addAll(
            recognizedItems.map(
              (item) => _ReceiptItemDraft(item.name, item.quantity),
            ),
          );
        if (receiptDates.isNotEmpty) _purchaseDate = receiptDates.last;
      });
      if (recognizedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상품명을 찾지 못했어요. 선명하게 다시 촬영해 주세요.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('영수증을 읽지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      await ocr.dispose();
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _changePurchaseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _purchaseDate = selected);
  }

  void _addManualItem() {
    setState(() => _items.add(_ReceiptItemDraft('', 1)));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index).dispose());
  }

  void _save() {
    final items =
        _items
            .where((item) => item.nameController.text.trim().isNotEmpty)
            .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('등록할 식품을 한 개 이상 입력해 주세요.')));
      return;
    }
    final foods = List.generate(
      items.length,
      (index) => FoodItem(
        id: widget.startingId + index,
        name: items[index].nameController.text.trim(),
        expiryDate: null,
        purchaseDate: _purchaseDate,
        storage: _storage,
        category: FoodCategory.other,
        amountValue: _quantity(items[index]),
        amountUnit: FoodUnit.piece,
      ),
    );
    Navigator.pop(context, foods);
  }

  double _quantity(_ReceiptItemDraft item) {
    final value = int.tryParse(item.quantityController.text.trim());
    return value == null || value < 1 ? 1.0 : value.toDouble();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('영수증으로 등록'),
      actions: [
        TextButton(
          key: const Key('saveReceiptFoodsButton'),
          onPressed: _isScanning ? null : _save,
          child: const Text('한 번에 저장'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        FilledButton.icon(
          key: const Key('scanReceiptButton'),
          onPressed: _isScanning ? null : _chooseReceiptSource,
          icon:
              _isScanning
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.receipt_long_outlined),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Text(_isScanning ? '영수증 읽는 중...' : '영수증 촬영 또는 선택'),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('구매일'),
                subtitle: Text(formatDate(_purchaseDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changePurchaseDate,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<StorageType>(
                  initialValue: _storage,
                  decoration: const InputDecoration(labelText: '공통 보관 위치'),
                  items:
                      StorageType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _storage = value);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                '등록할 식품',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              key: const Key('addReceiptItemButton'),
              onPressed: _addManualItem,
              icon: const Icon(Icons.add),
              label: const Text('직접 추가'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '영수증을 촬영하면 인식한 상품들이 여기에 표시돼요.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ...List.generate(
            _items.length,
            (index) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('receiptFoodNameField-$index'),
                        controller: _items[index].nameController,
                        decoration: InputDecoration(
                          labelText: '식품 ${index + 1}',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      child: TextField(
                        key: Key('receiptFoodQuantityField-$index'),
                        controller: _items[index].quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: '수량',
                          suffixText: '개',
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: '제외',
                      onPressed: () => _removeItem(index),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ReceiptItemDraft {
  _ReceiptItemDraft(String name, int quantity)
    : nameController = TextEditingController(text: name),
      quantityController = TextEditingController(text: '$quantity');

  final TextEditingController nameController;
  final TextEditingController quantityController;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}
