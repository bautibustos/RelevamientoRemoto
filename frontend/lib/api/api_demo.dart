import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// API simulada en memoria para mostrar la app sin servidor (compilar con --dart-define=DEMO=true).
/// Usa solo datos de ejemplo marcados entre corchetes; nada es inventario real.
http.Client clienteDemo({Duration demora = const Duration(milliseconds: 250)}) {
  final areas = [
    {'id': 1, 'nombre': '[ÁREA 1]'},
    {'id': 2, 'nombre': '[ÁREA 2]'},
  ];
  Map<String, dynamic> pc(int id, String nombre, int area, String piso, String estado, {bool relevada = false}) => {
        'id': id,
        'nombre': nombre,
        'piso': piso,
        'area': areas[area - 1],
        'red': '[RED]',
        'estado': estado,
        'ultimo_error': estado == 'error' ? '[DETALLE DEL ERROR]' : null,
        'fecha_relevamiento': relevada ? '[FECHA RELEVAMIENTO]' : null,
        'so': relevada ? '[SISTEMA OPERATIVO]' : null,
        'usuario': relevada ? '[USUARIO]' : null,
        'cpu_familia': relevada ? '[PROCESADOR]' : null,
        'cpu_modelo': relevada ? '[MODELO]' : null,
        'placa_fabricante': relevada ? '[PLACA MADRE]' : null,
        'video': relevada ? '[VIDEO]' : null,
        'ram_tipo': relevada ? '[DDR]' : null,
        'ram_total_gb': relevada ? 20 : null,
        'ram_modulos': relevada ? 2 : 0,
        'memorias': relevada
            ? [
                {'id': id * 10 + 1, 'capacidad_gb': 16, 'mhz': 2666},
                {'id': id * 10 + 2, 'capacidad_gb': 4, 'mhz': 2133},
              ]
            : [],
        'discos': relevada
            ? [
                {'id': id, 'marca': '[MARCA DISCO]', 'tecnologia': 'SSD', 'bus': 'SATA', 'capacidad_gb': 480.0},
              ]
            : [],
      };

  final pcs = [
    pc(1, '[EQUIPO 01]', 1, '1', 'ok', relevada: true),
    pc(2, '[EQUIPO 02]', 1, '1', 'pendiente'),
    pc(3, '[EQUIPO 03]', 1, '2', 'sin_respuesta'),
    pc(4, '[EQUIPO 04]', 2, 'PB', 'error'),
    pc(5, '[EQUIPO 05]', 2, 'PB', 'pendiente'),
  ];

  const interfaces = ['VGA', 'DVI', 'HDMI', 'DisplayPort', 'Mini DisplayPort', 'USB-C'];
  Map<String, dynamic>? refPc(int? id) {
    if (id == null) return null;
    final p = pcs.where((p) => p['id'] == id).firstOrNull;
    return p == null ? null : {'id': p['id'], 'nombre': p['nombre']};
  }

  final monitores = <Map<String, dynamic>>[
    {
      'id': 1, 'marca': '[MARCA]', 'modelo': '[MODELO A]', 'numero_serie': '[SERIE 1]', 'pulgadas': 21.5,
      'interfaces': [{'nombre': 'VGA', 'cantidad': 1}, {'nombre': 'HDMI', 'cantidad': 1}],
      'area': areas[0], 'piso': '1', 'equipo': refPc(1), 'observaciones': null,
    },
    {
      'id': 2, 'marca': '[MARCA]', 'modelo': '[MODELO B]', 'numero_serie': null, 'pulgadas': 24.0,
      'interfaces': [{'nombre': 'HDMI', 'cantidad': 2}],
      'area': areas[0], 'piso': '1', 'equipo': refPc(1), 'observaciones': null,
    },
    {
      'id': 3, 'marca': '[MARCA]', 'modelo': '[MODELO C]', 'numero_serie': '[SERIE 3]', 'pulgadas': 19.0,
      'interfaces': [{'nombre': 'VGA', 'cantidad': 1}],
      'area': areas[1], 'piso': 'PB', 'equipo': null, 'observaciones': '[OBSERVACIONES]',
    },
  ];

  http.Response json(Object cuerpo, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(cuerpo)), status, headers: {'content-type': 'application/json'});

  return MockClient((req) async {
    if (demora > Duration.zero) await Future<void>.delayed(demora); // simula la red
    final ruta = req.url.path.replaceFirst(RegExp(r'^.*/api/v1'), '');

    if (req.method == 'GET' && ruta == '/areas') {
      final ordenadas = [...areas]..sort((a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));
      return json([
        for (final a in ordenadas)
          {
            ...a,
            'cantidad_pc': pcs.where((p) => (p['area'] as Map)['id'] == a['id']).length,
            'cantidad_monitores': monitores.where((m) => (m['area'] as Map)['id'] == a['id']).length,
          },
      ]);
    }

    if (req.method == 'POST' && ruta == '/areas') {
      final nombre = ((jsonDecode(req.body) as Map)['nombre'] as String).trim();
      if (areas.any((a) => (a['nombre'] as String).toLowerCase() == nombre.toLowerCase())) {
        return json({'detail': 'Ya existe el área "$nombre"'}, 409);
      }
      final nueva = {'id': areas.length + 1, 'nombre': nombre};
      areas.add(nueva);
      return json(nueva, 201);
    }

    if (req.method == 'GET' && ruta == '/pc') {
      final q = (req.url.queryParameters['q'] ?? '').toUpperCase();
      final areaId = int.tryParse(req.url.queryParameters['area_id'] ?? '');
      final estado = req.url.queryParameters['estado'];
      return json(pcs
          .where((p) => (p['nombre'] as String).toUpperCase().contains(q))
          .where((p) => areaId == null || (p['area'] as Map)['id'] == areaId)
          .where((p) => estado == null || p['estado'] == estado)
          .toList());
    }

    final detalle = RegExp(r'^/pc/(\d+)$').firstMatch(ruta);
    if (req.method == 'GET' && detalle != null) {
      final id = int.parse(detalle.group(1)!);
      final encontrada = pcs.where((p) => p['id'] == id);
      return encontrada.isEmpty ? json({'detail': 'No existe la PC $id'}, 404) : json(encontrada.first);
    }

    final relevar = RegExp(r'^/pc/(\d+)/relevar$').firstMatch(ruta);
    if (req.method == 'POST' && relevar != null) {
      // relevamiento simulado: completa el hardware con datos de ejemplo
      final id = int.parse(relevar.group(1)!);
      final i = pcs.indexWhere((p) => p['id'] == id);
      if (i < 0) return json({'detail': 'No existe la PC $id'}, 404);
      final p = pcs[i];
      final nueva = pc(id, p['nombre'] as String, (p['area'] as Map)['id'] as int, p['piso'] as String, 'ok',
          relevada: true)
        ..['red'] = p['red'];
      pcs[i] = nueva;
      return json({...nueva, 'relevamiento': {'ok': true, 'detalle': 'Hardware actualizado desde el equipo.'}});
    }

    if (req.method == 'PATCH' && detalle != null) {
      final id = int.parse(detalle.group(1)!);
      final p = pcs.where((p) => p['id'] == id).firstOrNull;
      if (p == null) return json({'detail': 'No existe la PC $id'}, 404);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final nombre = body['nombre'] as String?;
      if (nombre != null && pcs.any((o) => o['id'] != id && o['nombre'] == nombre)) {
        return json({'detail': 'Ya existe la PC $nombre'}, 409);
      }
      for (final MapEntry(:key, :value) in body.entries) {
        switch (key) {
          case 'area_id':
            p['area'] = areas.firstWhere((a) => a['id'] == value);
          case 'memorias':
            final lista = [for (final (i, m) in (value as List).indexed) {'id': id * 10 + i, ...(m as Map)}];
            p['memorias'] = lista;
            p['ram_modulos'] = lista.length;
            p['ram_total_gb'] = lista.isEmpty ? null : lista.fold<num>(0, (s, m) => s + (m['capacidad_gb'] as num));
          case 'discos':
            p['discos'] = [for (final (i, d) in (value as List).indexed) {'id': id * 10 + i, ...(d as Map)}];
          default:
            p[key] = value;
        }
      }
      return json(p);
    }

    if (req.method == 'POST' && ruta == '/pc') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final nombre = (body['nombre'] as String).toUpperCase();
      if (pcs.any((p) => p['nombre'] == nombre)) return json({'detail': 'Ya existe la PC $nombre'}, 409);
      // ping simulado: responde si el nombre termina en un número par (ej. EQUIPO-06); si no, no responde
      final ultimo = int.tryParse(nombre.substring(nombre.length - 1));
      final responde = ultimo != null && ultimo.isEven;
      final nueva = pc(pcs.length + 1, nombre, body['area_id'] as int, body['piso'] as String,
          responde ? 'pendiente' : 'sin_respuesta');
      nueva['red'] = body['red'];
      pcs.insert(0, nueva);
      return json({
        ...nueva,
        'ping': {'responde': responde, 'detalle': responde ? 'Respondió al ping.' : 'No responde al ping.'},
      }, 201);
    }

    if (req.method == 'GET' && ruta == '/sistema') {
      return json({
        'modo': 'normal',
        'validador_local': false,
        'validadores': [],
        'cola': {'pendientes': pcs.where((p) => p['estado'] == 'pendiente').length, 'relevando': 0},
      });
    }

    if (req.method == 'GET' && ruta == '/interfaces') {
      return json([for (final (i, n) in interfaces.indexed) {'id': i + 1, 'nombre': n}]);
    }

    if (req.method == 'GET' && ruta == '/monitores') {
      final q = (req.url.queryParameters['q'] ?? '').toUpperCase();
      final areaId = int.tryParse(req.url.queryParameters['area_id'] ?? '');
      final sinPc = req.url.queryParameters['sin_pc'];
      bool coincide(Map<String, dynamic> m) => [m['marca'], m['modelo'], m['numero_serie'], m['equipo']?['nombre']]
          .whereType<String>()
          .any((t) => t.toUpperCase().contains(q));
      return json(monitores
          .where((m) => q.isEmpty || coincide(m))
          .where((m) => areaId == null || (m['area'] as Map)['id'] == areaId)
          .where((m) => sinPc == null || (sinPc == 'true') == (m['equipo'] == null))
          .toList());
    }

    if (req.method == 'POST' && ruta == '/monitores') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final serie = body['numero_serie'] as String?;
      if (serie != null && monitores.any((m) => m['numero_serie'] == serie)) {
        return json({'detail': 'Ya existe un monitor con número de serie $serie'}, 409);
      }
      final nuevo = {
        'id': monitores.length + 1, 'marca': body['marca'], 'modelo': body['modelo'], 'numero_serie': serie,
        'pulgadas': body['pulgadas'], 'interfaces': body['interfaces'] ?? [],
        'area': areas.firstWhere((a) => a['id'] == body['area_id']), 'piso': body['piso'],
        'equipo': refPc(body['equipo_id'] as int?), 'observaciones': body['observaciones'],
      };
      monitores.insert(0, nuevo);
      return json(nuevo, 201);
    }

    return json({'detail': 'No encontrado'}, 404);
  });
}
