import 'package:material_ui/material_ui.dart';

import '../../api/api_scope.dart';
import '../../models/pc.dart';
import '../../widgets/estado_carga.dart';
import '../../widgets/etiqueta_estado.dart';

/// Abre el detalle de una PC en una hoja inferior. Trae los discos de la API.
Future<void> mostrarDetallePc(BuildContext context, Pc resumen) {
  final api = ApiScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => FutureBuilder<Pc>(
        future: api.pc(resumen.id),
        builder: (context, snapshot) {
          // mientras llega el detalle se muestra lo que ya trajo la lista
          final pc = snapshot.data ?? resumen;
          return _Detalle(
            pc: pc,
            scroll: scroll,
            cargandoDiscos: snapshot.connectionState != ConnectionState.done,
            error: snapshot.hasError ? snapshot.error.toString() : null,
          );
        },
      ),
    ),
  );
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.pc, required this.scroll, required this.cargandoDiscos, this.error});

  final Pc pc;
  final ScrollController scroll;
  final bool cargandoDiscos;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final relevada = pc.fechaRelevamiento != null;
    final cpu = [pc.cpuFamilia, pc.cpuModelo, if (pc.cpuGhz != null) '${pc.cpuGhz} GHz']
        .whereType<String>()
        .join(' · ');
    final ram = [if (pc.ramTotalGb != null) '${pc.ramTotalGb} GB', pc.ramTipo].whereType<String>().join(' ');
    final placa = [pc.placaFabricante, pc.placaModelo].whereType<String>().join(' ');

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(pc.nombre, style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            EtiquetaEstado(estado: pc.estado),
          ],
        ),
        const SizedBox(height: 16),
        _Seccion('Ubicación', [
          ('Área', pc.area?.nombre),
          ('Piso', pc.piso),
          ('Red', pc.red),
        ]),
        if (pc.ultimoError != null) _Seccion('Último error', [('Detalle', pc.ultimoError)]),
        if (!relevada)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Este equipo todavía no fue relevado. El hardware se completa al ejecutar el relevamiento.',
              style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          )
        else ...[
          _Seccion('Sistema', [
            ('Usuario', pc.usuario),
            ('Sistema operativo', pc.so),
            ('Relevado', pc.fechaRelevamiento),
          ]),
          _Seccion('Hardware', [
            ('Procesador', cpu.isEmpty ? null : cpu),
            ('RAM', ram.isEmpty ? null : ram),
            ('Placa madre', placa.isEmpty ? null : placa),
            ('Video', pc.video),
          ]),
          _Seccion('Discos', [
            for (final d in pc.discos)
              (
                d.tecnologia,
                [d.modelo, if (d.capacidadGb != null) '${d.capacidadGb!.toStringAsFixed(0)} GB', d.bus]
                    .whereType<String>()
                    .join(' · ')
              ),
          ]),
          if (cargandoDiscos) const EstadoCarga.cargando('Cargando discos…'),
        ],
        if (error != null)
          Text(error!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo, this.filas);

  final String titulo;
  final List<(String, String?)> filas;

  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo.toUpperCase(),
              style: tema.textTheme.labelMedium?.copyWith(color: secundario, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          for (final (etiqueta, valor) in filas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(etiqueta, style: tema.textTheme.bodyMedium?.copyWith(color: secundario)),
                  ),
                  Expanded(child: Text(valor ?? '—', style: tema.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
