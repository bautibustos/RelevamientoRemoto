import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../api/api_scope.dart';
import '../../models/area.dart';
import '../../models/monitor.dart';
import '../../models/pc.dart';
import '../../rutas.dart';
import '../../widgets/estado_carga.dart';
import '../../widgets/pantalla_modulo.dart';
import '../pc/detalle_pc_sheet.dart';
import 'cargar_monitor_screen.dart';

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

  /// Arrastrar para actualizar: vuelve a buscar con los mismos filtros.
  Future<void> _actualizar() {
    _buscar();
    return _resultados!.then((_) {}, onError: (_) {});
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
          Expanded(child: RefreshIndicator(onRefresh: _actualizar, child: _lista(context))),
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
          return Desplazable(child: EstadoCarga.error(snapshot.error.toString(), onReintentar: _buscar));
        }
        final monitores = snapshot.data;
        if (monitores == null) return Desplazable(child: const EstadoCarga.cargando('Buscando monitores…'));
        if (monitores.isEmpty) return Desplazable(child: const EstadoCarga.vacio('No hay monitores que coincidan con la búsqueda.'));

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
                physics: const AlwaysScrollableScrollPhysics(),
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

  /// Detalle del monitor. Desde ahí se puede editar o abrir la PC a la que está conectado.
  Future<void> _mostrarDetalle(BuildContext context, Monitor m) async {
    final accion = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DetalleMonitor(monitor: m),
    );
    if (!context.mounted) return;
    switch (accion) {
      case Pc pc:
        if (await mostrarDetallePc(context, pc)) _buscar(); // por si se editó o relevó la PC
      case Monitor monitor:
        final guardado = await Navigator.of(context)
            .push<bool>(MaterialPageRoute(builder: (_) => CargarMonitorScreen(monitor: monitor)));
        if (guardado == true && mounted) _buscar();
    }
  }
}

/// Hoja de detalle. Se cierra devolviendo el [Monitor] para editarlo o la [Pc] conectada para abrirla.
class _DetalleMonitor extends StatefulWidget {
  const _DetalleMonitor({required this.monitor});

  final Monitor monitor;

  @override
  State<_DetalleMonitor> createState() => _DetalleMonitorState();
}

class _DetalleMonitorState extends State<_DetalleMonitor> {
  bool _abriendoPc = false;
  String? _errorPc;

  Future<void> _abrirPc(EquipoRef equipo) async {
    setState(() {
      _abriendoPc = true;
      _errorPc = null;
    });
    try {
      final pc = await ApiScope.of(context).pc(equipo.id);
      if (mounted) Navigator.of(context).pop(pc);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorPc = e.mensaje);
    } finally {
      if (mounted) setState(() => _abriendoPc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.monitor;
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

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(m.titulo.isEmpty ? 'Monitor ${m.id}' : m.titulo,
            style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(m),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Editar'),
            ),
          ],
        ),
        titulo('PC conectada'),
        if (m.equipo == null)
          Text('Sin PC', style: tema.textTheme.bodyLarge?.copyWith(color: secundario))
        else
          FilaResultado(
            titulo: m.equipo!.nombre,
            subtitulo: _abriendoPc ? 'Abriendo…' : 'Tocá para ver el detalle de la PC',
            etiqueta: _abriendoPc
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.desktop_windows_outlined),
            onTap: _abriendoPc ? null : () => _abrirPc(m.equipo!),
          ),
        if (_errorPc != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_errorPc!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
          ),
        titulo('Monitor'),
        fila('Pulgadas', m.pulgadasTexto),
        fila('Número de serie', m.numeroSerie),
        fila('Entradas', m.entradas.isEmpty ? null : m.entradas.join(', ')),
        titulo('Ubicación'),
        fila('Área', m.area?.nombre),
        fila('Piso', m.piso),
        if (m.observaciones != null) ...[titulo('Observaciones'), Text(m.observaciones!)],
      ],
    );
  }
}
