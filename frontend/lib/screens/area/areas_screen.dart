import 'package:material_ui/material_ui.dart';

import '../../api/api_scope.dart';
import '../../models/area.dart';
import '../../rutas.dart';
import '../../widgets/estado_carga.dart';
import '../../widgets/pantalla_modulo.dart';

/// Pantalla principal del módulo Áreas: búsqueda por nombre y botón Agregar.
/// Las áreas son pocas, así que se traen todas y se filtran en la app.
class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final _busqueda = TextEditingController();
  Future<List<Area>>? _areas;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _areas ??= ApiScope.of(context).areas();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    final nuevas = ApiScope.of(context).areas();
    setState(() {
      _areas = nuevas;
    });
  }

  Future<void> _agregar() async {
    final guardada = await Navigator.of(context).pushNamed<bool>(Rutas.areaCargar);
    if (guardada == true && mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaModulo(
      modulo: Modulo.area,
      textoAccion: 'Agregar',
      onCargar: _agregar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Nombre Área',
                hintText: '[NOMBRE ÁREA]',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_busqueda.clear),
                      ),
              ),
            ),
          ),
          Expanded(child: _lista(context)),
        ],
      ),
    );
  }

  Widget _lista(BuildContext context) {
    final tema = Theme.of(context);
    return FutureBuilder<List<Area>>(
      future: _areas,
      builder: (context, snapshot) {
        if (snapshot.hasError) return EstadoCarga.error(snapshot.error.toString(), onReintentar: _recargar);
        final todas = snapshot.data;
        if (todas == null) return const EstadoCarga.cargando('Cargando áreas…');
        if (todas.isEmpty) return const EstadoCarga.vacio('Todavía no hay áreas. Agregá la primera con el botón Agregar.');

        final texto = _sinAcentos(_busqueda.text.trim().toLowerCase());
        final areas = texto.isEmpty
            ? todas
            : todas.where((a) => _sinAcentos(a.nombre.toLowerCase()).contains(texto)).toList();
        if (areas.isEmpty) return const EstadoCarga.vacio('No hay áreas que coincidan con la búsqueda.');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                areas.length == 1 ? '1 área' : '${areas.length} áreas',
                style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                itemCount: areas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = areas[i];
                  return FilaResultado(
                    titulo: a.nombre,
                    subtitulo: '${_cantidad(a.cantidadPc, 'PC', 'PCs')} · '
                        '${_cantidad(a.cantidadMonitores, 'monitor', 'monitores')}',
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static String _cantidad(int? n, String uno, String varios) => '${n ?? 0} ${n == 1 ? uno : varios}';

  /// Para que "fiscalizacion" encuentre "Fiscalización".
  static String _sinAcentos(String s) => s
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');
}
