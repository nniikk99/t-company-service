// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:t_co_service/main.dart';

void main() {
  testWidgets('Service Department App Test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(MyApp());

    // Verify that the app title is displayed
    expect(find.text('T-company service'), findsOneWidget);

    // Verify that the bottom navigation bar is present
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Verify that all three main sections are accessible
    expect(find.text('Оборудование'), findsOneWidget);
    expect(find.text('Запчасти'), findsOneWidget);
    expect(find.text('Вызов инженера'), findsOneWidget);

    // Verify empty equipment list message
    expect(find.text('Нет добавленного оборудования'), findsOneWidget);

    // Test adding new equipment
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Verify add equipment dialog
    expect(find.text('Добавить оборудование'), findsOneWidget);
    expect(find.text('Производитель'), findsOneWidget);

    // Select manufacturer
    await tester.tap(find.text('Производитель'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tennant').first);
    await tester.pumpAndSettle();

    // Verify model selection appears
    expect(find.text('Модель'), findsOneWidget);

    // Select model
    await tester.tap(find.text('Модель'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T1').first);
    await tester.pumpAndSettle();

    // Fill in other fields
    await tester.enterText(
      find.widgetWithText(TextField, 'Адрес'),
      'ул. Тестовая, 1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Контактное лицо'),
      'Иван Иванов',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Телефон'),
      '+7 (999) 123-45-67',
    );

    // Add equipment
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();

    // Verify equipment was added
    expect(find.text('Tennant T1'), findsOneWidget);
    expect(find.text('ул. Тестовая, 1'), findsOneWidget);

    // Test equipment details
    await tester.tap(find.text('Tennant T1'));
    await tester.pumpAndSettle();

    // Verify equipment details page
    expect(find.text('Информация об оборудовании'), findsOneWidget);
    expect(find.text('Производитель:'), findsOneWidget);
    expect(find.text('Модель:'), findsOneWidget);
    expect(find.text('Адрес:'), findsOneWidget);
    expect(find.text('Контактное лицо:'), findsOneWidget);
    expect(find.text('Телефон:'), findsOneWidget);

    // Verify action buttons
    expect(find.text('Заказать запчасти'), findsOneWidget);
    expect(find.text('Вызвать инженера'), findsOneWidget);

    // Go back to main page
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Test navigation to Spare Parts page
    await tester.tap(find.text('Запчасти'));
    await tester.pumpAndSettle();

    // Test navigation to Service Request page
    await tester.tap(find.text('Вызов инженера'));
    await tester.pumpAndSettle();
  });

  testWidgets('Manufacturer Models Test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Open add equipment dialog
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Test Tennant models
    await tester.tap(find.text('Производитель'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tennant').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Модель'));
    await tester.pumpAndSettle();
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('T2'), findsOneWidget);
    expect(find.text('T3-43M'), findsOneWidget);

    // Test Godlee models
    await tester.tap(find.text('Производитель'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Godlee').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Модель'));
    await tester.pumpAndSettle();
    expect(find.text('GT30'), findsOneWidget);
    expect(find.text('GT50 With 50 (mains)'), findsOneWidget);
    expect(find.text('GT50 B50 (BATTERY)'), findsOneWidget);

    // Test IPC models
    await tester.tap(find.text('Производитель'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IPC').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Модель'));
    await tester.pumpAndSettle();
    expect(find.text('CT15B35'), findsOneWidget);
    expect(find.text('CT15C35'), findsOneWidget);
    expect(find.text('CT40B50'), findsOneWidget);

    // Test T-shaped models
    await tester.tap(find.text('Производитель'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T-shaped').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Модель'));
    await tester.pumpAndSettle();
    expect(find.text('TLO1500'), findsOneWidget);
    expect(find.text('T-Mop'), findsOneWidget);
    expect(find.text('T-vac'), findsOneWidget);
  });
}
