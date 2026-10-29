import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/auth/data/auth_repository.dart';
import 'package:laundry_app/features/shared/models/app_user.dart';
import 'package:laundry_app/features/shared/widgets/dashboard_widgets.dart';

void main() {
  testWidgets('PanelHeader, acciones y pestañas se dibujan', (tester) async {
    var toques = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(const AppUser(
            uid: 'u', nombre: 'Juan Perez', email: 'j@x.com', role: UserRole.repartidor))),
      ],
      child: MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Column(children: [
              const PanelHeader(rol: 'Repartidor', subtitulo: 'x', icono: Icons.two_wheeler),
              const PestanasPanel(tabs: [Tab(text: 'A'), Tab(text: 'B')]),
              FilaAcciones(acciones: [
                AccionRapida(icono: Icons.map, etiqueta: 'Mapa', onTap: () => toques++),
              ]),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hola, Juan 👋'), findsOneWidget);
    await tester.tap(find.text('Mapa'));
    expect(toques, 1);
    expect(resumenCarga({'Camisa': 2, 'Pantalón': 0}, '3.0 kg de ropa regular'),
        '2 Camisa · 3.0 kg de ropa regular');
  });
}
