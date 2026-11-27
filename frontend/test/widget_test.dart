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
    {
      'id': 1, 'nombre': 'EQUIPO-EXISTENTE', 'piso': '1', 'area': {'id': 1, 'nombre': 'AREA 1'}, 'estado': 'ok',
      'fecha_relevamiento': '2026-11-26', 'ram_tipo': 'DDR4', 'ram_total_gb': 16, 'ram_modulos': 1,
      'memorias': [{'id': 1, 'capacidad_gb': 16, 'mhz': 2133}],
      'discos': [{'id': 1, 'marca': 'Kingston', 'tecnologia': 'SSD', 'bus': 'SATA', 'capacidad_gb': 480}],
    },
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
    if (req.method == 'GET' && ruta == '/monitores') return _json([]);
    final relevar = RegExp(r'^/pc/(\d+)/relevar$').firstMatch(ruta);
    if (relevar != null && req.method == 'POST') {
      final p = pcs.firstWhere((p) => p['id'] == int.parse(relevar.group(1)!));
      p['video'] = 'VIDEO NUEVO';
      return _json({...p, 'relevamiento': {'ok': true, 'detalle': 'Hardware actualizado desde el equipo.'}});
    }
    final idPc = RegExp(r'^/pc/(\d+)$').firstMatch(ruta);
    if (idPc != null) {
      final p = pcs.firstWhere((p) => p['id'] == int.parse(idPc.group(1)!));
      if (req.method == 'PATCH') p.addAll(jsonDecode(req.body) as Map<String, dynamic>);
      return _json(p);
    }
    if (req.method == 'POST' && ruta == '/pc') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (pcs.any((p) => p['nombre'] == body['nombre'])) {
        return _json({'detail': 'Ya existe la PC ${body['nombre']}'}, 409);
      }
      final responde = !(body['nombre'] as String).contains('CAIDO'); // ping simulado
      final nueva = {
        'id': pcs.length + 1, 'nombre': body['nombre'], 'piso': body['piso'],
        'area': {'id': 1, 'nombre': 'AREA 1'}, 'estado': responde ? 'pendiente' : 'sin_respuesta',
      };
      pcs.add(nueva);
      return _json({...nueva, 'ping': {'responde': responde, 'detalle': '-'}}, 201);
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
    expect(find.text('Equipo EQUIPO-NUEVO guardado'), findsOneWidget);
    expect(find.text('Respondió al ping: está en red y listo para relevar.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'PC'), findsOneWidget);
    expect(find.text('EQUIPO-NUEVO'), findsOneWidget); // la lista se actualizó
    expect(find.text('2 equipos'), findsOneWidget);
    final post = api.pedidos.singleWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {'nombre': 'EQUIPO-NUEVO', 'area_id': 1, 'piso': '2'}); // sin red: no se envía
  });

  testWidgets('Cargar envía la red si se completa', (tester) async {
    final api = await _abrirApp(tester);
    await _irACargar(tester);
    await _completar(tester, nombre: 'equipo-red');
    await tester.enterText(find.widgetWithText(TextFormField, 'Red (opcional)'), ' [RED 1] ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final post = api.pedidos.singleWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {'nombre': 'EQUIPO-RED', 'area_id': 1, 'piso': '2', 'red': '[RED 1]'});
  });

  testWidgets('Si la PC no responde al ping, avisa con una alerta', (tester) async {
    await _abrirApp(tester);
    await _irACargar(tester);
    await _completar(tester, nombre: 'equipo-caido');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Equipo EQUIPO-CAIDO guardado, sin respuesta'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'PC'), findsOneWidget); // igual vuelve a la búsqueda
  });

  testWidgets('El nombre no acepta espacios ni caracteres raros', (tester) async {
    final api = await _abrirApp(tester);
    await _irACargar(tester);
    await _completar(tester, nombre: 'ws 123');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Usá solo letras, números, punto, guion o guion bajo (sin espacios).'), findsOneWidget);
    expect(api.pedidos.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('Desde el detalle se edita la PC y solo se envía lo que cambió', (tester) async {
    final api = await _abrirApp(tester);
    await tester.tap(find.text('EQUIPO-EXISTENTE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('16 GB 2133 MHz'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar PC'), findsOneWidget);
    expect(find.text('Sin cambios'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Piso'), '7');
    await tester.pump();
    expect(find.text('Modificado'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Agregar módulo'), 200,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar módulo'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Módulo 2 · GB'), '4');
    await tester.enterText(find.widgetWithText(TextFormField, 'MHz').last, '2666');
    await tester.pump();
    expect(find.text('2 cambios'), findsOneWidget);
    expect(find.text('Total 20 GB · 2 módulos'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final patch = api.pedidos.singleWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(patch.body), {
      'piso': '7',
      'memorias': [
        {'capacidad_gb': 16.0, 'mhz': 2133},
        {'capacidad_gb': 4.0, 'mhz': 2666},
      ],
    });
    expect(find.text('Equipo EQUIPO-EXISTENTE actualizado'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'PC'), findsOneWidget); // volvió a la lista
  });

  testWidgets('Volver a relevar actualiza el detalle y avisa el resultado', (tester) async {
    final api = await _abrirApp(tester);
    await tester.tap(find.text('EQUIPO-EXISTENTE'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Volver a relevar'));
    await tester.pumpAndSettle();
    expect(api.pedidos.where((r) => r.method == 'POST' && r.url.path.endsWith('/pc/1/relevar')), hasLength(1));
    expect(find.text('Relevamiento completo'), findsOneWidget);
    await tester.dragUntilVisible(find.text('VIDEO NUEVO'), find.byType(ListView).last, const Offset(0, -150));
    expect(find.text('VIDEO NUEVO'), findsOneWidget);
  });

  testWidgets('Salir de la edición con cambios pide confirmación', (tester) async {
    await _abrirApp(tester);
    await tester.tap(find.text('EQUIPO-EXISTENTE'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Red'), 'OTRA');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Descartar').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'PC'), findsOneWidget);
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
