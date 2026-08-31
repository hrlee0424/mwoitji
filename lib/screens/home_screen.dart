import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_theme_style.dart';
import '../models/food_item.dart';
import '../services/ocr_service.dart';
import '../viewmodels/fridge_view_model.dart';
import '../viewmodels/theme_view_model.dart';
import '../widgets/empty_state.dart';
import '../widgets/food_card.dart';
import '../widgets/food_icon.dart';
import '../widgets/fridge_overview.dart';
import 'add_food_screen.dart';

class MwoitjiHome extends StatefulWidget {
  const MwoitjiHome({super.key, required this.themeViewModel});

  final ThemeViewModel themeViewModel;

  @override
  State<MwoitjiHome> createState() => _MwoitjiHomeState();
}

class _MwoitjiHomeState extends State<MwoitjiHome> {
  final _viewModel = FridgeViewModel();
  final _searchController = TextEditingController();
  int _tabIndex = 0;
  bool _showOverview = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_refresh);
    _viewModel.initialize();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  Future<void> _openAddFood() async {
    final food = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(builder: (_) => AddFoodScreen(id: _viewModel.nextId)),
    );
    if (food == null) return;
    try {
      await _viewModel.addFood(food);
    } catch (_) {
      if (mounted) _showPersistenceError();
    }
  }

  Future<void> _showFoodDetails(FoodItem food) async {
    final action = await showDialog<_FoodDetailAction>(
      context: context,
      builder: (_) => _FoodDetailsDialog(food: food),
    );
    if (!mounted) return;
    if (action == _FoodDetailAction.edit) {
      await _openEditFood(food);
    } else if (action == _FoodDetailAction.delete) {
      await _confirmDeleteFood(food);
    }
  }

  Future<void> _confirmDeleteFood(FoodItem food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('식품을 삭제할까요?'),
            content: Text('${food.name} 정보가 냉장고와 기록에서 삭제돼요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                key: const Key('confirmDeleteFoodButton'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _viewModel.deleteFood(food);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${food.name}을(를) 삭제했어요.'),
            action: SnackBarAction(
              label: '되돌리기',
              onPressed: () async {
                try {
                  await _viewModel.restoreDeletedFood(food);
                } catch (_) {
                  if (mounted) _showPersistenceError();
                }
              },
            ),
          ),
        );
    } catch (_) {
      if (mounted) _showPersistenceError();
    }
  }

  Future<void> _openEditFood(FoodItem food) async {
    final updated = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(
        builder: (_) => AddFoodScreen(id: food.id, initialFood: food),
      ),
    );
    if (updated == null) return;
    try {
      await _viewModel.updateFood(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${updated.name} 정보를 수정했어요.')));
    } catch (_) {
      if (mounted) _showPersistenceError();
    }
  }

  Future<void> _completeFood(FoodItem food, FoodStatus status) async {
    if (status == FoodStatus.consumed) {
      await _recordConsumedAmount(food);
      return;
    }
    try {
      await _viewModel.completeFood(food, status);
    } catch (_) {
      if (mounted) _showPersistenceError();
      return;
    }
    if (!mounted) return;
    final message =
        status == FoodStatus.consumed
            ? '${food.name}을(를) 먹음 처리했어요.'
            : '${food.name}을(를) 버림 처리했어요.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () async {
              try {
                await _viewModel.restoreFood(food);
              } catch (_) {
                if (mounted) _showPersistenceError();
              }
            },
          ),
        ),
      );
  }

  Future<void> _recordConsumedAmount(FoodItem food) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _ConsumeAmountDialog(food: food),
    );
    if (amount == null || !mounted) return;

    try {
      final updated = await _viewModel.consumeAmount(food, amount);
      if (!mounted) return;
      final amountText = amount
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'\.?0+$'), '');
      final message =
          updated.status == FoodStatus.consumed
              ? '${food.name}을(를) 모두 먹었어요.'
              : '$amountText ${food.amountUnit.label}을(를) 먹었어요. ${updated.amountLabel} 남았어요.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: '되돌리기',
              onPressed: () async {
                try {
                  await _viewModel.updateFood(food);
                } catch (_) {
                  if (mounted) _showPersistenceError();
                }
              },
            ),
          ),
        );
    } catch (_) {
      if (mounted) _showPersistenceError();
    }
  }

  void _showPersistenceError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_viewModel.persistenceError ?? '저장 중 문제가 발생했어요.'),
        ),
      );
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _FridgePage(
        foods: _viewModel.allStoredFoods,
        filter: _viewModel.filter,
        searchQuery: _searchQuery,
        showOverview: _showOverview,
        onViewChanged: (value) => setState(() => _showOverview = value),
        onFilterChanged: _viewModel.setFilter,
        onFoodTap: _showFoodDetails,
        onComplete: _completeFood,
      ),
      _HistoryPage(foods: _viewModel.foods),
      _StatsPage(foods: _viewModel.foods),
      _SettingsPage(themeViewModel: widget.themeViewModel),
    ];
    const titles = ['뭐있지', '기록', '통계', '설정'];

    return Scaffold(
      appBar: AppBar(
        title:
            _tabIndex == 0 && _isSearching
                ? TextField(
                  key: const Key('appBarFoodSearchField'),
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: '식품 이름 검색',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                )
                : Text(
                  titles[_tabIndex],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        actions: [
          if (_tabIndex == 0)
            IconButton(
              key: Key(
                _isSearching ? 'closeFoodSearchButton' : 'openFoodSearchButton',
              ),
              tooltip: _isSearching ? '검색 닫기' : '식품 검색',
              onPressed:
                  _isSearching
                      ? _closeSearch
                      : () => setState(() => _isSearching = true),
              icon: Icon(_isSearching ? Icons.close : Icons.search),
            ),
        ],
        backgroundColor: Colors.transparent,
      ),
      body: IndexedStack(index: _tabIndex, children: pages),
      floatingActionButton:
          _tabIndex == 0
              ? FloatingActionButton.extended(
                key: const Key('addFoodButton'),
                onPressed: _openAddFood,
                icon: const Icon(Icons.add),
                label: const Text('식품 등록'),
              )
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          if (index != 0 && _isSearching) {
            _searchController.clear();
            _searchQuery = '';
            _isSearching = false;
          }
          setState(() => _tabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            label: '냉장고',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: '기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: '통계',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class _FridgePage extends StatelessWidget {
  const _FridgePage({
    required this.foods,
    required this.filter,
    required this.searchQuery,
    required this.showOverview,
    required this.onViewChanged,
    required this.onFilterChanged,
    required this.onFoodTap,
    required this.onComplete,
  });

  final List<FoodItem> foods;
  final StorageType? filter;
  final String searchQuery;
  final bool showOverview;
  final ValueChanged<bool> onViewChanged;
  final ValueChanged<StorageType?> onFilterChanged;
  final ValueChanged<FoodItem> onFoodTap;
  final Future<void> Function(FoodItem, FoodStatus) onComplete;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final searchedFoods =
        foods
            .where(
              (food) =>
                  normalizedQuery.isEmpty ||
                  food.name.toLowerCase().contains(normalizedQuery),
            )
            .toList();
    final listFoods =
        searchedFoods
            .where((food) => filter == null || food.storage == filter)
            .toList();
    final urgent =
        foods.where((food) {
          final daysLeft = food.daysLeft;
          return daysLeft != null && daysLeft <= 3;
        }).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: Icon(
                  Icons.eco_outlined,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '소비기한 임박 $urgent개',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '가까운 식품부터 확인해 보세요.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.view_list_outlined),
              label: Text('목록'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.kitchen_outlined),
              label: Text('한눈에'),
            ),
          ],
          selected: {showOverview},
          onSelectionChanged: (value) => onViewChanged(value.first),
        ),
        const SizedBox(height: 14),
        if (showOverview)
          if (foods.isEmpty)
            const EmptyState(
              icon: Icons.kitchen_outlined,
              title: '등록된 식품이 없어요',
              subtitle: '식품을 등록하면 냉장고 안에 보여드려요.',
            )
          else
            FridgeOverview(
              foods: searchedFoods,
              onFoodTap: onFoodTap,
              onComplete: onComplete,
            )
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: filter == null,
                  onSelected: (_) => onFilterChanged(null),
                ),
                const SizedBox(width: 8),
                ...StorageType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(type.icon, size: 18),
                      label: Text(type.label),
                      selected: filter == type,
                      onSelected: (_) => onFilterChanged(type),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (listFoods.isEmpty)
            const EmptyState(
              icon: Icons.kitchen_outlined,
              title: '조건에 맞는 식품이 없어요',
              subtitle: '검색어나 보관 위치를 바꿔 보세요.',
            )
          else
            ...listFoods.map(
              (food) => FoodCard(
                food: food,
                onTap: () => onFoodTap(food),
                onComplete: onComplete,
              ),
            ),
        ],
      ],
    );
  }
}

