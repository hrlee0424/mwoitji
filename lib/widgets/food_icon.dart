import 'package:flutter/material.dart';

import '../models/food_item.dart';

class FoodIcon extends StatelessWidget {
  const FoodIcon({super.key, required this.food, this.size = 25});

  final FoodItem food;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    _iconFor(food),
    style: TextStyle(fontSize: size, height: 1),
    textAlign: TextAlign.center,
    semanticsLabel: '${food.name} 아이콘',
  );

  String _iconFor(FoodItem food) {
    final name = food.name.toLowerCase().replaceAll(' ', '');
    const namedIcons = <String, String>{
      '우유': '🥛',
      '두부': '◻️',
      '만두': '🥟',
      '소금': '🧂',
      '설탕': '🧂',
      '계란': '🥚',
      '달걀': '🥚',
      '빵': '🍞',
      '식빵': '🍞',
      '사과': '🍎',
      '바나나': '🍌',
      '포도': '🍇',
      '딸기': '🍓',
      '토마토': '🍅',
      '당근': '🥕',
      '감자': '🥔',
      '고구마': '🍠',
      '옥수수': '🌽',
      '양파': '🧅',
      '마늘': '🧄',
      '버섯': '🍄',
      '샐러드': '🥗',
      '김치': '🥬',
      '밥': '🍚',
      '라면': '🍜',
      '국수': '🍜',
      '치즈': '🧀',
      '버터': '🧈',
      '요거트': '🥛',
      '요구르트': '🥛',
      '소고기': '🥩',
      '돼지고기': '🥓',
      '닭고기': '🍗',
      '고기': '🥩',
      '생선': '🐟',
      '연어': '🍣',
      '새우': '🦐',
      '게': '🦀',
      '물': '💧',
      '주스': '🧃',
      '커피': '☕',
      '차': '🍵',
      '콜라': '🥤',
      '사이다': '🥤',
      '과자': '🍪',
      '초콜릿': '🍫',
      '케이크': '🍰',
      '아이스크림': '🍨',
      '피자': '🍕',
      '햄버거': '🍔',
      '소시지': '🌭',
      '시리얼': '🥣',
      '꿀': '🍯',
      '잼': '🍯',
    };

    for (final entry in namedIcons.entries) {
      if (name.contains(entry.key)) return entry.value;
    }

    return switch (food.category) {
      FoodCategory.sideDish => '🍚',
      FoodCategory.snack => '🍪',
      FoodCategory.baking => '🧁',
      FoodCategory.dairy => '🥛',
      FoodCategory.produce => '🥬',
      FoodCategory.meatSeafood => '🥩',
      FoodCategory.beverage => '🧃',
      FoodCategory.seasoning => '🧂',
      FoodCategory.other => '🍽️',
    };
  }
}
