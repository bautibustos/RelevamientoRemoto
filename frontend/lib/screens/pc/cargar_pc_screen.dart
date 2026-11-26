import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../api/api_scope.dart';
import '../../models/area.dart';
import '../../widgets/estado_carga.dart';

/// Alta de una PC: área, piso y nombre del equipo.
class CargarPcScreen extends StatefulWidget {
  const CargarPcScreen({super.key});

  @override
  State<CargarPcScreen> createState() => _CargarPcScreenState();
}

class _CargarPcScreenState extends State<CargarPcScreen> {
  final _form = GlobalKey<FormState>();
  final _piso = TextEditingController();
  final _nombre = TextEditingController();
  final _nombreFoco = FocusNode();

  Future<List<Area>>? _areas;
  Area? _area;
  bool _guardando = false;
  bool _intentado = false; // tras el primer Guardar, los errores se actualizan al corregir
  String? _errorNombre; // error que viene de la API (duplicado)
  String? _errorGeneral;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _areas ??= ApiScope.of(context).areas();
  }

  @override
  void dispose() {
    _piso.dispose();
    _nombre.dispose();
    _nombreFoco.dispose();
    super.dispose();
  }

  void _reintentarAreas() {
    final nuevas = ApiScope.of(context).areas();
    setState(() {
      _areas = nuevas;
    });
  }

  Future<void> _guardar() async {
    setState(() {
      _intentado = true;
      _errorNombre = null;
      _errorGeneral = null;
    });
    if (!_form.currentState!.validate()) return;

    final nombre = _nombre.text.trim().toUpperCase();
    setState(() => _guardando = true);
    try {
      await ApiScope.of(context).crearPc(nombre: nombre, areaId: _area!.id, piso: _piso.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Equipo $nombre guardado.')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        if (e.esDuplicado) {
          _errorNombre = 'Ya existe un equipo con ese nombre.';
          _nombreFoco.requestFocus();
        } else {
          _errorGeneral = e.mensaje;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cargar PC')),
      body: SafeArea(
        child: FutureBuilder<List<Area>>(
          future: _areas,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const EstadoCarga.cargando('Cargando áreas…');
            }
            if (snapshot.hasError) {
              return EstadoCarga.error(snapshot.error.toString(), onReintentar: _reintentarAreas);
            }
            return _formulario(context, snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context, List<Area> areas) {
    final tema = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _form,
          autovalidateMode: _intentado ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Area>(
                      initialValue: _area,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Área', hintText: '[ÁREA]'),
                      items: [
                        for (final a in areas)
                          DropdownMenuItem(value: a, child: Text(a.nombre, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: _guardando ? null : (a) => setState(() => _area = a),
                      validator: (a) => a == null ? 'Elegí un área.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _piso,
                      enabled: !_guardando,
                      decoration: const InputDecoration(labelText: 'Piso', hintText: '[PISO]'),
                      textInputAction: TextInputAction.next,
                      maxLength: 20,
                      buildCounter: _sinContador,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresá el piso.' : null,
                    ),
                  ),
                ],
              ),
              if (areas.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('No hay áreas cargadas. Agregá una desde el módulo Áreas antes de cargar equipos.',
                      style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre,
                focusNode: _nombreFoco,
                enabled: !_guardando,
                decoration: InputDecoration(
                  labelText: 'Nombre Equipo',
                  hintText: '[NOMBRE EQUIPO]',
                  errorText: _errorNombre,
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                maxLength: 50,
                buildCounter: _sinContador,
                onChanged: (_) {
                  if (_errorNombre != null) setState(() => _errorNombre = null);
                },
                onFieldSubmitted: (_) => _guardar(),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresá el nombre del equipo.' : null,
              ),
              if (_errorGeneral != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_errorGeneral!,
                      style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
                ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox.square(
                              dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget? _sinContador(BuildContext context,
          {required int currentLength, required bool isFocused, required int? maxLength}) =>
      null;
}
