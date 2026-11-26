class Area {
  const Area({required this.id, required this.nombre, this.cantidadPc, this.cantidadMonitores});

  final int id;
  final String nombre;

  /// Solo vienen en el listado de áreas (GET /areas).
  final int? cantidadPc;
  final int? cantidadMonitores;

  factory Area.fromJson(Map<String, dynamic> json) => Area(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        cantidadPc: json['cantidad_pc'] as int?,
        cantidadMonitores: json['cantidad_monitores'] as int?,
      );

  @override
  bool operator ==(Object other) => other is Area && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
