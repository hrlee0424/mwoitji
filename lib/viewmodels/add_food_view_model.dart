import 'package:flutter/material.dart';

import '../models/food_item.dart';

class AddFoodViewModel extends ChangeNotifier {
  AddFoodViewModel({required this.id, FoodItem? initialFood})
    : _initialFood = initialFood,
      nameController = TextEditingController(text: initialFood?.name ?? ''),
      amountController = TextEditingController(
        text: initialFood == null ? '1' : _amountText(initialFood.amountValue),
      ) {
    if (initialFood != null) {
      purchaseDate = initialFood.purchaseDate;
      manufactureDate = initialFood.manufactureDate;
      expiryDate = initialFood.expiryDate;
      storage = initialFood.storage;
      category = initialFood.category;
      amountUnit = initialFood.amountUnit;
    }
  }

  final int id;
  final FoodItem? _initialFood;
  final TextEditingController nameController;
  final TextEditingController amountController;
  DateTime purchaseDate = DateUtils.dateOnly(DateTime.now());
  DateTime? manufactureDate;
  DateTime? expiryDate;
  StorageType storage = StorageType.fridge;
  FoodCategory category = FoodCategory.other;
  FoodUnit amountUnit = FoodUnit.piece;
  bool isScanning = false;

  bool get isEditing => _initialFood != null;

  static String _amountText(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  void update({
    DateTime? purchaseDate,
    DateTime? manufactureDate,
    DateTime? expiryDate,
    StorageType? storage,
    bool? isScanning,
  }) {
    this.purchaseDate = purchaseDate ?? this.purchaseDate;
    this.manufactureDate = manufactureDate ?? this.manufactureDate;
    this.expiryDate = expiryDate ?? this.expiryDate;
    this.storage = storage ?? this.storage;
    this.isScanning = isScanning ?? this.isScanning;
    notifyListeners();
  }

  void setCategory(FoodCategory value) {
    category = value;
    amountUnit = recommendedUnitFor(value);
    notifyListeners();
  }

  void setAmountUnit(FoodUnit value) {
    amountUnit = value;
    notifyListeners();
  }

  double? get parsedAmount =>
      double.tryParse(amountController.text.trim().replaceAll(',', '.'));

  void clearManufactureDate() {
    manufactureDate = null;
    notifyListeners();
  }

  void clearExpiryDate() {
    expiryDate = null;
    notifyListeners();
  }

  void setProductName(String name) {
    nameController.text = name;
    notifyListeners();
  }

  FoodItem buildFoodItem() => FoodItem(
    id: id,
    name: nameController.text.trim(),
    expiryDate: expiryDate,
    purchaseDate: purchaseDate,
    storage: storage,
    category: category,
    manufactureDate: manufactureDate,
    amountValue: parsedAmount ?? 1,
    amountUnit: amountUnit,
    status: _initialFood?.status ?? FoodStatus.stored,
    completedAt: _initialFood?.completedAt,
    imageUrl: _initialFood?.imageUrl,
  );

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }
}
