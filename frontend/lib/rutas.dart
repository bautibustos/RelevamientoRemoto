import 'package:material_ui/material_ui.dart';

import 'screens/area/areas_screen.dart';
import 'screens/area/cargar_area_screen.dart';
import 'screens/monitor/cargar_monitor_screen.dart';
import 'screens/monitor/monitor_screen.dart';
import 'screens/pc/cargar_pc_screen.dart';
import 'screens/pc/consultar_pc_screen.dart';

/// Módulos disponibles en el menú.
enum Modulo {
  pc('PC', Rutas.pc, Icons.desktop_windows_outlined),
  monitor('Monitor', Rutas.monitor, Icons.monitor_outlined),
  area('Áreas', Rutas.areas, Icons.apartment_outlined);

  const Modulo(this.titulo, this.ruta, this.icono);

  final String titulo;
  final String ruta;
  final IconData icono;
}

abstract final class Rutas {
  static const pc = '/';
  static const pcCargar = '/pc/cargar';
  static const monitor = '/monitor';
  static const monitorCargar = '/monitor/cargar';
  static const areas = '/areas';
  static const areaCargar = '/areas/cargar';
}

Route<dynamic> generarRuta(RouteSettings settings) {
  final Widget pantalla = switch (settings.name) {
    Rutas.pcCargar => const CargarPcScreen(),
    Rutas.monitor => const MonitorScreen(),
    Rutas.monitorCargar => const CargarMonitorScreen(),
    Rutas.areas => const AreasScreen(),
    Rutas.areaCargar => const CargarAreaScreen(),
    _ => const ConsultarPcScreen(),
  };
  return MaterialPageRoute(builder: (_) => pantalla, settings: settings);
}