class _ConsumeAmountDialog extends StatefulWidget {
  const _ConsumeAmountDialog({required this.food});

  final FoodItem food;

  @override
  State<_ConsumeAmountDialog> createState() => _ConsumeAmountDialogState();
}

class _ConsumeAmountDialogState extends State<_ConsumeAmountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  double? get _amount =>
      double.tryParse(_controller.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final amount = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      return '0보다 큰 양을 입력해 주세요.';
    }
    if (amount > widget.food.amountValue) {
      return '현재 보유량보다 많이 입력할 수 없어요.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _amount);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('얼마나 먹었나요?'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('현재 보유량: ${widget.food.amountLabel}'),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('consumedAmountField'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: '먹은 양',
              hintText: '예: 200',
              suffixText: widget.food.amountUnit.label,
            ),
            validator: _validate,
            onFieldSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('consumeAllButton'),
              onPressed: () {
                _controller.text = widget.food.amountValue
                    .toStringAsFixed(2)
                    .replaceFirst(RegExp(r'\.?0+$'), '');
              },
              child: const Text('전부 입력'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('confirmConsumedAmountButton'),
        onPressed: _submit,
        child: const Text('기록'),
      ),
    ],
  );
}

enum _FoodDetailAction { edit, delete }

class _FoodDetailsDialog extends StatelessWidget {
  const _FoodDetailsDialog({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: FoodIcon(food: food),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            food.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FoodDetailRow(label: '보유량', value: food.amountLabel),
          _FoodDetailRow(label: '카테고리', value: food.category.label),
          _FoodDetailRow(label: '보관 위치', value: food.storage.label),
          const Divider(height: 24),
          _FoodDetailRow(label: '구매일', value: formatDate(food.purchaseDate)),
          _FoodDetailRow(
            label: '제조일',
            value:
                food.manufactureDate == null
                    ? '-'
                    : formatDate(food.manufactureDate!),
          ),
          _FoodDetailRow(
            label: '소비기한',
            value:
                food.expiryDate == null
                    ? '기한 없음'
                    : formatDate(food.expiryDate!),
          ),
        ],
      ),
    ),
    actions: [
      FilledButton.icon(
        key: const Key('editFoodButton'),
        onPressed: () => Navigator.pop(context, _FoodDetailAction.edit),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('수정'),
      ),
      TextButton.icon(
        key: const Key('deleteFoodButton'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(context, _FoodDetailAction.delete),
        icon: const Icon(Icons.delete_outline),
        label: const Text('삭제'),
      ),
      TextButton(
        key: const Key('closeFoodDetailsButton'),
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}

class _FoodDetailRow extends StatelessWidget {
  const _FoodDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.foods});

  final List<FoodItem> foods;

  @override
  Widget build(BuildContext context) {
    final history =
        foods.where((food) => food.status != FoodStatus.stored).toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    if (history.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: '아직 기록이 없어요',
          subtitle: '식품을 먹거나 버리면 여기에 기록돼요.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: history.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (_, index) {
        final food = history[index];
        final consumed = food.status == FoodStatus.consumed;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Icon(consumed ? Icons.check : Icons.delete_outline),
          ),
          title: Text(
            food.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(formatDate(food.completedAt!)),
          trailing: Text(
            consumed ? '먹음' : '버림',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: consumed ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        );
      },
    );
  }
}

