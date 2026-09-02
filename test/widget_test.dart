import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwoitji/main.dart';
import 'package:mwoitji/widgets/fridge_overview.dart';

void main() {
  testWidgets('Google 로그인 화면을 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.byKey(const Key('googleSignInButton')), findsOneWidget);
  });

  testWidgets('설정에서 냉장고 초대 코드를 입력할 수 있다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());

    await tester.tap(find.text('설정'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('joinFridgeButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('joinFridgeButton')));
    await tester.pumpAndSettle();

    expect(find.text('냉장고 참여'), findsOneWidget);
    expect(find.byKey(const Key('fridgeInviteCodeField')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('fridgeInviteCodeField')),
      'AB12CD',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirmJoinFridgeButton')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('처음에는 빈 냉장고와 핵심 탭을 표시한다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());

    expect(find.text('뭐있지'), findsOneWidget);
    expect(find.text('등록된 식품이 없어요'), findsOneWidget);
    expect(find.text('우유'), findsNothing);
    expect(find.text('냉장고'), findsOneWidget);
    expect(find.text('통계'), findsOneWidget);
  });

  testWidgets('앱바 검색 아이콘으로 식품 검색을 열고 닫는다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());

    await tester.tap(find.byKey(const Key('openFoodSearchButton')));
    await tester.pump();

    expect(find.byKey(const Key('appBarFoodSearchField')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('appBarFoodSearchField')),
      '우유',
    );
    await tester.tap(find.byKey(const Key('closeFoodSearchButton')));
    await tester.pump();

    expect(find.byKey(const Key('appBarFoodSearchField')), findsNothing);
    expect(find.text('뭐있지'), findsOneWidget);
  });

  testWidgets('통계 탭에 이번 달 핵심 지표를 표시한다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());

    await tester.tap(find.text('통계'));
    await tester.pump();

    expect(find.textContaining('월 소비 리포트'), findsOneWidget);
    expect(find.text('다 먹음'), findsOneWidget);
    expect(find.text('버림'), findsOneWidget);
    expect(find.text('폐기율'), findsOneWidget);
    expect(find.text('7일 이내'), findsOneWidget);
    expect(find.text('곧 소비해야 해요'), findsNothing);

    await tester.tap(find.byKey(const Key('stats-다 먹음')));
    await tester.pumpAndSettle();

    expect(find.text('이번 달 다 먹음'), findsOneWidget);
    expect(find.text('이번 달에 다 먹은 식품이 없어요.'), findsOneWidget);
  });

  testWidgets('홈의 소비기한 임박 카드를 누르면 임박 목록을 연다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());

    await tester.tap(find.byKey(const Key('urgentFoodsCard')));
    await tester.pumpAndSettle();

    expect(find.text('소비기한 임박'), findsOneWidget);
    expect(find.text('소비기한이 임박한 식품이 없어요.'), findsOneWidget);
  });

  testWidgets('식품 등록 화면을 열고 입력값을 검증한다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());
    await tester.tap(find.byKey(const Key('addFoodButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openManualFoodEntry')));
    await tester.pumpAndSettle();

    expect(find.text('식품 등록'), findsOneWidget);
    expect(find.byKey(const Key('foodNameField')), findsOneWidget);
    expect(find.byKey(const Key('ocrButton')), findsOneWidget);
    expect(find.byKey(const Key('foodAmountField')), findsOneWidget);
    expect(find.byKey(const Key('foodUnitField')), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(find.text('식품명을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('식품 등록 버튼에서 영수증 일괄 등록 화면을 연다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());
    await tester.tap(find.byKey(const Key('addFoodButton')));
    await tester.pumpAndSettle();

    expect(find.text('직접 등록'), findsOneWidget);
    expect(find.text('영수증으로 한 번에 등록'), findsOneWidget);
    await tester.tap(find.byKey(const Key('openReceiptFoodEntry')));
    await tester.pumpAndSettle();

    expect(find.text('영수증으로 등록'), findsOneWidget);
    expect(find.byKey(const Key('scanReceiptButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('addReceiptItemButton')));
    await tester.pump();
    expect(find.byKey(const Key('receiptFoodNameField-0')), findsOneWidget);
  });

  testWidgets('수정 화면에 기존 식품 값을 채운다', (tester) async {
    final food = FoodItem(
      id: 1,
      name: '우유',
      expiryDate: DateTime(2026, 9, 15),
      purchaseDate: DateTime(2026, 8, 31),
      storage: StorageType.fridge,
      category: FoodCategory.dairy,
      amountValue: 900,
      amountUnit: FoodUnit.milliliter,
    );
    await tester.pumpWidget(
      MaterialApp(home: AddFoodScreen(id: food.id, initialFood: food)),
    );

    expect(find.text('식품 수정'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('foodNameField')))
          .controller
          ?.text,
      '우유',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('foodAmountField')))
          .controller
          ?.text,
      '900',
    );
  });

  testWidgets('한눈에 보기는 한 칸에 9자리만 보이고 나머지를 목록으로 연다', (tester) async {
    final foods = List.generate(
      11,
      (index) => FoodItem(
        id: index + 1,
        name: '냉동식품 ${index + 1}',
        expiryDate: null,
        purchaseDate: DateTime(2026, 8, 31),
        storage: StorageType.freezer,
        category: FoodCategory.other,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FridgeOverview(
              foods: foods,
              onFoodTap: (_) {},
              onComplete: (_, _) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('+3개'), findsOneWidget);
    expect(find.text('냉동식품 9'), findsNothing);

    await tester.tap(find.byKey(const Key('fridgeOverviewOverflow')));
    await tester.pumpAndSettle();

    expect(find.text('냉동실 11개'), findsOneWidget);
    expect(find.text('냉동식품 11'), findsOneWidget);
  });

  testWidgets('날짜를 YYYYMMDD 숫자로 직접 입력한다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());
    await tester.tap(find.byKey(const Key('addFoodButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openManualFoodEntry')));
    await tester.pumpAndSettle();

    final expiryTile = find.text('소비기한 (선택)');
    await tester.ensureVisible(expiryTile);
    await tester.tap(expiryTile);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dateNumberField')), findsOneWidget);
    expect(find.text('날짜 직접 입력'), findsOneWidget);
    expect(find.text('예: 20260915'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('dateNumberField')))
          .controller
          ?.text,
      isEmpty,
    );

    await tester.enterText(
      find.byKey(const Key('dateNumberField')),
      '20260915',
    );
    await tester.tap(find.byKey(const Key('confirmDateButton')));
    await tester.pumpAndSettle();

    expect(find.text('2026.09.15'), findsOneWidget);
  });

  testWidgets('제조일 입력창에는 오늘 날짜를 기본으로 보여준다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());
    await tester.tap(find.byKey(const Key('addFoodButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openManualFoodEntry')));
    await tester.pumpAndSettle();

    final manufactureTile = find.text('제조일 (선택)');
    await tester.ensureVisible(manufactureTile);
    await tester.tap(manufactureTile);
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final expected =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('dateNumberField')))
          .controller
          ?.text,
      expected,
    );
  });

  testWidgets('구매일 입력창에는 오늘 날짜를 기본으로 보여준다', (tester) async {
    await tester.pumpWidget(const MwoitjiApp());
    await tester.tap(find.byKey(const Key('addFoodButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openManualFoodEntry')));
    await tester.pumpAndSettle();

    final purchaseTile = find.text('구매일');
    await tester.ensureVisible(purchaseTile);
    await tester.tap(purchaseTile);
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final expected =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('dateNumberField')))
          .controller
          ?.text,
      expected,
    );
  });

  test('OCR 텍스트에서 유효한 날짜 후보만 추출한다', () {
    final dates = extractDateCandidates(
      '제조 2026.08.21 소비기한 2026년 09월 15일 잘못된 날짜 2026.13.40',
    );

    expect(dates, [DateTime(2026, 8, 21), DateTime(2026, 9, 15)]);
  });

  test('OCR 텍스트에서 상품명 후보와 안내 문구를 구분한다', () {
    final names = extractProductNameCandidates('''
서울우유
나100%
소비기한 2026.09.15까지
내용량 1000 ml
원재료명 원유 100%
''');

    expect(names, ['서울우유', '나100%']);
  });

  test('영수증 OCR에서 가격과 결제 문구를 제외하고 여러 상품명을 추출한다', () {
    final items = extractReceiptItems('''
이마트 영수증
사업자번호 123-45-67890
1 서울우유 2 5,000
2 친환경 대파 1,980
3 신선한 계란 3 2,300 6,900
결제합계 13,880
2026-09-02 18:30
''');

    expect(items.map((item) => item.name), ['서울우유', '친환경 대파', '신선한 계란']);
    expect(items.map((item) => item.quantity), [2, 1, 3]);
  });

  test('소비기한 없는 식품을 표현할 수 있다', () {
    final food = FoodItem(
      id: 10,
      name: '소금',
      expiryDate: null,
      purchaseDate: DateTime(2026, 8, 31),
      storage: StorageType.room,
      category: FoodCategory.seasoning,
    );

    expect(food.expiryDate, isNull);
    expect(food.daysLeft, isNull);
  });

  test('식품의 보유량과 단위를 표현할 수 있다', () {
    final meat = FoodItem(
      id: 11,
      name: '삼겹살',
      expiryDate: null,
      purchaseDate: DateTime(2026, 8, 31),
      storage: StorageType.fridge,
      category: FoodCategory.meatSeafood,
      amountValue: 1.5,
      amountUnit: FoodUnit.kilogram,
    );

    expect(meat.amountLabel, '1.5 kg');
    expect(recommendedUnitFor(FoodCategory.meatSeafood), FoodUnit.gram);
    expect(recommendedUnitFor(FoodCategory.beverage), FoodUnit.milliliter);
  });

  test('먹은 양만큼 보유량을 줄이고 전부 먹으면 완료 처리한다', () {
    final food = FoodItem(
      id: 12,
      name: '삼겹살',
      expiryDate: null,
      purchaseDate: DateTime(2026, 8, 31),
      storage: StorageType.fridge,
      category: FoodCategory.meatSeafood,
      amountValue: 600,
      amountUnit: FoodUnit.gram,
    );

    final partiallyConsumed = food.useAmount(200);
    expect(partiallyConsumed.amountValue, 400);
    expect(partiallyConsumed.status, FoodStatus.stored);

    final consumedAt = DateTime(2026, 9, 1);
    final fullyConsumed = food.useAmount(600, usedAt: consumedAt);
    expect(fullyConsumed.amountValue, 0);
    expect(fullyConsumed.status, FoodStatus.consumed);
    expect(fullyConsumed.completedAt, consumedAt);
  });

  test('식품 이미지 주소를 보유량 변경 후에도 유지한다', () {
    final food = FoodItem(
      id: 20,
      name: '우유',
      expiryDate: DateTime(2026, 9, 15),
      purchaseDate: DateTime(2026, 9, 1),
      storage: StorageType.fridge,
      category: FoodCategory.dairy,
      amountValue: 1000,
      amountUnit: FoodUnit.milliliter,
      imageUrl: 'https://example.com/foods/milk.jpg',
    );

    expect(food.useAmount(200).imageUrl, food.imageUrl);
  });

  test('테마 기본값은 프레시이고 스타일별 색상이 다르다', () {
    expect(AppThemeStyle.fromName(null), AppThemeStyle.fresh);
    expect(AppThemeStyle.fromName('unknown'), AppThemeStyle.fresh);
    expect(
      buildAppTheme(AppThemeStyle.fresh).colorScheme.primary,
      isNot(buildAppTheme(AppThemeStyle.minimal).colorScheme.primary),
    );
  });
}
