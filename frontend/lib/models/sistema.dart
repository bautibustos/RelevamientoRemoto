/// Estado del sistema (GET /sistema): modo de la API y validadores de adentro de la red.
class EstadoSistema {
  const EstadoSistema({
    required this.modo,
    required this.validadores,
    required this.pendientes,
    required this.relevando,
  });

  /// "normal": la API releva. "carga": la API solo guarda y releva un validador.
  final String modo;
  final List<ValidadorSistema> validadores;
  final int pendientes;
  final int relevando;

  bool get modoCarga => modo == 'carga';
  bool get hayValidadorActivo => validadores.any((v) => v.activo);

  factory EstadoSistema.fromJson(Map<String, dynamic> json) {
    final cola = (json['cola'] as Map<String, dynamic>?) ?? const {};
    return EstadoSistema(
      modo: json['modo'] as String? ?? 'normal',
      validadores: [
        for (final v in (json['validadores'] as List?) ?? const [])
          ValidadorSistema.fromJson(v as Map<String, dynamic>),
      ],
      pendientes: cola['pendientes'] as int? ?? 0,
      relevando: cola['relevando'] as int? ?? 0,
    );
  }
}

class ValidadorSistema {
  const ValidadorSistema({required this.nombre, required this.ultimoLatido, required this.activo, this.equipoActual});

  final String nombre;
  final String ultimoLatido;
  final bool activo;
  final String? equipoActual;

  factory ValidadorSistema.fromJson(Map<String, dynamic> json) => ValidadorSistema(
        nombre: json['nombre'] as String,
        ultimoLatido: json['ultimo_latido'] as String,
        activo: json['activo'] as bool? ?? false,
        equipoActual: json['equipo_actual'] as String?,
      );
}
