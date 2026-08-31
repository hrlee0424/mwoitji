import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_item.dart';
import '../models/ocr_scan_result.dart';
import '../services/ocr_service.dart';
import '../viewmodels/add_food_view_model.dart';
import '../widgets/date_tile.dart';
import 'live_scanner_screen.dart';

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key, required this.id, this.initialFood});

  final int id;
  final FoodItem? initialFood;

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AddFoodViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AddFoodViewModel(
      id: widget.id,
      initialFood: widget.initialFood,
    )..addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _viewModel
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate({DateTime? initialValue}) => showDialog<DateTime>(
    context: context,
    builder: (_) => _DateInputDialog(initialValue: initialValue),
  );

  Future<void> _scanGallery() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2200,
    );
    if (image == null || !mounted) return;

    _viewModel.update(isScanning: true);
    final ocrService = OcrService();
    try {
      final text = await ocrService.recognize(
        InputImage.fromFilePath(image.path),
      );
      final candidates = extractDateCandidates(text);
      if (!mounted) return;
      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('날짜를 찾지 못했어요. 가까이에서 다시 촬영해 주세요.')),
        );
        return;
      }

      final selected = await _selectDate(candidates);
      if (selected == null || !mounted) return;
      _viewModel.update(expiryDate: selected);
      await _chooseProductName(extractProductNameCandidates(text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${formatDate(selected)}을 소비기한으로 입력했어요.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상품 정보를 인식하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      await ocrService.dispose();
      if (mounted) _viewModel.update(isScanning: false);
    }
  }

  Future<DateTime?> _selectDate(List<DateTime> candidates) async {
    if (candidates.length == 1) return candidates.first;
    return showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '소비기한을 선택하세요',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('사진에서 여러 날짜를 찾았어요.'),
                  const SizedBox(height: 10),
                  ...candidates.map(
                    (date) => ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(formatDate(date)),
                      onTap: () => Navigator.pop(context, date),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _chooseProductName(List<String> candidates) async {
    if (candidates.isEmpty ||
        _viewModel.nameController.text.trim().isNotEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.65,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상품명을 선택하세요',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('포장지에서 상품명으로 보이는 글자를 찾았어요.'),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        key: const Key('productCandidateList'),
                        children: [
                          ...candidates
                              .take(5)
                              .map(
                                (name) => ListTile(
                                  leading: const Icon(
                                    Icons.inventory_2_outlined,
                                  ),
                                  title: Text(name),
                                  onTap: () => Navigator.pop(context, name),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('manualProductNameOption'),
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text(
                        '직접 입력',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('후보에 원하는 상품명이 없어요'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
    if (selected != null && mounted) _viewModel.setProductName(selected);
  }

  Future<void> _showOcrSourcePicker() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    '상품 정보 가져오기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: const Text('실시간으로 읽기'),
                  subtitle: const Text('상품명과 날짜가 함께 보이게 맞추세요'),
                  onTap: () => Navigator.pop(context, 'live'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('사진에서 선택'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
    );

    if (source == 'gallery') {
      await _scanGallery();
    } else if (source == 'live' && mounted) {
      final result = await Navigator.of(context).push<OcrScanResult>(
        MaterialPageRoute(builder: (_) => const LiveScannerScreen()),
      );
      if (result != null && mounted) {
        if (result.expiryDate != null) {
          _viewModel.update(expiryDate: result.expiryDate);
        }
        await _chooseProductName(result.productNameCandidates);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('인식된 상품 정보를 입력했어요.')));
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _viewModel.buildFoodItem());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_viewModel.isEditing ? '식품 수정' : '식품 등록'),
      actions: [TextButton(onPressed: _save, child: const Text('저장'))],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton.icon(
            key: const Key('ocrButton'),
            onPressed: _viewModel.isScanning ? null : _showOcrSourcePicker,
            icon:
                _viewModel.isScanning
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.document_scanner_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                _viewModel.isScanning ? '상품 정보 인식 중...' : '사진으로 상품 정보 읽기',
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('foodNameField'),
            controller: _viewModel.nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '식품명 *',
              hintText: '예: 우유',
            ),
            validator:
                (value) =>
                    value == null || value.trim().isEmpty
                        ? '식품명을 입력해 주세요.'
                        : null,
          ),
          const SizedBox(height: 16),
          DateTile(
            label: '구매일',
            value: _viewModel.purchaseDate,
            onTap: () async {
              final date = await _pickDate(
                initialValue: _viewModel.purchaseDate,
              );
              if (date != null) _viewModel.update(purchaseDate: date);
            },
          ),
          const SizedBox(height: 12),
          DateTile(
            label: '제조일 (선택)',
            value: _viewModel.manufactureDate,
            onTap: () async {
              final date = await _pickDate(
                initialValue:
                    _viewModel.manufactureDate ??
                    DateUtils.dateOnly(DateTime.now()),
              );
              if (date != null) _viewModel.update(manufactureDate: date);
            },
            onClear:
                _viewModel.manufactureDate == null
                    ? null
                    : _viewModel.clearManufactureDate,
          ),
          const SizedBox(height: 12),
          DateTile(
            label: '소비기한 (선택)',
            value: _viewModel.expiryDate,
            onTap: () async {
              final date = await _pickDate();
              if (date != null) _viewModel.update(expiryDate: date);
            },
            onClear:
                _viewModel.expiryDate == null
                    ? null
                    : _viewModel.clearExpiryDate,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<FoodCategory>(
            key: const Key('foodCategoryField'),
            value: _viewModel.category,
            decoration: const InputDecoration(labelText: '카테고리'),
            items:
                FoodCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Icon(category.icon, size: 20),
                            const SizedBox(width: 10),
                            Text(category.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) _viewModel.setCategory(value);
            },
          ),
          const SizedBox(height: 20),
          Text('보관 위치', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<StorageType>(
            segments:
                StorageType.values
                    .map(
                      (type) => ButtonSegment(
                        value: type,
                        icon: Icon(type.icon),
                        label: Text(type.label),
                      ),
                    )
                    .toList(),
            selected: {_viewModel.storage},
            onSelectionChanged:
                (value) => _viewModel.update(storage: value.first),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: const Key('foodAmountField'),
                  controller: _viewModel.amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: '보유량',
                    hintText: '예: 600, 1.5',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (amount == null || amount <= 0) {
                      return '0보다 큰 수량을 입력해 주세요.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<FoodUnit>(
                  key: const Key('foodUnitField'),
                  value: _viewModel.amountUnit,
                  decoration: const InputDecoration(labelText: '단위'),
                  items:
                      FoodUnit.values
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) _viewModel.setAmountUnit(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_viewModel.isEditing ? '수정 완료' : '등록하기'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DateInputDialog extends StatefulWidget {
  const _DateInputDialog({this.initialValue});

  final DateTime? initialValue;

  @override
  State<_DateInputDialog> createState() => _DateInputDialogState();
}

class _DateInputDialogState extends State<_DateInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final date = widget.initialValue;
    final initialText =
        date == null
            ? ''
            : '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    _controller = TextEditingController(text: initialText);
    if (initialText.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialText.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String input) {
    if (!RegExp(r'^\d{8}$').hasMatch(input)) return null;
    final year = int.parse(input.substring(0, 4));
    final month = int.parse(input.substring(4, 6));
    final day = int.parse(input.substring(6, 8));
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String? _validate(String? value) {
    final input = value?.trim() ?? '';
    if (input.length != 8) return 'YYYYMMDD 형식의 8자리를 입력해 주세요.';
    final date = _parseDate(input);
    if (date == null) return '존재하는 날짜를 입력해 주세요.';
    final firstDate = DateTime(2020);
    final lastDate = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 3650)),
    );
    if (date.isBefore(firstDate) || date.isAfter(lastDate)) {
      return '2020년부터 ${lastDate.year}년 사이의 날짜를 입력해 주세요.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _parseDate(_controller.text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('날짜 직접 입력'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        key: const Key('dateNumberField'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8),
        ],
        decoration: const InputDecoration(
          labelText: '날짜 8자리',
          hintText: '예: 20260915',
          helperText: '연도 4자리 + 월 2자리 + 일 2자리',
          counterText: '',
        ),
        maxLength: 8,
        validator: _validate,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('confirmDateButton'),
        onPressed: _submit,
        child: const Text('확인'),
      ),
    ],
  );
}

@Deprecated('Use AddFoodScreen instead.')
typedef AddFoodPage = AddFoodScreen;
