import 'package:material_ui/material_ui.dart';

import '../rutas.dart';

/// Menú lateral para cambiar de módulo.
class MenuModulos extends StatelessWidget {
  const MenuModulos({super.key, required this.actual});

  final Modulo actual;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: Modulo.values.indexOf(actual),
      onDestinationSelected: (indice) {
        final destino = Modulo.values[indice];
        Navigator.of(context).pop(); // cierra el menú
        if (destino != actual) {
          Navigator.of(context).pushNamedAndRemoveUntil(destino.ruta, (_) => false);
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Text('Inventario',
              style: tema.textTheme.titleMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              )),
        ),
        for (final modulo in Modulo.values)
          NavigationDrawerDestination(icon: Icon(modulo.icono), label: Text(modulo.titulo)),
      ],
    );
  }
}
