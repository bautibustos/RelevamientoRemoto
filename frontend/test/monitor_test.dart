import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:inventario_frontend/api/api_client.dart';
import 'package:inventario_frontend/api/api_demo.dart';
import 'package:inventario_frontend/main.dart';
import 'package:inventario_frontend/models/area.dart';

Future<void> _abrirMonitores(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      InventarioApp(api: ApiClient(baseUrl: 'http://demo/api/v1', client: clienteDemo(demora: Duration.zero))));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Abrir menú de módulos'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Monitor'));
  await tester.pumpAndSettle();
}

Future<void> _irACargar(WidgetTester tester) async {
  await tester.tap(find.text('Cargar'));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _elegirArea(WidgetTester tester, String nombre) async {
  await _tocar(tester, find.byType(DropdownButtonFormField<Area>));
  await tester.tap(find.text(nombre).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('El módulo Monitor tiene búsqueda, filtros y botón Cargar', (tester) async {
    await _abrirMonitores(tester);
    expect(find.widgetWithText(AppBar, 'Monitor'), findsOneWidget);
    expect(find.text('3 monitores'), findsOneWidget);
    expect(find.text('Conexión'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Sin PC · [ÁREA 2] · Piso PB'), findsOneWidget);
  });

  testWidgets('Cargar monitor marca los campos obligatorios', (tester) async {
    await _abrirMonitores(tester);
    await _irACargar(tester);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Elegí un área.'), findsOneWidget);
    expect(find.text('Ingresá la marca.'), findsOneWidget);
    expect(find.text('Ingresá el modelo.'), findsOneWidget);
    expect(find.text('Ingresá las pulgadas.'), findsOneWidget);
    expect(find.text('Cargar monitor'), findsOneWidget);
  });

  testWidgets('Cargar monitor completo vuelve a la búsqueda con el monitor nuevo', (tester) async {
    await _abrirMonitores(tester);
    await _irACargar(tester);

    await _elegirArea(tester, '[ÁREA 2]');
    await tester.enterText(find.widgetWithText(TextFormField, 'Marca'), '[MARCA NUEVA]');
    await tester.enterText(find.widgetWithText(TextFormField, 'Modelo'), '[MODELO N]');
    await _tocar(tester, find.widgetWithText(OutlinedButton, '24"'));
    expect(find.widgetWithText(TextFormField, '24'), findsOneWidget);

    await _tocar(tester, find.byTooltip('Agregar HDMI'));
    await _tocar(tester, find.byTooltip('Agregar HDMI'));
    await _tocar(tester, find.byTooltip('Agregar VGA'));

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Monitor [MARCA NUEVA] [MODELO N] guardado.'), findsOneWidget);
    expect(find.text('4 monitores'), findsOneWidget);
    expect(find.text('[MARCA NUEVA] [MODELO N]'), findsOneWidget);

    await tester.tap(find.text('[MARCA NUEVA] [MODELO N]'));
    await tester.pumpAndSettle();
    expect(find.text('VGA, 2 × HDMI'), findsOneWidget);
  });

  testWidgets('Número de serie repetido muestra el error en el campo', (tester) async {
    await _abrirMonitores(tester);
    await _irACargar(tester);
    await _elegirArea(tester, '[ÁREA 1]');
    await tester.enterText(find.widgetWithText(TextFormField, 'Marca'), 'X');
    await tester.enterText(find.widgetWithText(TextFormField, 'Modelo'), 'Y');
    await tester.enterText(find.widgetWithText(TextFormField, 'Pulgadas'), '22');
    await tester.enterText(find.widgetWithText(TextFormField, 'Número de serie (opcional)'), '[serie 1]');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ya existe un monitor con ese número de serie.'), findsOneWidget);
  });

  testWidgets('Elegir la PC completa área y piso', (tester) async {
    await _abrirMonitores(tester);
    await _irACargar(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'PC conectada (opcional)'), '04');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('[EQUIPO 04]'));
    await tester.pumpAndSettle();

    expect(find.text('[ÁREA 2]'), findsOneWidget); // área elegida en el desplegable
    expect(find.widgetWithText(TextFormField, 'PB'), findsOneWidget); // piso completado

    // texto que no corresponde a ninguna PC de la lista
    await tester.enterText(find.widgetWithText(TextFormField, 'PC conectada (opcional)'), 'XYZ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Elegí un equipo de la lista o dejá el campo vacío.'), findsOneWidget);
  });
}
