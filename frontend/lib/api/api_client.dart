import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/area.dart';
import '../models/monitor.dart';
import '../models/pc.dart';

/// Error devuelto por la API (o por la red) con un mensaje listo para mostrar.
class ApiException implements Exception {
  const ApiException(this.mensaje, {this.status});

  final String mensaje;
  final int? status;

  bool get esDuplicado => status == 409;

  @override
  String toString() => mensaje;
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<List<Area>> areas() async {
    final datos = await _get('/areas') as List;
    return [for (final a in datos) Area.fromJson(a as Map<String, dynamic>)];
  }

  Future<Area> crearArea(String nombre) async {
    final datos = await _enviar(
      () => _http.post(
        _uri('/areas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre}),
      ),
    );
    return Area.fromJson(datos as Map<String, dynamic>);
  }

  Future<List<Pc>> pcs({String? nombre, int? areaId, EstadoPc? estado}) async {
    final datos = await _get('/pc', {
      if (nombre != null && nombre.trim().isNotEmpty) 'q': nombre.trim(),
      if (areaId != null) 'area_id': '$areaId',
      if (estado != null) 'estado': estado.valor,
    }) as List;
    return [for (final p in datos) Pc.fromJson(p as Map<String, dynamic>)];
  }

  Future<Pc> pc(int id) async => Pc.fromJson(await _get('/pc/$id') as Map<String, dynamic>);

  /// Da de alta la PC. La API le hace un ping y devuelve el resultado junto con la PC.
  Future<(Pc, ResultadoPing?)> crearPc({required String nombre, required int areaId, required String piso}) async {
    final datos = await _enviar(
      () => _http.post(
        _uri('/pc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre, 'area_id': areaId, 'piso': piso}),
      ),
    ) as Map<String, dynamic>;
    final ping = datos['ping'];
    return (Pc.fromJson(datos), ping is Map<String, dynamic> ? ResultadoPing.fromJson(ping) : null);
  }

  // ------------------------------------------------------------------ monitores
  Future<List<String>> interfaces() async {
    final datos = await _get('/interfaces') as List;
    return [for (final i in datos) (i as Map<String, dynamic>)['nombre'] as String];
  }

  Future<List<Monitor>> monitores({String? texto, int? areaId, Conexion conexion = Conexion.todas}) async {
    final datos = await _get('/monitores', {
      if (texto != null && texto.trim().isNotEmpty) 'q': texto.trim(),
      if (areaId != null) 'area_id': '$areaId',
      if (conexion == Conexion.conPc) 'sin_pc': 'false',
      if (conexion == Conexion.sinPc) 'sin_pc': 'true',
    }) as List;
    return [for (final m in datos) Monitor.fromJson(m as Map<String, dynamic>)];
  }

  Future<Monitor> crearMonitor({
    required String marca,
    required String modelo,
    required double pulgadas,
    required int areaId,
    String? piso,
    String? numeroSerie,
    int? equipoId,
    List<Entrada> entradas = const [],
    String? observaciones,
  }) async {
    final datos = await _enviar(
      () => _http.post(
        _uri('/monitores'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'marca': marca,
          'modelo': modelo,
          'pulgadas': pulgadas,
          'area_id': areaId,
          'piso': ?piso,
          'numero_serie': ?numeroSerie,
          'equipo_id': ?equipoId,
          'interfaces': [for (final e in entradas) e.toJson()],
          'observaciones': ?observaciones,
        }),
      ),
    );
    return Monitor.fromJson(datos as Map<String, dynamic>);
  }

  // ------------------------------------------------------------------ interno
  Uri _uri(String ruta, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$ruta');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Future<dynamic> _get(String ruta, [Map<String, String>? query]) =>
      _enviar(() => _http.get(_uri(ruta, query)));

  Future<dynamic> _enviar(Future<http.Response> Function() pedido) async {
    final http.Response respuesta;
    try {
      respuesta = await pedido();
    } on http.ClientException {
      throw ApiException('No se pudo conectar con la API en $baseUrl. Verificá que esté en ejecución.');
    }

    final cuerpo = respuesta.body.isEmpty ? null : jsonDecode(utf8.decode(respuesta.bodyBytes));
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return cuerpo;
    throw ApiException(_mensajeDeError(cuerpo, respuesta.statusCode), status: respuesta.statusCode);
  }

  static String _mensajeDeError(dynamic cuerpo, int status) {
    final detalle = cuerpo is Map ? cuerpo['detail'] : null;
    if (detalle is String) return detalle;
    if (detalle is List && detalle.isNotEmpty && detalle.first is Map) {
      return (detalle.first as Map)['msg']?.toString() ?? 'Datos inválidos.';
    }
    return 'La API respondió con un error ($status).';
  }
}
