import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/ocr_service.dart';
import 'food_icon.dart';

class FoodCard extends StatelessWidget {
  const FoodCard({
    super.key,
    required this.food,
    required this.onTap,
    required this.onComplete,
  });

  final FoodItem food;
  final VoidCallback onTap;
  final Future<void> Function(FoodItem, FoodStatus) onComplete;

  String get _dayLabel {
    final daysLeft = food.daysLeft;
    if (daysLeft == null) return '기한 없음';
    if (daysLeft < 0) return '${daysLeft.abs()}일 지남';
    if (daysLeft == 0) return '오늘까지';
    return 'D-$daysLeft';
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = food.daysLeft;
    final urgent = daysLeft != null && daysLeft <= 3;
    final expiryLabel =
        food.expiryDate == null ? '기한 없음' : '${formatDate(food.expiryDate!)}까지';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      urgent
                          ? const Color(0xFFFFE9E4)
                          : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: FoodIcon(food: food),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _dayLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                                urgent
                                    ? Colors.red.shade700
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${food.category.label} · ${food.storage.label} · ${food.amountLabel} · $expiryLabel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (food.manufactureDate != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '제조 ${formatDate(food.manufactureDate!)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<FoodStatus>(
                tooltip: '처리',
                onSelected: (status) async => onComplete(food, status),
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(
                        value: FoodStatus.consumed,
                        child: Text('먹었어요'),
                      ),
                      PopupMenuItem(
                        value: FoodStatus.discarded,
                        child: Text('버렸어요'),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
