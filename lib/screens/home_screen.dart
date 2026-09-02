import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_theme_style.dart';
import '../models/food_item.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/fridge_invite_service.dart';
import '../services/ocr_service.dart';
import '../viewmodels/fridge_view_model.dart';
import '../viewmodels/theme_view_model.dart';
import '../widgets/empty_state.dart';
import '../widgets/food_card.dart';
import '../widgets/food_icon.dart';
import '../widgets/fridge_overview.dart';
import 'add_food_screen.dart';
import 'receipt_scan_screen.dart';

class MwoitjiHome extends StatefulWidget {
  const MwoitjiHome({super.key, required this.themeViewModel});

  final ThemeViewModel themeViewModel;

  @override
  State<MwoitjiHome> createState() => _MwoitjiHomeState();
}

class _MwoitjiHomeState extends State<MwoitjiHome> {
  late FridgeViewModel _viewModel;
  final _searchController = TextEditingController();
  int _tabIndex = 0;
  bool _showOverview = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _viewModel = FridgeViewModel();
    _viewModel.addListener(_refresh);
    _viewModel.initialize();
  }

  void _refresh() => setState(() {});

  Future<void> _reloadActiveFridge() async {
    _viewModel
      ..removeListener(_refresh)
      ..dispose();
    DatabaseService.instance.invalidateActiveFridge();
    _viewModel = FridgeViewModel()..addListener(_refresh);
    setState(() {});
    await _viewModel.initialize();
  }

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

  Future<void> _openAddOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    '식품 등록 방법',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  key: const Key('openManualFoodEntry'),
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('직접 등록'),
                  subtitle: const Text('식품을 하나씩 자세히 입력해요.'),
                  onTap: () => Navigator.pop(context, 'manual'),
                ),
                ListTile(
                  key: const Key('openReceiptFoodEntry'),
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('영수증으로 한 번에 등록'),
                  subtitle: const Text('영수증에서 여러 상품을 읽어와요.'),
                  onTap: () => Navigator.pop(context, 'receipt'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
    );
    if (!mounted) return;
    if (option == 'manual') {
      await _openAddFood();
    } else if (option == 'receipt') {
      await _openReceiptFoodEntry();
    }
  }

  Future<void> _openReceiptFoodEntry() async {
    final foods = await Navigator.of(context).push<List<FoodItem>>(
      MaterialPageRoute(
        builder: (_) => ReceiptScanScreen(startingId: _viewModel.nextId),
      ),
    );
    if (foods == null || foods.isEmpty || !mounted) return;
    try {
      await _viewModel.addFoods(foods);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('식품 ${foods.length}개를 등록했어요.')));
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
      _SettingsPage(
        themeViewModel: widget.themeViewModel,
        onFridgeChanged: _reloadActiveFridge,
      ),
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
                onPressed: _openAddOptions,
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
    final urgentFoods =
        foods.where((food) {
            final daysLeft = food.daysLeft;
            return daysLeft != null && daysLeft <= 3;
          }).toList()
          ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      children: [
        Material(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('urgentFoodsCard'),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => _StatsFoodListPage(
                          title: '소비기한 임박',
                          foods: urgentFoods,
                          emptyMessage: '소비기한이 임박한 식품이 없어요.',
                          dateLabel: '소비기한',
                          useExpiryDate: true,
                        ),
                  ),
                ),
            child: Padding(
              padding: const EdgeInsets.all(20),
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
                          '소비기한 임박 ${urgentFoods.length}개',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
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
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ],
              ),
            ),
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
                  showCheckmark: false,
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
                      showCheckmark: false,
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
    final now = DateTime.now();
    final completedThisMonth =
        foods.where((food) {
          final completedAt = food.completedAt;
          return completedAt != null &&
              completedAt.year == now.year &&
              completedAt.month == now.month;
        }).toList();
    final consumedFoods =
        completedThisMonth
            .where((food) => food.status == FoodStatus.consumed)
            .toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final discardedFoods =
        completedThisMonth
            .where((food) => food.status == FoodStatus.discarded)
            .toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final discardRate =
        completedThisMonth.isEmpty
            ? 0
            : (discardedFoods.length / completedThisMonth.length * 100).round();
    final expiringSoon =
        foods.where((food) {
            if (food.status != FoodStatus.stored) return false;
            final daysLeft = food.daysLeft;
            return daysLeft != null && daysLeft >= 0 && daysLeft <= 7;
          }).toList()
          ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          '${now.month}월 소비 리포트',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          '이번 달 냉장고 사용 기록을 모았어요.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '다 먹음',
                value: '${consumedFoods.length}개',
                icon: Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.secondaryContainer,
                onTap:
                    () => _openFoodList(
                      context,
                      title: '이번 달 다 먹음',
                      foods: consumedFoods,
                      emptyMessage: '이번 달에 다 먹은 식품이 없어요.',
                      dateLabel: '먹은 날',
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: '버림',
                value: '${discardedFoods.length}개',
                icon: Icons.delete_outline,
                color: Theme.of(context).colorScheme.errorContainer,
                onTap:
                    () => _openFoodList(
                      context,
                      title: '이번 달 버림',
                      foods: discardedFoods,
                      emptyMessage: '이번 달에 버린 식품이 없어요.',
                      dateLabel: '버린 날',
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '폐기율',
                value: '$discardRate%',
                icon: Icons.pie_chart_outline,
                color: Theme.of(context).colorScheme.tertiaryContainer,
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => _WasteRatePage(
                              consumedFoods: consumedFoods,
                              discardedFoods: discardedFoods,
                            ),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: '7일 이내',
                value: '${expiringSoon.length}개',
                icon: Icons.event_busy_outlined,
                color: Theme.of(context).colorScheme.primaryContainer,
                onTap:
                    () => _openFoodList(
                      context,
                      title: '7일 이내 소비기한',
                      foods: expiringSoon,
                      emptyMessage: '7일 안에 소비해야 할 식품이 없어요.',
                      dateLabel: '소비기한',
                      useExpiryDate: true,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openFoodList(
    BuildContext context, {
    required String title,
    required List<FoodItem> foods,
    required String emptyMessage,
    required String dateLabel,
    bool useExpiryDate = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _StatsFoodListPage(
              title: title,
              foods: foods,
              emptyMessage: emptyMessage,
              dateLabel: dateLabel,
              useExpiryDate: useExpiryDate,
            ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: Key('stats-$label'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

class _StatsEmptyCard extends StatelessWidget {
  const _StatsEmptyCard({this.message = '7일 안에 소비해야 할 식품이 없어요.'});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _StatsFoodListPage extends StatelessWidget {
  const _StatsFoodListPage({
    required this.title,
    required this.foods,
    required this.emptyMessage,
    required this.dateLabel,
    required this.useExpiryDate,
  });

  final String title;
  final List<FoodItem> foods;
  final String emptyMessage;
  final String dateLabel;
  final bool useExpiryDate;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body:
        foods.isEmpty
            ? Center(
              child: EmptyState(
                icon: Icons.insights_outlined,
                title: emptyMessage,
                subtitle: '기록이 생기면 이곳에서 확인할 수 있어요.',
              ),
            )
            : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: foods.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder:
                  (_, index) => _StatsFoodTile(
                    food: foods[index],
                    dateLabel: dateLabel,
                    useExpiryDate: useExpiryDate,
                  ),
            ),
  );
}

class _StatsFoodTile extends StatelessWidget {
  const _StatsFoodTile({
    required this.food,
    required this.dateLabel,
    this.useExpiryDate = false,
  });

  final FoodItem food;
  final String dateLabel;
  final bool useExpiryDate;

  @override
  Widget build(BuildContext context) {
    final date = useExpiryDate ? food.expiryDate : food.completedAt;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ListTile(
          leading: FoodIcon(food: food, size: 28),
          title: Text(
            food.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('${food.storage.label} · ${food.amountLabel}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date == null ? '-' : formatDate(date),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WasteRatePage extends StatelessWidget {
  const _WasteRatePage({
    required this.consumedFoods,
    required this.discardedFoods,
  });

  final List<FoodItem> consumedFoods;
  final List<FoodItem> discardedFoods;

  @override
  Widget build(BuildContext context) {
    final total = consumedFoods.length + discardedFoods.length;
    final rate = total == 0 ? 0 : (discardedFoods.length / total * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('이번 달 폐기 현황')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '폐기율',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$rate%',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : discardedFoods.length / total,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 10),
                Text(
                  '완료 $total개 중 다 먹음 ${consumedFoods.length}개 · 버림 ${discardedFoods.length}개',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '버린 식품',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (discardedFoods.isEmpty)
            const _StatsEmptyCard(message: '이번 달에 버린 식품이 없어요.')
          else
            ...discardedFoods.map(
              (food) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _StatsFoodTile(food: food, dateLabel: '버린 날'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.themeViewModel,
    required this.onFridgeChanged,
  });

  final ThemeViewModel themeViewModel;
  final Future<void> Function() onFridgeChanged;

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

  Future<void> _signOut(BuildContext context) async {
    try {
      await AuthService.instance.signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃하지 못했어요.')));
    }
  }

  Future<void> _createInvite(BuildContext context) async {
    try {
      final invite = await FridgeInviteService.instance.createInvite();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('냉장고 초대 코드'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    invite.code,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('24시간 동안 최대 10명이 사용할 수 있어요.'),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: invite.code));
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('초대 코드를 복사했어요.')),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('복사'),
                ),
                FilledButton.icon(
                  key: const Key('shareFridgeInviteButton'),
                  onPressed:
                      () => SharePlus.instance.share(
                        ShareParams(
                          subject: '뭐있지 냉장고 초대',
                          text:
                              '뭐있지 냉장고에 초대했어요.\n앱에서 초대 코드 ${invite.code}를 입력해 주세요.',
                        ),
                      ),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('공유'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('닫기'),
                ),
              ],
            ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('초대 코드를 만들지 못했어요.')));
    }
  }

  Future<void> _joinFridge(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _JoinFridgeDialog(),
    );
    if (code == null || !context.mounted) return;

    try {
      await FridgeInviteService.instance.joinWithCode(code);
      await onFridgeChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공유 냉장고에 참여했어요.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('초대 코드가 올바르지 않거나 만료됐어요.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (Firebase.apps.isNotEmpty &&
          FirebaseAuth.instance.currentUser != null) ...[
        Text(
          '계정',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  FirebaseAuth.instance.currentUser!.photoURL == null
                      ? null
                      : NetworkImage(
                        FirebaseAuth.instance.currentUser!.photoURL!,
                      ),
              child:
                  FirebaseAuth.instance.currentUser!.photoURL == null
                      ? const Icon(Icons.person_outline)
                      : null,
            ),
            title: Text(
              FirebaseAuth.instance.currentUser!.displayName ?? 'Google 사용자',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(FirebaseAuth.instance.currentUser!.email ?? ''),
          ),
        ),
        TextButton.icon(
          key: const Key('signOutButton'),
          onPressed: () => _signOut(context),
          icon: const Icon(Icons.logout),
          label: const Text('로그아웃'),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
      ],
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
      ListTile(
        leading: const Icon(Icons.group_outlined),
        title: const Text('냉장고 공유'),
        subtitle: const Text('가족과 같은 냉장고를 함께 관리해요.'),
        contentPadding: EdgeInsets.zero,
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('joinFridgeButton'),
              onPressed: () => _joinFridge(context),
              icon: const Icon(Icons.key_outlined),
              label: const Text('코드 입력'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              key: const Key('createFridgeInviteButton'),
              onPressed: () => _createInvite(context),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('초대하기'),
            ),
          ),
        ],
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

class _JoinFridgeDialog extends StatefulWidget {
  const _JoinFridgeDialog();

  @override
  State<_JoinFridgeDialog> createState() => _JoinFridgeDialogState();
}

class _JoinFridgeDialogState extends State<_JoinFridgeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) return;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('냉장고 참여'),
    content: TextField(
      key: const Key('fridgeInviteCodeField'),
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      maxLength: 6,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
      ],
      decoration: const InputDecoration(
        labelText: '6자리 초대 코드',
        hintText: '예: AB12CD',
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('confirmJoinFridgeButton'),
        onPressed: _controller.text.trim().length == 6 ? _submit : null,
        child: const Text('참여'),
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