class _StatsPage extends StatelessWidget {
  const _StatsPage({required this.foods});

  final List<FoodItem> foods;

  @override
  Widget build(BuildContext context) {
    final consumed =
        foods.where((food) => food.status == FoodStatus.consumed).length;
    final discarded =
        foods.where((food) => food.status == FoodStatus.discarded).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '나의 냉장고 요약',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '등록',
                value: foods.length,
                color: const Color(0xFFE3F0E7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '먹음',
                value: consumed,
                color: const Color(0xFFE7F0FA),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '버림',
                value: discarded,
                color: const Color(0xFFFFE9E4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const EmptyState(
          icon: Icons.insights_outlined,
          title: '기록을 더 모아보세요',
          subtitle: '먹음·버림 기록이 쌓이면 자주 구매하고 소비하는 식품을 분석해 드려요.',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    ),
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.themeViewModel});

  final ThemeViewModel themeViewModel;

  Future<void> _selectTheme(BuildContext context, AppThemeStyle style) async {
    try {
      await themeViewModel.setStyle(style);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('테마 설정을 저장하지 못했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        '화면 스타일',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        '나에게 편한 분위기를 골라보세요.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      ...AppThemeStyle.values.map(
        (style) => _ThemeOption(
          style: style,
          selected: themeViewModel.style == style,
          onTap: () => _selectTheme(context, style),
        ),
      ),
      const SizedBox(height: 16),
      const Divider(),
      const ListTile(
        leading: Icon(Icons.notifications_outlined),
        title: Text('소비기한 알림'),
        subtitle: Text('3일 전 · 당일'),
        trailing: Icon(Icons.chevron_right),
      ),
      const Divider(),
      const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('앱 정보'),
        subtitle: Text('뭐있지 1.0.0'),
      ),
    ],
  );
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final AppThemeStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    color:
        selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color:
            selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: ListTile(
      key: Key('theme-${style.name}'),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: style.seedColor.withValues(alpha: 0.25)),
        ),
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: style.seedColor,
              shape: BoxShape.circle,
              border: Border.all(color: style.accentColor, width: 5),
            ),
          ),
        ),
      ),
      title: Text(
        style.label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(style.description),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color:
            selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
      ),
    ),
  );
}
