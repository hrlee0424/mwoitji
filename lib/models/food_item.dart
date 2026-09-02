import 'package:flutter/material.dart';

enum FoodStatus { stored, consumed, discarded }

enum StorageType {
  fridge('냉장', Icons.kitchen_outlined),
  freezer('냉동', Icons.ac_unit),
  room('실온', Icons.inventory_2_outlined);

  const StorageType(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum FoodCategory {
  sideDish('반찬', Icons.rice_bowl_outlined),
  snack('간식', Icons.cookie_outlined),
  baking('베이킹 재료', Icons.cake_outlined),
  dairy('유제품', Icons.local_drink_outlined),
  produce('채소/과일', Icons.eco_outlined),
  meatSeafood('육류/해산물', Icons.set_meal_outlined),
  beverage('음료', Icons.local_cafe_outlined),
  seasoning('소스/양념', Icons.soup_kitchen_outlined),
  other('기타', Icons.category_outlined);

  const FoodCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum FoodUnit {
  piece('개'),
  pack('팩'),
  bag('봉'),
  bottle('병'),
  can('캔'),
  gram('g'),
  kilogram('kg'),
  milliliter('ml'),
  liter('L');

  const FoodUnit(this.label);

  final String label;
}

FoodUnit recommendedUnitFor(FoodCategory category) => switch (category) {
  FoodCategory.meatSeafood || FoodCategory.baking => FoodUnit.gram,
  FoodCategory.dairy || FoodCategory.beverage => FoodUnit.milliliter,
  FoodCategory.produce ||
  FoodCategory.sideDish ||
  FoodCategory.snack ||
  FoodCategory.seasoning ||
  FoodCategory.other => FoodUnit.piece,
};

class FoodItem {
  FoodItem({
    required this.id,
    required this.name,
    required this.expiryDate,
    required this.purchaseDate,
    required this.storage,
    required this.category,
    this.manufactureDate,
    this.amountValue = 1,
    this.amountUnit = FoodUnit.piece,
    this.status = FoodStatus.stored,
    this.completedAt,
    this.imageUrl,
  });

  final int id;
  final String name;
  final DateTime? expiryDate;
  final DateTime purchaseDate;
  final StorageType storage;
  final FoodCategory category;
  final DateTime? manufactureDate;
  final double amountValue;
  final FoodUnit amountUnit;
  FoodStatus status;
  DateTime? completedAt;
  final String? imageUrl;

  int? get daysLeft {
    final date = expiryDate;
    if (date == null) return null;
    return DateUtils.dateOnly(
      date,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
  }

  String get amountLabel {
    final value = amountValue
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    return '$value ${amountUnit.label}';
  }

  FoodItem useAmount(double usedAmount, {DateTime? usedAt}) {
    if (usedAmount <= 0 || usedAmount > amountValue) {
      throw ArgumentError.value(usedAmount, 'usedAmount');
    }
    final calculated = amountValue - usedAmount;
    final remaining = double.parse(calculated.toStringAsFixed(6));
    final fullyConsumed = remaining <= 0;
    return FoodItem(
      id: id,
      name: name,
      expiryDate: expiryDate,
      purchaseDate: purchaseDate,
      storage: storage,
      category: category,
      manufactureDate: manufactureDate,
      amountValue: fullyConsumed ? 0 : remaining,
      amountUnit: amountUnit,
      status: fullyConsumed ? FoodStatus.consumed : status,
      completedAt: fullyConsumed ? (usedAt ?? DateTime.now()) : completedAt,
      imageUrl: imageUrl,
    );
  }
}
