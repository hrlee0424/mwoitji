import 'package:flutter/material.dart';

import '../services/ocr_service.dart';

class DateTile extends StatelessWidget {
  const DateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    tileColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Colors.grey.shade500),
      borderRadius: BorderRadius.circular(4),
    ),
    leading: const Icon(Icons.dialpad_outlined),
    title: Text(label),
    subtitle: Text(value == null ? 'YYYYMMDD 숫자로 입력하세요' : formatDate(value!)),
    trailing:
        onClear == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
              tooltip: '선택 해제',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
  );
}
