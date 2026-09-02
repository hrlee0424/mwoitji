import 'package:flutter/material.dart';

import '../models/food_item.dart';
import 'food_card.dart';
import 'food_icon.dart';

class FridgeOverview extends StatelessWidget {
  const FridgeOverview({
    super.key,
    required this.foods,
    required this.onFoodTap,
    required this.onComplete,
  });

  final List<FoodItem> foods;
  final ValueChanged<FoodItem> onFoodTap;
  final Future<void> Function(FoodItem, FoodStatus) onComplete;

  @override
  Widget build(BuildContext context) {
    final freezer =
        foods.where((food) => food.storage == StorageType.freezer).toList();
    final fridge =
        foods.where((food) => food.storage == StorageType.fridge).toList();
    final room =
        foods.where((food) => food.storage == StorageType.room).toList();

    if (foods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: Text('조건에 맞는 식품이 없어요.')),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _FridgeZone(
                title: '냉동실',
                icon: Icons.ac_unit,
                foods: freezer,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                top: true,
                onFoodTap: onFoodTap,
                onShowAll: () => _showZoneFoods(context, '냉동실', freezer),
              ),
              const SizedBox(height: 6),
              _FridgeZone(
                title: '냉장실',
                icon: Icons.kitchen_outlined,
                foods: fridge,
                backgroundColor: Theme.of(context).colorScheme.surface,
                onFoodTap: onFoodTap,
                onShowAll: () => _showZoneFoods(context, '냉장실', fridge),
              ),
              const SizedBox(height: 6),
              _FridgeZone(
                title: '실온',
                icon: Icons.inventory_2_outlined,
                foods: room,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                bottom: true,
                onFoodTap: onFoodTap,
                onShowAll: () => _showZoneFoods(context, '실온', room),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showZoneFoods(
    BuildContext context,
    String title,
    List<FoodItem> zoneFoods,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title ${zoneFoods.length}개',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child:
                          zoneFoods.isEmpty
                              ? const Center(child: Text('등록된 식품이 없어요.'))
                              : ListView(
                                children:
                                    zoneFoods
                                        .map(
                                          (food) => FoodCard(
                                            food: food,
                                            onTap: () {
                                              Navigator.pop(sheetContext);
                                              onFoodTap(food);
                                            },
                                            onComplete: onComplete,
                                          ),
                                        )
                                        .toList(),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _FridgeZone extends StatelessWidget {
  const _FridgeZone({
    required this.title,
    required this.icon,
    required this.foods,
    required this.backgroundColor,
    required this.onFoodTap,
    required this.onShowAll,
    this.top = false,
    this.bottom = false,
  });

  static const _maxSlots = 9;
  final String title;
  final IconData icon;
  final List<FoodItem> foods;
  final Color backgroundColor;
  final ValueChanged<FoodItem> onFoodTap;
  final VoidCallback onShowAll;
  final bool top;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    final hasOverflow = foods.length > _maxSlots;
    final visibleFoods = foods.take(hasOverflow ? _maxSlots - 1 : _maxSlots);
    final overflowCount = foods.length - (_maxSlots - 1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(top ? 16 : 8),
          bottom: Radius.circular(bottom ? 16 : 8),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            key: Key('zone-$title'),
            onTap: onShowAll,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${foods.length}개'),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 19),
                ],
              ),
            ),
          ),
          if (foods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '비어 있어요',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 7),
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.15,
              children: [
                ...visibleFoods.map(
                  (food) => _FoodSlot(food: food, onTap: () => onFoodTap(food)),
                ),
                if (hasOverflow)
                  _OverflowSlot(count: overflowCount, onTap: onShowAll),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FoodSlot extends StatelessWidget {
  const _FoodSlot({required this.food, required this.onTap});

  final FoodItem food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FoodIcon(food: food, size: 24),
            const SizedBox(height: 5),
            Text(
              food.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverflowSlot extends StatelessWidget {
  const _OverflowSlot({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.primary,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: const Key('fridgeOverviewOverflow'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Text(
          '+$count개',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}
