import 'package:material_ui/material_ui.dart';

/// Mensaje centrado para los estados "cargando", "error" y "vacío".
class EstadoCarga extends StatelessWidget {
  const EstadoCarga.cargando(this.mensaje, {super.key})
      : cargando = true,
        esError = false,
        onReintentar = null;

  const EstadoCarga.error(this.mensaje, {super.key, required this.onReintentar})
      : cargando = false,
        esError = true;

  const EstadoCarga.vacio(this.mensaje, {super.key})
      : cargando = false,
        esError = false,
        onReintentar = null;

  final String mensaje;
  final bool cargando;
  final bool esError;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cargando) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            if (esError) ...[
              Icon(Icons.cloud_off_outlined, size: 32, color: tema.colorScheme.error),
              const SizedBox(height: 12),
            ],
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
