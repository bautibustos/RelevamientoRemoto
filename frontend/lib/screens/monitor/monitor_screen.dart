import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/api_scope.dart';
import '../../models/area.dart';
import '../../models/monitor.dart';
import '../../rutas.dart';
import '../../widgets/estado_carga.dart';
import '../../widgets/pantalla_modulo.dart';

/// Pantalla principal del módulo Monitor: búsqueda, filtros y botón Cargar.
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final _busqueda = TextEditingController();
  Timer? _espera;

  List<Area> _areas = const [];
  Area? _area;
  Conexion _conexion = Conexion.todas;

  Future<List<Monitor>>? _resultados;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resultados == null) {
      _buscar();
      ApiScope.of(context).areas().then((a) {
        if (mounted) setState(() => _areas = a);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() {
      _resultados = ApiScope.of(context).monitores(texto: _busqueda.text, areaId: _area?.id, conexion: _conexion);
    });
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 300), _buscar);
    setState(() {});
  }

  Future<void> _cargar() async {
    final guardado = await Navigator.of(context).pushNamed<bool>(Rutas.monitorCargar);
    if (guardado == true && mounted) _buscar();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaModulo(
      modulo: Modulo.monitor,
      onCargar: _cargar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filtros(),
          Expanded(child: _lista(context)),
        ],
      ),
    );
  }

  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _busqueda,
            onChanged: _alEscribir,
            onSubmitted: (_) => _buscar(),
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Buscar monitor',
              hintText: '[MARCA, MODELO O SERIE]',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busqueda.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _busqueda.clear();
                        _buscar();
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Area?>(
                  initialValue: _area,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Área'),
                  items: [
                    const DropdownMenuItem<Area?>(value: null, child: Text('Todas')),
                    for (final a in _areas)
                      DropdownMenuItem<Area?>(value: a, child: Text(a.nombre, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (a) {
                    _area = a;
                    _buscar();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<Conexion>(
                  initialValue: _conexion,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Conexión'),
                  items: [
                    for (final c in Conexion.values) DropdownMenuItem(value: c, child: Text(c.etiqueta)),
                  ],
                  onChanged: (c) {
                    _conexion = c ?? Conexion.todas;
                    _buscar();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lista(BuildContext context) {
    final tema = Theme.of(context);
    return FutureBuilder<List<Monitor>>(
      future: _resultados,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EstadoCarga.error(snapshot.error.toString(), onReintentar: _buscar);
        }
        final monitores = snapshot.data;
        if (monitores == null) return const EstadoCarga.cargando('Buscando monitores…');
        if (monitores.isEmpty) return const EstadoCarga.vacio('No hay monitores que coincidan con la búsqueda.');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                monitores.length == 1 ? '1 monitor' : '${monitores.length} monitores',
                style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                itemCount: monitores.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = monitores[i];
                  final subtitulo = [
                    m.equipo?.nombre ?? 'Sin PC',
                    m.area?.nombre ?? 'Sin área',
                    if (m.piso != null) 'Piso ${m.piso}',
                  ].join(' · ');
                  return FilaResultado(
                    titulo: m.titulo.isEmpty ? 'Monitor ${m.id}' : m.titulo,
                    subtitulo: subtitulo,
                    etiqueta: m.pulgadasTexto == null ? null : Pildora(m.pulgadasTexto!),
                    onTap: () => _mostrarDetalle(context, m),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDetalle(BuildContext context, Monitor m) {
    final tema = Theme.of(context);
    final secundario = tema.colorScheme.onSurfaceVariant;
    Widget fila(String etiqueta, String? valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: Text(etiqueta, style: TextStyle(color: secundario))),
              Expanded(child: Text(valor ?? '—')),
            ],
          ),
        );
    Widget titulo(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(t.toUpperCase(), style: tema.textTheme.labelMedium?.copyWith(color: secundario, letterSpacing: 0.8)),
        );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(m.titulo.isEmpty ? 'Monitor ${m.id}' : m.titulo,
              style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          titulo('Monitor'),
          fila('Pulgadas', m.pulgadasTexto),
          fila('Número de serie', m.numeroSerie),
          fila('Entradas', m.entradas.isEmpty ? null : m.entradas.join(', ')),
          titulo('Ubicación'),
          fila('PC conectada', m.equipo?.nombre ?? 'Sin PC'),
          fila('Área', m.area?.nombre),
          fila('Piso', m.piso),
          if (m.observaciones != null) ...[titulo('Observaciones'), Text(m.observaciones!)],
        ],
      ),
    );
  }
}
