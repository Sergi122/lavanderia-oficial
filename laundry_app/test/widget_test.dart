import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laundry_app/features/auth/presentation/splash_screen.dart';

void main() {
  testWidgets('Splash screen muestra el nombre de la app', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Lavandería App'), findsOneWidget);
    expect(find.text('Los Asustadores'), findsOneWidget);
  });
}
