import 'area.dart';

/// Estado del último relevamiento, tal como lo devuelve la API.
enum EstadoPc {
  pendiente('pendiente', 'Pendiente'),
  relevando('relevando', 'Relevando'),
  ok('ok', 'Relevada'),
  sinRespuesta('sin_respuesta', 'Sin respuesta'),
  error('error', 'Error');

  const EstadoPc(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  /// El relevamiento todavía no terminó (en cola del validador o en curso).
  bool get enCurso => this == pendiente || this == relevando;

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

/// Formatea GB sin decimales de más: 16.0 -> "16", 0.5 -> "0,5".
String gbTexto(double gb) =>
    gb == gb.roundToDouble() ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1).replaceAll('.', ',');

/// Un módulo de RAM: capacidad y velocidad propias (una PC puede tener 16 GB a 2666 + 4 GB a 2133).
/// Resultado de volver a relevar una PC (POST /pc/{id}/relevar).
class ResultadoRelevamiento {
  const ResultadoRelevamiento({required this.ok, required this.detalle, this.enCola = false});

  final bool ok;
  final String detalle;

  /// Modo "carga": la PC quedó en cola y la releva el validador de adentro de la red.
  final bool enCola;

  factory ResultadoRelevamiento.fromJson(Map<String, dynamic> json) => ResultadoRelevamiento(
        ok: json['ok'] as bool,
        detalle: json['detalle'] as String? ?? '',
        enCola: json['en_cola'] as bool? ?? false,
      );
}

/// Una parte de la prueba de conexión (ping o WMI).
class PasoPrueba {
  const PasoPrueba({required this.ok, required this.detalle});

  final bool ok;
  final String detalle;

  factory PasoPrueba.fromJson(Map<String, dynamic> json) =>
      PasoPrueba(ok: json['ok'] as bool, detalle: json['detalle'] as String? ?? '');
}

/// Resultado de probar la conexión (POST /pc/{id}/probar). [wmi] es null si el ping falló.
class PruebaConexion {
  const PruebaConexion({required this.ping, this.wmi});

  final PasoPrueba ping;
  final PasoPrueba? wmi;

  bool get ok => ping.ok && (wmi?.ok ?? false);

  factory PruebaConexion.fromJson(Map<String, dynamic> json) => PruebaConexion(
        ping: PasoPrueba.fromJson(json['ping'] as Map<String, dynamic>),
        wmi: json['wmi'] == null ? null : PasoPrueba.fromJson(json['wmi'] as Map<String, dynamic>),
      );
}

class Memoria {
  const Memoria({required this.capacidadGb, this.mhz});

  final double capacidadGb;
  final int? mhz;

  String get texto => [ '${gbTexto(capacidadGb)} GB', if (mhz != null) '$mhz MHz'].join(' ');

  Map<String, dynamic> toJson() => {'capacidad_gb': capacidadGb, 'mhz': mhz};

  factory Memoria.fromJson(Map<String, dynamic> json) =>
      Memoria(capacidadGb: (json['capacidad_gb'] as num).toDouble(), mhz: json['mhz'] as int?);
}

class Disco {
  const Disco({this.marca, required this.tecnologia, this.bus, this.capacidadGb});

  final String? marca;
  final String tecnologia;
  final String? bus;
  final double? capacidadGb;

  Map<String, dynamic> toJson() =>
      {'marca': marca, 'tecnologia': tecnologia, 'bus': bus, 'capacidad_gb': capacidadGb};

  factory Disco.fromJson(Map<String, dynamic> json) => Disco(
        marca: json['marca'] as String?,
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
    this.relevandoPor,
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
    this.memorias = const [],
    this.ultimoError,
    this.fechaRelevamiento,
    this.discos = const [],
  });

  final int id;
  final String nombre;
  final EstadoPc estado;

  /// Validador que la está relevando (solo con estado "relevando").
  final String? relevandoPor;
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
  final double? ramTotalGb;

  /// Módulos de RAM con su capacidad y MHz. Solo viene en el detalle.
  final List<Memoria> memorias;
  final String? ultimoError;
  final String? fechaRelevamiento;
  final List<Disco> discos;

  factory Pc.fromJson(Map<String, dynamic> json) => Pc(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        estado: EstadoPc.desde(json['estado'] as String?),
        relevandoPor: json['relevando_por'] as String?,
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
        ramTotalGb: (json['ram_total_gb'] as num?)?.toDouble(),
        memorias: [
          for (final m in (json['memorias'] as List?) ?? const []) Memoria.fromJson(m as Map<String, dynamic>),
        ],
        ultimoError: json['ultimo_error'] as String?,
        fechaRelevamiento: json['fecha_relevamiento'] as String?,
        discos: [
          for (final d in (json['discos'] as List?) ?? const []) Disco.fromJson(d as Map<String, dynamic>),
        ],
      );
}
