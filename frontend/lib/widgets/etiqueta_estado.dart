import 'package:material_ui/material_ui.dart';

import '../models/pc.dart';
import '../theme.dart';

/// Píldora con el estado del relevamiento.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado({super.key, required this.estado});

  final EstadoPc estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.extension<ColoresEstado>() ?? ColoresEstado.claro;
    final acento = tema.colorScheme.primary;
    final (texto, fondo) = switch (estado) {
      EstadoPc.ok => (c.ok, c.okFondo),
      EstadoPc.sinRespuesta => (c.alerta, c.alertaFondo),
      EstadoPc.error => (c.error, c.errorFondo),
      EstadoPc.pendiente => (c.neutro, c.neutroFondo),
      EstadoPc.relevando => (acento, acento.withValues(alpha: 0.12)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(99)),
      child: Text(
        estado.etiqueta,
        style: TextStyle(color: texto, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
