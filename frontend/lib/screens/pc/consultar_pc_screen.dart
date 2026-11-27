import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/api_scope.dart';
import '../../models/area.dart';
import '../../models/pc.dart';
import '../../rutas.dart';
import '../../widgets/estado_carga.dart';
import '../../widgets/etiqueta_estado.dart';
import '../../widgets/pantalla_modulo.dart';
import 'detalle_pc_sheet.dart';

/// Pantalla principal del módulo PC: búsqueda por nombre, filtros de área y estado,
/// y el botón Cargar para dar de alta un equipo.
class ConsultarPcScreen extends StatefulWidget {
  const ConsultarPcScreen({super.key});

  @override
  State<ConsultarPcScreen> createState() => _ConsultarPcScreenState();
}

class _ConsultarPcScreenState extends State<ConsultarPcScreen> {
  final _busqueda = TextEditingController();
  Timer? _espera;

  List<Area> _areas = const [];
  Area? _area;
  EstadoPc? _estado;

  Future<List<Pc>>? _resultados;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resultados == null) {
      _buscar();
      ApiScope.of(context).areas().then((a) {
        if (mounted) setState(() => _areas = a);
      }, onError: (_) {}); // si fallan, el error ya se ve en la lista
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
      _resultados = ApiScope.of(context).pcs(nombre: _busqueda.text, areaId: _area?.id, estado: _estado);
    });
  }

  /// Arrastrar para actualizar: vuelve a buscar con los mismos filtros.
  Future<void> _actualizar() {
    _buscar();
    return _resultados!.then((_) {}, onError: (_) {}); // el error se muestra en la lista
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 300), _buscar);
    setState(() {}); // muestra u oculta el botón de borrar
  }

  Future<void> _cargar() async {
    final guardada = await Navigator.of(context).pushNamed<bool>(Rutas.pcCargar);
    if (guardada == true && mounted) _buscar(); // muestra el equipo recién cargado
  }

  @override
  Widget build(BuildContext context) {
    return PantallaModulo(
      modulo: Modulo.pc,
      onCargar: _cargar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filtros(context),
          Expanded(child: RefreshIndicator(onRefresh: _actualizar, child: _lista(context))),
        ],
      ),
    );
  }

  Widget _filtros(BuildContext context) {
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
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Nombre Equipo',
              hintText: '[NOMBRE EQUIPO]',
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
                child: DropdownButtonFormField<EstadoPc?>(
                  initialValue: _estado,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    const DropdownMenuItem<EstadoPc?>(value: null, child: Text('Todos')),
                    for (final e in EstadoPc.values) DropdownMenuItem<EstadoPc?>(value: e, child: Text(e.etiqueta)),
                  ],
                  onChanged: (e) {
                    _estado = e;
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
    return FutureBuilder<List<Pc>>(
      future: _resultados,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Desplazable(child: EstadoCarga.error(snapshot.error.toString(), onReintentar: _buscar));
        }
        final pcs = snapshot.data;
        if (pcs == null) return Desplazable(child: const EstadoCarga.cargando('Buscando equipos…'));
        if (pcs.isEmpty) return Desplazable(child: const EstadoCarga.vacio('No hay equipos que coincidan con la búsqueda.'));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    pcs.length == 1 ? '1 equipo' : '${pcs.length} equipos',
                    style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                  if (snapshot.connectionState != ConnectionState.done) ...[
                    const SizedBox(width: 8),
                    const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), // espacio para el botón Cargar
                itemCount: pcs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _FilaPc(pc: pcs[i], onModificada: _buscar),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilaPc extends StatelessWidget {
  const _FilaPc({required this.pc, required this.onModificada});

  final Pc pc;
  final VoidCallback onModificada;

  @override
  Widget build(BuildContext context) {
    final ubicacion = [
      pc.area?.nombre ?? 'Sin área',
      if (pc.piso != null) 'Piso ${pc.piso}',
    ].join(' · ');
    return FilaResultado(
      titulo: pc.nombre,
      subtitulo: ubicacion,
      etiqueta: EtiquetaEstado(estado: pc.estado),
      onTap: () async {
        if (await mostrarDetallePc(context, pc)) onModificada(); // refleja lo editado en la lista
      },
    );
  }
}
