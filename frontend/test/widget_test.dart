import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:inventario_frontend/api/api_client.dart';
import 'package:inventario_frontend/main.dart';
import 'package:inventario_frontend/models/area.dart';

/// API falsa en memoria: [AREA 1] y un equipo existente.
class ApiFalsa {
  final pcs = <Map<String, dynamic>>[
    {'id': 1, 'nombre': 'EQUIPO-EXISTENTE', 'piso': '1', 'area': {'id': 1, 'nombre': 'AREA 1'}, 'estado': 'pendiente'},
  ];
  final pedidos = <http.Request>[];

  late final client = MockClient((req) async {
    pedidos.add(req);
    final ruta = req.url.path.replaceFirst('/api/v1', '');
    if (req.method == 'GET' && ruta == '/areas') {
      return _json([{'id': 1, 'nombre': 'AREA 1'}]);
    }
    if (req.method == 'GET' && ruta == '/pc') {
      final q = req.url.queryParameters['q']?.toUpperCase() ?? '';
      return _json(pcs.where((p) => (p['nombre'] as String).contains(q)).toList());
    }
    if (req.method == 'POST' && ruta == '/pc') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (pcs.any((p) => p['nombre'] == body['nombre'])) {
        return _json({'detail': 'Ya existe la PC ${body['nombre']}'}, 409);
      }
      final nueva = {
        'id': pcs.length + 1, 'nombre': body['nombre'], 'piso': body['piso'],
        'area': {'id': 1, 'nombre': 'AREA 1'}, 'estado': 'pendiente',
      };
      pcs.add(nueva);
      return _json(nueva, 201);
    }
    return _json({'detail': 'no encontrado'}, 404);
  });

  static http.Response _json(Object cuerpo, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(cuerpo)), status, headers: {'content-type': 'application/json'});
}

Future<ApiFalsa> _abrirApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = ApiFalsa();
  await tester.pumpWidget(InventarioApp(api: ApiClient(baseUrl: 'http://api/api/v1', client: api.client)));
  await tester.pumpAndSettle();
  return api;
}

Future<void> _irACargar(WidgetTester tester) async {
  await tester.tap(find.text('Cargar'));
  await tester.pumpAndSettle();
}

Future<void> _completar(WidgetTester tester, {required String nombre}) async {
  await tester.tap(find.byType(DropdownButtonFormField<Area>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('AREA 1').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Piso'), '2');
  await tester.enterText(find.widgetWithText(TextFormField, 'Nombre Equipo'), nombre);
}

void main() {
  testWidgets('El módulo PC abre directo en la búsqueda, con el botón Cargar', (tester) async {
    await _abrirApp(tester);
    expect(find.widgetWithText(AppBar, 'PC'), findsOneWidget);
    expect(find.byTooltip('Abrir menú de módulos'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nombre Equipo'), findsOneWidget);
    expect(find.text('EQUIPO-EXISTENTE'), findsOneWidget);
    expect(find.text('Consultar'), findsNothing);
    expect(tester.getSize(find.byType(FloatingActionButton)).height, greaterThanOrEqualTo(44));

    await tester.tap(find.byTooltip('Abrir menú de módulos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monitor'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Monitor'), findsOneWidget);
  });

  testWidgets('Cargar no deja guardar con el nombre vacío', (tester) async {
    final api = await _abrirApp(tester);
    await _irACargar(tester);
    await _completar(tester, nombre: '   ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá el nombre del equipo.'), findsOneWidget);
    expect(api.pedidos.where((r) => r.method == 'POST'), isEmpty);

    // al corregir el campo, el error desaparece sin volver a pulsar Guardar
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre Equipo'), 'X');
    await tester.pump();
    expect(find.text('Ingresá el nombre del equipo.'), findsNothing);
  });

  testWidgets('Cargar avisa si el nombre ya existe', (tester) async {
    await _abrirApp(tester);
    await _irACargar(tester);
    await _completar(tester, nombre: 'equipo-existente');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ya existe un equipo con ese nombre.'), findsOneWidget);
    expect(find.text('Cargar PC'), findsOneWidget); // sigue en el formulario
  });

  testWidgets('Guardar confirma, vuelve a la búsqueda y muestra el equipo nuevo', (tester) async {
    final api = await _abrirApp(tester);
    await _irACargar(tester);
    await _completar(tester, nombre: 'equipo-nuevo');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Equipo EQUIPO-NUEVO guardado.'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'PC'), findsOneWidget);
    expect(find.text('EQUIPO-NUEVO'), findsOneWidget); // la lista se actualizó
    expect(find.text('2 equipos'), findsOneWidget);
    final post = api.pedidos.singleWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {'nombre': 'EQUIPO-NUEVO', 'area_id': 1, 'piso': '2'});
  });

  testWidgets('La búsqueda lista los equipos y filtra por nombre', (tester) async {
    final api = await _abrirApp(tester);
    expect(find.text('EQUIPO-EXISTENTE'), findsOneWidget);
    expect(find.text('1 equipo'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nombre Equipo'), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('No hay equipos que coincidan con la búsqueda.'), findsOneWidget);
    expect(api.pedidos.last.url.queryParameters['q'], 'zzz');
  });
}
