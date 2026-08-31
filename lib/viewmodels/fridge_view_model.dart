import 'package:flutter/foundation.dart';

import '../models/food_item.dart';
import '../services/database_service.dart';

class FridgeViewModel extends ChangeNotifier {
  FridgeViewModel({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService _databaseService;
  final List<FoodItem> _foods = [];
  int _nextId = 1;
  StorageType? _filter;
  bool _isLoading = false;
  bool _disposed = false;
  String? _persistenceError;

  int get nextId => _nextId;
  StorageType? get filter => _filter;
  bool get isLoading => _isLoading;
  String? get persistenceError => _persistenceError;
  List<FoodItem> get foods => List.unmodifiable(_foods);

  List<FoodItem> get allStoredFoods {
    final result =
        _foods.where((food) => food.status == FoodStatus.stored).toList()
          ..sort((a, b) {
            final aDate = a.expiryDate;
            final bDate = b.expiryDate;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
    return result;
  }

  List<FoodItem> get storedFoods {
    return allStoredFoods
        .where((food) => _filter == null || food.storage == _filter)
        .toList();
  }

  Future<void> initialize() async {
    _isLoading = true;
    _notify();
    try {
      final savedFoods = await _databaseService.getFoods();
      if (_disposed) return;
      _foods
        ..clear()
        ..addAll(savedFoods);
      _nextId =
          _foods.isEmpty
              ? 1
              : _foods.map((food) => food.id).reduce((a, b) => a > b ? a : b) +
                  1;
      _persistenceError = null;
    } catch (_) {
      if (_disposed) return;
      _persistenceError = '저장소를 불러오지 못했어요.';
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void setFilter(StorageType? value) {
    _filter = value;
    _notify();
  }

  Future<void> addFood(FoodItem food) async {
    _foods.add(food);
    _nextId++;
    _notify();
    try {
      await _databaseService.insertFood(food);
      _persistenceError = null;
    } catch (_) {
      _foods.remove(food);
      _nextId--;
      _persistenceError = '식품을 저장하지 못했어요.';
      _notify();
      rethrow;
    }
  }

  Future<void> updateFood(FoodItem food) async {
    final index = _foods.indexWhere((item) => item.id == food.id);
    if (index < 0) return;
    final previous = _foods[index];
    _foods[index] = food;
    _notify();
    try {
      await _databaseService.updateFood(food);
      _persistenceError = null;
    } catch (_) {
      _foods[index] = previous;
      _persistenceError = '식품 정보를 수정하지 못했어요.';
      _notify();
      rethrow;
    }
  }

  Future<FoodItem> consumeAmount(FoodItem food, double amount) async {
    final index = _foods.indexWhere((item) => item.id == food.id);
    if (index < 0) throw StateError('식품을 찾을 수 없어요.');
    final previous = _foods[index];
    final updated = previous.useAmount(amount);
    _foods[index] = updated;
    _notify();
    try {
      await _databaseService.updateFood(updated);
      _persistenceError = null;
      return updated;
    } catch (_) {
      _foods[index] = previous;
      _persistenceError = '사용량을 저장하지 못했어요.';
      _notify();
      rethrow;
    }
  }

  Future<void> completeFood(FoodItem food, FoodStatus status) async {
    final previousStatus = food.status;
    final previousCompletedAt = food.completedAt;
    food.status = status;
    food.completedAt = DateTime.now();
    _notify();
    try {
      await _databaseService.updateFood(food);
      _persistenceError = null;
    } catch (_) {
      food.status = previousStatus;
      food.completedAt = previousCompletedAt;
      _persistenceError = '식품 상태를 저장하지 못했어요.';
      _notify();
      rethrow;
    }
  }

  Future<void> restoreFood(FoodItem food) async {
    final previousStatus = food.status;
    final previousCompletedAt = food.completedAt;
    food.status = FoodStatus.stored;
    food.completedAt = null;
    _notify();
    try {
      await _databaseService.updateFood(food);
      _persistenceError = null;
    } catch (_) {
      food.status = previousStatus;
      food.completedAt = previousCompletedAt;
      _persistenceError = '식품 상태를 되돌리지 못했어요.';
      _notify();
      rethrow;
    }
  }

  Future<void> deleteFood(FoodItem food) async {
    final index = _foods.indexOf(food);
    if (index < 0) return;
    _foods.removeAt(index);
    _notify();
    try {
      await _databaseService.deleteFood(food.id);
      _persistenceError = null;
    } catch (_) {
      _foods.insert(index, food);
      _persistenceError = '식품을 삭제하지 못했어요.';
      _notify();
      rethrow;
    }
  }

  Future<void> restoreDeletedFood(FoodItem food) async {
    if (_foods.any((item) => item.id == food.id)) return;
    _foods.add(food);
    _notify();
    try {
      await _databaseService.insertFood(food);
      _persistenceError = null;
    } catch (_) {
      _foods.remove(food);
      _persistenceError = '삭제한 식품을 복구하지 못했어요.';
      _notify();
      rethrow;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
