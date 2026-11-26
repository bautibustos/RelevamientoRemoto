import 'area.dart';

/// Una entrada de video del monitor y cuántas tiene (ej. 2 x HDMI).
class Entrada {
  const Entrada({required this.nombre, this.cantidad = 1});

  final String nombre;
  final int cantidad;

  factory Entrada.fromJson(Map<String, dynamic> json) =>
      Entrada(nombre: json['nombre'] as String, cantidad: json['cantidad'] as int? ?? 1);

  Map<String, dynamic> toJson() => {'nombre': nombre, 'cantidad': cantidad};

  @override
  String toString() => cantidad > 1 ? '$cantidad × $nombre' : nombre;
}

/// Referencia corta a la PC conectada.
class EquipoRef {
  const EquipoRef({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory EquipoRef.fromJson(Map<String, dynamic> json) =>
      EquipoRef(id: json['id'] as int, nombre: json['nombre'] as String);
}

class Monitor {
  const Monitor({
    required this.id,
    this.marca,
    this.modelo,
    this.numeroSerie,
    this.pulgadas,
    this.entradas = const [],
    this.area,
    this.piso,
    this.equipo,
    this.observaciones,
  });

  final int id;
  final String? marca;
  final String? modelo;
  final String? numeroSerie;
  final double? pulgadas;
  final List<Entrada> entradas;
  final Area? area;
  final String? piso;
  final EquipoRef? equipo;
  final String? observaciones;

  String get titulo => [marca, modelo].whereType<String>().join(' ');

  /// 21.5 -> "21,5", 24.0 -> "24"
  String? get pulgadasTexto {
    final p = pulgadas;
    if (p == null) return null;
    final texto = p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString();
    return '${texto.replaceAll('.', ',')}"';
  }

  factory Monitor.fromJson(Map<String, dynamic> json) => Monitor(
        id: json['id'] as int,
        marca: json['marca'] as String?,
        modelo: json['modelo'] as String?,
        numeroSerie: json['numero_serie'] as String?,
        pulgadas: (json['pulgadas'] as num?)?.toDouble(),
        entradas: [
          for (final e in (json['interfaces'] as List?) ?? const []) Entrada.fromJson(e as Map<String, dynamic>),
        ],
        area: json['area'] == null ? null : Area.fromJson(json['area'] as Map<String, dynamic>),
        piso: json['piso'] as String?,
        equipo: json['equipo'] == null ? null : EquipoRef.fromJson(json['equipo'] as Map<String, dynamic>),
        observaciones: json['observaciones'] as String?,
      );
}

/// Filtro de conexión para la búsqueda.
enum Conexion {
  todas('Todas'),
  conPc('Con PC'),
  sinPc('Sin PC');

  const Conexion(this.etiqueta);

  final String etiqueta;
}
