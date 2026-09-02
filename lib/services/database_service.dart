import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/food_item.dart';

class DatabaseService {
  DatabaseService._({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  static final DatabaseService instance = DatabaseService._();

  final FirebaseFirestore? _firestoreOverride;
  String? _cachedUserId;
  Future<String>? _activeFridgeIdFuture;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  User get _user {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    return user;
  }

  DocumentReference<Map<String, dynamic>> get _userDocument =>
      _firestore.collection('users').doc(_user.uid);

  CollectionReference<Map<String, dynamic>> get _settings =>
      _userDocument.collection('app_settings');

  Future<String> _activeFridgeId() {
    final user = _user;
    if (_cachedUserId != user.uid) {
      _cachedUserId = user.uid;
      _activeFridgeIdFuture = null;
    }
    return _activeFridgeIdFuture ??= _loadOrCreatePersonalFridge(user);
  }

  void invalidateActiveFridge() {
    _activeFridgeIdFuture = null;
  }

  Future<String> _loadOrCreatePersonalFridge(User user) async {
    final userReference = _firestore.collection('users').doc(user.uid);
    final userSnapshot = await userReference.get();
    final savedFridgeId = userSnapshot.data()?['activeFridgeId'];
    if (savedFridgeId is String && savedFridgeId.isNotEmpty) {
      return savedFridgeId;
    }

    final fridgeId = user.uid;
    final fridgeReference = _firestore.collection('fridges').doc(fridgeId);
    final batch = _firestore.batch();
    batch.set(userReference, {
      'activeFridgeId': fridgeId,
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(fridgeReference, {
      'name': '내 냉장고',
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(fridgeReference.collection('members').doc(user.uid), {
      'role': 'owner',
      'displayName': user.displayName,
      'email': user.email,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return fridgeId;
  }

  Future<CollectionReference<Map<String, dynamic>>> _foods() async => _firestore
      .collection('fridges')
      .doc(await _activeFridgeId())
      .collection('foods');

  Future<List<FoodItem>> getFoods() async {
    final snapshot = await (await _foods()).get();
    return snapshot.docs.map(_fromDocument).toList();
  }

  Future<void> insertFood(FoodItem food) async =>
      (await _foods()).doc(food.id.toString()).set(_toMap(food));

  Future<void> insertFoods(List<FoodItem> foods) async {
    if (foods.isEmpty) return;
    final collection = await _foods();
    final batch = _firestore.batch();
    for (final food in foods) {
      batch.set(collection.doc(food.id.toString()), _toMap(food));
    }
    await batch.commit();
  }

  Future<void> updateFood(FoodItem food) async =>
      (await _foods()).doc(food.id.toString()).set(_toMap(food));

  Future<void> deleteFood(int id) async =>
      (await _foods()).doc(id.toString()).delete();

  Future<String?> getSetting(String key) async {
    final snapshot = await _settings.doc(key).get();
    return snapshot.data()?['value'] as String?;
  }

  Future<void> saveSetting(String key, String value) =>
      _settings.doc(key).set({'value': value});

  Map<String, dynamic> _toMap(FoodItem food) => {
    'id': food.id,
    'name': food.name,
    'expiryDate': _timestamp(food.expiryDate),
    'purchaseDate': Timestamp.fromDate(food.purchaseDate),
    'storage': food.storage.name,
    'category': food.category.name,
    'manufactureDate': _timestamp(food.manufactureDate),
    'amountValue': food.amountValue,
    'amountUnit': food.amountUnit.name,
    'status': food.status.name,
    'completedAt': _timestamp(food.completedAt),
    'imageUrl': food.imageUrl,
  };

  FoodItem _fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    return FoodItem(
      id: _intValue(data['id']) ?? int.parse(document.id),
      name: data['name'] as String,
      expiryDate: _dateValue(data['expiryDate']),
      purchaseDate: _dateValue(data['purchaseDate'])!,
      storage: _enumByName(
        StorageType.values,
        data['storage'] as String?,
        StorageType.fridge,
      ),
      category: _enumByName(
        FoodCategory.values,
        data['category'] as String?,
        FoodCategory.other,
      ),
      manufactureDate: _dateValue(data['manufactureDate']),
      amountValue: (data['amountValue'] as num? ?? 1).toDouble(),
      amountUnit: _enumByName(
        FoodUnit.values,
        data['amountUnit'] as String?,
        FoodUnit.piece,
      ),
      status: _enumByName(
        FoodStatus.values,
        data['status'] as String?,
        FoodStatus.stored,
      ),
      completedAt: _dateValue(data['completedAt']),
      imageUrl: data['imageUrl'] as String?,
    );
  }

  Timestamp? _timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);

  DateTime? _dateValue(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
    _ => null,
  };

  int? _intValue(Object? value) => value is num ? value.toInt() : null;

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
