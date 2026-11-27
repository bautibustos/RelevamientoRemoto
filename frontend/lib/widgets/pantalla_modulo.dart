import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../rutas.dart';
import 'menu_modulos.dart';

/// Estructura común de cada módulo: encabezado con menú y título, contenido
/// (la búsqueda) y el botón flotante "Cargar".
class PantallaModulo extends StatelessWidget {
  /// Ancho máximo de la columna de contenido (filtros y lista).
  static const anchoContenido = 560.0;

  const PantallaModulo({
    super.key,
    required this.modulo,
    required this.onCargar,
    required this.child,
    this.textoAccion = 'Cargar',
  });

  final Modulo modulo;
  final VoidCallback onCargar;
  final Widget child;
  final String textoAccion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Abrir menú de módulos',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(modulo.titulo),
      ),
      drawer: MenuModulos(actual: modulo),
      floatingActionButtonLocation: const _BotonJuntoALaLista(anchoContenido),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCargar,
        icon: const Icon(Icons.add),
        label: Text(textoAccion),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: anchoContenido), child: child),
        ),
      ),
    );
  }
}

/// Como el botón flotante de abajo a la derecha, pero en pantallas anchas queda junto al borde
/// derecho de la columna de contenido en lugar de irse al borde de la ventana.
class _BotonJuntoALaLista extends FloatingActionButtonLocation {
  const _BotonJuntoALaLista(this.anchoContenido);

  final double anchoContenido;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometria) {
    final normal = FloatingActionButtonLocation.endFloat.getOffset(geometria);
    final ancho = geometria.scaffoldSize.width;
    if (ancho <= anchoContenido) return normal;
    // 16 = margen de la lista dentro de la columna
    final bordeLista = (ancho + anchoContenido) / 2 - 16;
    return Offset(math.min(normal.dx, bordeLista - geometria.floatingActionButtonSize.width), normal.dy);
  }

  @override
  String toString() => 'FloatingActionButtonLocation.junto a la lista';
}

/// Fila de resultado: título, subtítulo, una etiqueta a la derecha y la flecha.
class FilaResultado extends StatelessWidget {
  const FilaResultado({super.key, required this.titulo, required this.subtitulo, this.etiqueta, this.onTap});

  final String titulo;
  final String subtitulo;
  final Widget? etiqueta;

  /// Si es null, la fila no se puede tocar y no muestra la flecha.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: tema.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (etiqueta != null) ...[const SizedBox(width: 8), etiqueta!],
                if (onTap != null) Icon(Icons.chevron_right, color: tema.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora neutra (ej. las pulgadas de un monitor).
class Pildora extends StatelessWidget {
  const Pildora(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: esquema.surface,
        border: Border.all(color: esquema.outline),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(texto, style: TextStyle(color: esquema.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
