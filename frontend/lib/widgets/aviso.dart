import 'package:material_ui/material_ui.dart';

import '../theme.dart';

enum TipoAviso { ok, alerta }

/// Notificación inferior con ícono y color según el resultado.
void mostrarAviso(BuildContext context, {required String titulo, String? detalle, TipoAviso tipo = TipoAviso.ok}) {
  final tema = Theme.of(context);
  final c = tema.extension<ColoresEstado>() ?? ColoresEstado.claro;
  final (icono, color, fondo) = switch (tipo) {
    TipoAviso.ok => (Icons.check_circle, c.ok, c.okFondo),
    TipoAviso.alerta => (Icons.warning_amber_rounded, c.alerta, c.alertaFondo),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      backgroundColor: fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
                if (detalle != null) ...[
                  const SizedBox(height: 2),
                  Text(detalle, style: TextStyle(color: tema.colorScheme.onSurface, fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ),
    ));
}
