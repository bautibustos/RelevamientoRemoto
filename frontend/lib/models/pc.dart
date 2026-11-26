import 'area.dart';

/// Estado del último relevamiento, tal como lo devuelve la API.
enum EstadoPc {
  pendiente('pendiente', 'Pendiente'),
  ok('ok', 'Relevada'),
  sinRespuesta('sin_respuesta', 'Sin respuesta'),
  error('error', 'Error');

  const EstadoPc(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoPc desde(String? valor) =>
      EstadoPc.values.firstWhere((e) => e.valor == valor, orElse: () => EstadoPc.pendiente);
}

/// Resultado del ping que la API hace al dar de alta una PC.
class ResultadoPing {
  const ResultadoPing({required this.responde, required this.detalle});

  final bool responde;
  final String detalle;

  factory ResultadoPing.fromJson(Map<String, dynamic> json) =>
      ResultadoPing(responde: json['responde'] as bool, detalle: json['detalle'] as String? ?? '');
}

class Disco {
  const Disco({this.modelo, required this.tecnologia, this.bus, this.capacidadGb});

  final String? modelo;
  final String tecnologia;
  final String? bus;
  final double? capacidadGb;

  factory Disco.fromJson(Map<String, dynamic> json) => Disco(
        modelo: json['modelo'] as String?,
        tecnologia: json['tecnologia'] as String,
        bus: json['bus'] as String?,
        capacidadGb: (json['capacidad_gb'] as num?)?.toDouble(),
      );
}

class Pc {
  const Pc({
    required this.id,
    required this.nombre,
    required this.estado,
    this.piso,
    this.area,
    this.red,
    this.usuario,
    this.so,
    this.cpuFamilia,
    this.cpuModelo,
    this.cpuGhz,
    this.placaFabricante,
    this.placaModelo,
    this.video,
    this.ramTipo,
    this.ramTotalGb,
    this.ultimoError,
    this.fechaRelevamiento,
    this.discos = const [],
  });

  final int id;
  final String nombre;
  final EstadoPc estado;
  final String? piso;
  final Area? area;
  final String? red;
  final String? usuario;
  final String? so;
  final String? cpuFamilia;
  final String? cpuModelo;
  final double? cpuGhz;
  final String? placaFabricante;
  final String? placaModelo;
  final String? video;
  final String? ramTipo;
  final int? ramTotalGb;
  final String? ultimoError;
  final String? fechaRelevamiento;
  final List<Disco> discos;

  factory Pc.fromJson(Map<String, dynamic> json) => Pc(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        estado: EstadoPc.desde(json['estado'] as String?),
        piso: json['piso'] as String?,
        area: json['area'] == null ? null : Area.fromJson(json['area'] as Map<String, dynamic>),
        red: json['red'] as String?,
        usuario: json['usuario'] as String?,
        so: json['so'] as String?,
        cpuFamilia: json['cpu_familia'] as String?,
        cpuModelo: json['cpu_modelo'] as String?,
        cpuGhz: (json['cpu_ghz'] as num?)?.toDouble(),
        placaFabricante: json['placa_fabricante'] as String?,
        placaModelo: json['placa_modelo'] as String?,
        video: json['video'] as String?,
        ramTipo: json['ram_tipo'] as String?,
        ramTotalGb: json['ram_total_gb'] as int?,
        ultimoError: json['ultimo_error'] as String?,
        fechaRelevamiento: json['fecha_relevamiento'] as String?,
        discos: [
          for (final d in (json['discos'] as List?) ?? const []) Disco.fromJson(d as Map<String, dynamic>),
        ],
      );
}
