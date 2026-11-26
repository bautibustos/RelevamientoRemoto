import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:inventario_frontend/api/api_client.dart';
import 'package:inventario_frontend/api/api_demo.dart';
import 'package:inventario_frontend/main.dart';

Future<void> _abrirAreas(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      InventarioApp(api: ApiClient(baseUrl: 'http://demo/api/v1', client: clienteDemo(demora: Duration.zero))));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Abrir menú de módulos'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Áreas'));
  await tester.pumpAndSettle();
}

Future<void> _agregar(WidgetTester tester, String nombre) async {
  await tester.tap(find.text('Agregar'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Nombre Área'), nombre);
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Áreas muestra la búsqueda sin filtros, las cantidades y el botón Agregar', (tester) async {
    await _abrirAreas(tester);
    expect(find.widgetWithText(AppBar, 'Áreas'), findsOneWidget);
    expect(find.text('2 áreas'), findsOneWidget);
    expect(find.text('3 PCs · 2 monitores'), findsOneWidget); // [ÁREA 1]
    expect(find.text('2 PCs · 1 monitor'), findsOneWidget); // [ÁREA 2]
    expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    expect(find.widgetWithText(FloatingActionButton, 'Agregar'), findsOneWidget);
  });

  testWidgets('La búsqueda filtra por nombre', (tester) async {
    await _abrirAreas(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Nombre Área'), 'area 2'); // sin tilde
    await tester.pumpAndSettle();
    expect(find.text('1 área'), findsOneWidget);
    expect(find.text('[ÁREA 2]'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nombre Área'), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No hay áreas que coincidan con la búsqueda.'), findsOneWidget);
  });

  testWidgets('Agregar un área vuelve a la búsqueda con el área nueva', (tester) async {
    await _abrirAreas(tester);
    await _agregar(tester, '  [ÁREA   NUEVA] ');
    expect(find.text('Área [ÁREA NUEVA] agregada.'), findsOneWidget);
    expect(find.text('3 áreas'), findsOneWidget);
    expect(find.text('[ÁREA NUEVA]'), findsOneWidget);
    expect(find.text('0 PCs · 0 monitores'), findsOneWidget);
  });

  testWidgets('Agregar valida vacío y duplicado', (tester) async {
    await _abrirAreas(tester);
    await _agregar(tester, '   ');
    expect(find.text('Ingresá el nombre del área.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre Área'), '[área 1]');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ya existe un área con ese nombre.'), findsOneWidget);
    expect(find.text('Agregar área'), findsOneWidget); // sigue en el formulario
  });
}
