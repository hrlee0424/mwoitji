import 'package:cloud_functions/cloud_functions.dart';

class FridgeInvite {
  const FridgeInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

class FridgeInviteService {
  FridgeInviteService._();

  static final FridgeInviteService instance = FridgeInviteService._();

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<FridgeInvite> createInvite() async {
    final result = await _functions.httpsCallable('createFridgeInvite').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return FridgeInvite(
      code: data['code'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] as int),
    );
  }

  Future<String> joinWithCode(String code) async {
    final result = await _functions.httpsCallable('joinFridgeWithCode').call({
      'code': code.trim().toUpperCase(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['fridgeId'] as String;
  }
}
