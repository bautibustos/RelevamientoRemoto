import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:inventario_frontend/api/api_client.dart';
import 'package:inventario_frontend/api/api_demo.dart';
import 'package:inventario_frontend/main.dart';

/// Abre la app contra la API de demo. Devuelve los pedidos que se hicieron.
Future<List<http.BaseRequest>> _abrir(WidgetTester tester, {Size tamano = const Size(390, 844)}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final pedidos = <http.BaseRequest>[];
  final demo = clienteDemo(demora: Duration.zero);
  final cliente = MockClient((req) async {
    pedidos.add(req);
    // MockClient entrega un pedido ya cerrado: se arma una copia para pasárselo a la demo
    final copia = http.Request(req.method, req.url)
      ..headers.addAll(req.headers)
      ..bodyBytes = req.bodyBytes;
    return http.Response.fromStream(await demo.send(copia));
  });
  await tester.pumpWidget(InventarioApp(api: ApiClient(baseUrl: 'http://demo/api/v1', client: cliente)));
  await tester.pumpAndSettle();
  return pedidos;
}

Future<void> _irA(WidgetTester tester, String modulo) async {
  await tester.tap(find.byTooltip('Abrir menú de módulos'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(modulo));
  await tester.pumpAndSettle();
}

Future<void> _verEnDetalle(WidgetTester tester, Finder f) async {
  await tester.dragUntilVisible(f, find.byType(ListView).last, const Offset(0, -150));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('El detalle de la PC muestra los monitores conectados', (tester) async {
    await _abrir(tester);
    await tester.tap(find.text('[EQUIPO 01]'));
    await tester.pumpAndSettle();
    await _verEnDetalle(tester, find.text('MONITORES'));
    expect(find.textContaining('[MARCA] [MODELO A] · S/N [SERIE 1]'), findsOneWidget);
    expect(find.textContaining('[MARCA] [MODELO B]'), findsOneWidget);
  });

  testWidgets('Una PC sin monitores lo dice en el detalle', (tester) async {
    await _abrir(tester);
    await tester.tap(find.text('[EQUIPO 02]'));
    await tester.pumpAndSettle();
    expect(find.text('Sin monitores conectados'), findsOneWidget);
  });

  testWidgets('Probar conexión muestra el resultado del ping y de WMI por separado', (tester) async {
    final pedidos = await _abrir(tester);
    await tester.tap(find.text('[EQUIPO 04]')); // en la demo responde al ping pero no a WMI
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Probar conexión'));
    await tester.pumpAndSettle();
    expect(pedidos.where((r) => r.method == 'POST' && r.url.path.endsWith('/pc/4/probar')), hasLength(1));
    expect(find.text('El equipo no se puede relevar'), findsOneWidget);
    expect(find.text('Respondió al ping.'), findsOneWidget);
    expect(find.text('El servidor RPC no está disponible.'), findsOneWidget);
  });

  testWidgets('Si el ping falla, la prueba no intenta WMI', (tester) async {
    await _abrir(tester);
    await tester.tap(find.text('[EQUIPO 03]')); // sin respuesta
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Probar conexión'));
    await tester.pumpAndSettle();
    expect(find.text('No responde al ping.'), findsOneWidget);
    expect(find.text('No se probó (falló el ping).'), findsOneWidget);
  });

  testWidgets('El detalle del monitor muestra la PC conectada y la abre', (tester) async {
    await _abrir(tester);
    await _irA(tester, 'Monitor');
    await tester.tap(find.text('[MARCA] [MODELO A]'));
    await tester.pumpAndSettle();
    expect(find.text('PC CONECTADA'), findsOneWidget);
    expect(find.text('Tocá para ver el detalle de la PC'), findsOneWidget);
    await tester.tap(find.text('[EQUIPO 01]'));
    await tester.pumpAndSettle();
    // ahora está abierto el detalle de la PC, con su botón de relevar
    expect(find.widgetWithText(OutlinedButton, 'Volver a relevar'), findsOneWidget);
    expect(find.text('Relevada'), findsOneWidget);
  });

  testWidgets('Editar un monitor: se puede desconectar de la PC', (tester) async {
    final pedidos = await _abrir(tester);
    await _irA(tester, 'Monitor');
    await tester.tap(find.text('[MARCA] [MODELO A]'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar monitor'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '[MODELO A]'), findsOneWidget); // viene completo

    await tester.enterText(find.widgetWithText(TextFormField, 'PC conectada (opcional)'), '');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(pedidos.where((r) => r.method == 'PATCH' && r.url.path.endsWith('/monitores/1')), hasLength(1));
    expect(find.text('Sin PC · [ÁREA 1] · Piso 1'), findsOneWidget); // la lista se actualizó
  });

  testWidgets('Editar un área cambia su nombre en la lista', (tester) async {
    await _abrir(tester);
    await _irA(tester, 'Áreas');
    await tester.tap(find.text('[ÁREA 2]'));
    await tester.pumpAndSettle();
    expect(find.text('Editar área'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre Área'), '[ÁREA NUEVA]');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('[ÁREA NUEVA]'), findsOneWidget);
    expect(find.text('[ÁREA 2]'), findsNothing);
  });

  testWidgets('Editar un área con el nombre de otra avisa que ya existe', (tester) async {
    await _abrir(tester);
    await _irA(tester, 'Áreas');
    await tester.tap(find.text('[ÁREA 2]'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre Área'), '[área 1]');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ya existe un área con ese nombre.'), findsOneWidget);
  });

  for (final modulo in ['PC', 'Monitor', 'Áreas']) {
    testWidgets('Arrastrar la lista hacia abajo la actualiza ($modulo)', (tester) async {
      final pedidos = await _abrir(tester);
      if (modulo != 'PC') await _irA(tester, modulo);
      final ruta = {'PC': '/pc', 'Monitor': '/monitores', 'Áreas': '/areas'}[modulo]!;
      int consultas() => pedidos.where((r) => r.method == 'GET' && r.url.path.endsWith(ruta)).length;
      final antes = consultas();
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(consultas(), antes + 1);
    });
  }

  testWidgets('En escritorio el botón Cargar queda junto a la lista, no en el borde de la ventana', (tester) async {
    await _abrir(tester, tamano: const Size(1400, 900));
    final boton = tester.getRect(find.byType(FloatingActionButton));
    final lista = tester.getRect(find.byType(ListView).first);
    expect(boton.right, closeTo(lista.right - 16, 1)); // alineado con las filas (margen de 16)
    expect(boton.right, lessThan(1000));
  });

  testWidgets('En el celular el botón Cargar sigue abajo a la derecha', (tester) async {
    await _abrir(tester);
    final boton = tester.getRect(find.byType(FloatingActionButton));
    expect(boton.right, closeTo(390 - 16, 1));
  });
}
