import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../api/api_scope.dart';
import '../../models/area.dart';
import '../../models/monitor.dart';
import '../../models/pc.dart';
import '../../widgets/estado_carga.dart';

/// Alta de un monitor en tres bloques: ubicación, datos del monitor y entradas de video.
/// Con [monitor] el mismo formulario sirve para editarlo.
class CargarMonitorScreen extends StatefulWidget {
  const CargarMonitorScreen({super.key, this.monitor});

  /// El monitor a editar; null para cargar uno nuevo.
  final Monitor? monitor;

  /// Tamaños más comunes: se cargan con un toque.
  static const pulgadasFrecuentes = [19.0, 21.5, 22.0, 23.8, 24.0, 27.0];

  @override
  State<CargarMonitorScreen> createState() => _CargarMonitorScreenState();
}

class _CargarMonitorScreenState extends State<CargarMonitorScreen> {
  final _form = GlobalKey<FormState>();
  final _piso = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _pulgadas = TextEditingController();
  final _serie = TextEditingController();
  final _observaciones = TextEditingController();
  final _serieFoco = FocusNode();

  Future<(List<Area>, List<String>)>? _catalogos;
  Area? _area;
  EquipoRef? _equipo;
  String _textoEquipo = '';
  final Map<String, int> _entradas = {};
  List<String> _ordenInterfaces = const [];

  bool _guardando = false;
  bool _intentado = false;
  String? _errorSerie;
  String? _errorGeneral;

  bool get _editando => widget.monitor != null;

  @override
  void initState() {
    super.initState();
    final m = widget.monitor;
    if (m == null) return;
    _area = m.area;
    _piso.text = m.piso ?? '';
    _marca.text = m.marca ?? '';
    _modelo.text = m.modelo ?? '';
    if (m.pulgadas != null) _pulgadas.text = _formatoPulgadas(m.pulgadas!);
    _serie.text = m.numeroSerie ?? '';
    _observaciones.text = m.observaciones ?? '';
    _equipo = m.equipo;
    _textoEquipo = m.equipo?.nombre ?? '';
    for (final e in m.entradas) {
      _entradas[e.nombre] = e.cantidad;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalogos ??= _cargarCatalogos();
  }

  Future<(List<Area>, List<String>)> _cargarCatalogos() async {
    final api = ApiScope.of(context);
    final (areas, interfaces) = await (api.areas(), api.interfaces()).wait;
    _ordenInterfaces = interfaces;
    return (areas, interfaces);
  }

  @override
  void dispose() {
    for (final c in [_piso, _marca, _modelo, _pulgadas, _serie, _observaciones]) {
      c.dispose();
    }
    _serieFoco.dispose();
    super.dispose();
  }

  double? get _pulgadasValor => double.tryParse(_pulgadas.text.trim().replaceAll(',', '.'));

  static String _formatoPulgadas(double p) =>
      (p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString()).replaceAll('.', ',');

  /// Al elegir la PC, completa área y piso si todavía están vacíos.
  void _elegirEquipo(Pc pc, List<Area> areas) {
    setState(() {
      _equipo = EquipoRef(id: pc.id, nombre: pc.nombre);
      _textoEquipo = pc.nombre;
      if (_area == null && pc.area != null) {
        _area = areas.where((a) => a.id == pc.area!.id).firstOrNull;
      }
      if (_piso.text.trim().isEmpty && pc.piso != null) _piso.text = pc.piso!;
    });
  }

  String? _limpio(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _guardar() async {
    setState(() {
      _intentado = true;
      _errorSerie = null;
      _errorGeneral = null;
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _guardando = true);
    final entradas = [
      for (final nombre in _ordenInterfaces) // en el orden del catálogo
        if ((_entradas[nombre] ?? 0) > 0) Entrada(nombre: nombre, cantidad: _entradas[nombre]!),
    ];
    final api = ApiScope.of(context);
    try {
      final monitor = _editando
          // se envía todo el formulario: los campos vaciados quedan en null (ej. desconectar la PC)
          ? await api.editarMonitor(widget.monitor!.id, {
              'marca': _marca.text.trim(),
              'modelo': _modelo.text.trim(),
              'pulgadas': _pulgadasValor!,
              'area_id': _area!.id,
              'piso': _limpio(_piso),
              'numero_serie': _limpio(_serie)?.toUpperCase(),
              'equipo_id': _equipo?.id,
              'interfaces': [for (final e in entradas) e.toJson()],
              'observaciones': _limpio(_observaciones),
            })
          : await api.crearMonitor(
              marca: _marca.text.trim(),
              modelo: _modelo.text.trim(),
              pulgadas: _pulgadasValor!,
              areaId: _area!.id,
              piso: _limpio(_piso),
              numeroSerie: _limpio(_serie)?.toUpperCase(),
              equipoId: _equipo?.id,
              entradas: entradas,
              observaciones: _limpio(_observaciones),
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Monitor ${monitor.titulo} guardado.')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        if (e.esDuplicado) {
          _errorSerie = 'Ya existe un monitor con ese número de serie.';
          _serieFoco.requestFocus();
        } else {
          _errorGeneral = e.mensaje;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Area>, List<String>)>(
      future: _catalogos,
      builder: (context, snapshot) {
        final listo = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
        return Scaffold(
          appBar: AppBar(title: Text(_editando ? 'Editar monitor' : 'Cargar monitor')),
          bottomNavigationBar: listo ? _botones(context) : null,
          body: SafeArea(
            child: switch (snapshot) {
              _ when snapshot.hasError => EstadoCarga.error(
                snapshot.error.toString(),
                onReintentar: () {
                  final nuevos = _cargarCatalogos();
                  setState(() {
                    _catalogos = nuevos;
                  });
                },
              ),
              _ when !listo => const EstadoCarga.cargando('Cargando datos…'),
              _ => _formulario(context, snapshot.data!.$1, snapshot.data!.$2),
            },
          ),
        );
      },
    );
  }

  Widget _botones(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: esquema.surface,
        border: Border(top: BorderSide(color: esquema.outline)),
      ),
      child: SafeArea(
        top: false,
        // en pantallas anchas los botones quedan alineados con la columna del formulario
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
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
                          ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context, List<Area> areas, List<String> interfaces) {
    final tema = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _form,
          autovalidateMode: _intentado ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // ---------------------------------------------------------- ubicación
              const _TituloSeccion('Ubicación'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Area>(
                      key: ValueKey(_area),
                      initialValue: _area,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Área', hintText: '[ÁREA]'),
                      items: [
                        for (final a in areas)
                          DropdownMenuItem(
                            value: a,
                            child: Text(a.nombre, overflow: TextOverflow.ellipsis),
                          ),
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
                      inputFormatters: [LengthLimitingTextInputFormatter(20)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CampoEquipo(
                habilitado: !_guardando,
                textoInicial: _textoEquipo,
                onElegido: (pc) => _elegirEquipo(pc, areas),
                onEscrito: (texto) => setState(() {
                  _textoEquipo = texto;
                  if (_equipo != null && texto != _equipo!.nombre) _equipo = null;
                }),
                validator: (_) => _textoEquipo.trim().isNotEmpty && _equipo == null
                    ? 'Elegí un equipo de la lista o dejá el campo vacío.'
                    : null,
              ),

              // ---------------------------------------------------------- monitor
              const _TituloSeccion('Monitor'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marca,
                      enabled: !_guardando,
                      decoration: const InputDecoration(labelText: 'Marca', hintText: '[MARCA]'),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(60)],
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresá la marca.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modelo,
                      enabled: !_guardando,
                      decoration: const InputDecoration(labelText: 'Modelo', hintText: '[MODELO]'),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(80)],
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresá el modelo.' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pulgadas,
                enabled: !_guardando,
                decoration: const InputDecoration(labelText: 'Pulgadas', hintText: '[PULGADAS]', suffixText: '"'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (_) => setState(() {}),
                validator: (_) {
                  final p = _pulgadasValor;
                  if (_pulgadas.text.trim().isEmpty) return 'Ingresá las pulgadas.';
                  if (p == null || p <= 0 || p > 100) return 'Ingresá un número entre 1 y 100.';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // tamaños frecuentes en una grilla de 3 columnas
              for (final fila in [
                CargarMonitorScreen.pulgadasFrecuentes.sublist(0, 3),
                CargarMonitorScreen.pulgadasFrecuentes.sublist(3),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (final (i, p) in fila.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _OpcionPulgadas(
                            texto: '${_formatoPulgadas(p)}"',
                            elegida: _pulgadasValor == p,
                            onTap: _guardando ? null : () => setState(() => _pulgadas.text = _formatoPulgadas(p)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serie,
                focusNode: _serieFoco,
                enabled: !_guardando,
                decoration: InputDecoration(
                  labelText: 'Número de serie (opcional)',
                  hintText: '[NÚMERO DE SERIE]',
                  errorText: _errorSerie,
                ),
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                onChanged: (_) {
                  if (_errorSerie != null) setState(() => _errorSerie = null);
                },
              ),

              // ---------------------------------------------------------- entradas
              const _TituloSeccion('Entradas de video'),
              Container(
                decoration: BoxDecoration(
                  color: tema.colorScheme.surface,
                  border: Border.all(color: tema.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (final (i, nombre) in interfaces.indexed) ...[
                      if (i > 0) Divider(height: 1, color: tema.colorScheme.outline),
                      _FilaEntrada(
                        nombre: nombre,
                        cantidad: _entradas[nombre] ?? 0,
                        habilitado: !_guardando,
                        onCambio: (n) => setState(() => _entradas[nombre] = n),
                      ),
                    ],
                  ],
                ),
              ),

              // ---------------------------------------------------------- observaciones
              const _TituloSeccion('Observaciones'),
              TextFormField(
                controller: _observaciones,
                enabled: !_guardando,
                decoration: const InputDecoration(labelText: 'Observaciones (opcional)', hintText: '[OBSERVACIONES]'),
                minLines: 2,
                maxLines: 4,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
              ),
              if (_errorGeneral != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorGeneral!,
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        texto.toUpperCase(),
        style: tema.textTheme.labelLarge?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Botón de un tamaño frecuente; el elegido queda con el color de acento.
class _OpcionPulgadas extends StatelessWidget {
  const _OpcionPulgadas({required this.texto, required this.elegida, required this.onTap});

  final String texto;
  final bool elegida;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      selected: elegida,
      button: true,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: EdgeInsets.zero,
          backgroundColor: elegida ? esquema.primary : esquema.surface,
          foregroundColor: elegida ? esquema.onPrimary : esquema.onSurface,
          side: BorderSide(color: elegida ? esquema.primary : esquema.outline),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(texto),
      ),
    );
  }
}

/// Una interfaz con su contador: [-] 0 [+].
class _FilaEntrada extends StatelessWidget {
  const _FilaEntrada({required this.nombre, required this.cantidad, required this.habilitado, required this.onCambio});

  static const maximo = 4;

  final String nombre;
  final int cantidad;
  final bool habilitado;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final activa = cantidad > 0;
    return Semantics(
      label: '$nombre: $cantidad',
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: tema.textTheme.bodyLarge?.copyWith(
                  fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
                  color: activa ? tema.colorScheme.onSurface : tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Quitar $nombre',
              icon: const Icon(Icons.remove),
              onPressed: habilitado && cantidad > 0 ? () => onCambio(cantidad - 1) : null,
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$cantidad',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: activa ? tema.colorScheme.primary : tema.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Agregar $nombre',
              icon: const Icon(Icons.add),
              onPressed: habilitado && cantidad < maximo ? () => onCambio(cantidad + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo con sugerencias de PCs: se escribe parte del nombre y se elige de la lista.
class _CampoEquipo extends StatefulWidget {
  const _CampoEquipo({
    required this.habilitado,
    required this.textoInicial,
    required this.onElegido,
    required this.onEscrito,
    required this.validator,
  });

  final bool habilitado;
  final String textoInicial;
  final ValueChanged<Pc> onElegido;
  final ValueChanged<String> onEscrito;
  final FormFieldValidator<String> validator;

  @override
  State<_CampoEquipo> createState() => _CampoEquipoState();
}

class _CampoEquipoState extends State<_CampoEquipo> {
  Timer? _espera;

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  /// Espera a que se deje de escribir antes de consultar la API.
  Future<List<Pc>> _sugerencias(String texto) {
    _espera?.cancel();
    if (texto.trim().isEmpty) return Future.value(const []);
    final completer = Completer<List<Pc>>();
    final api = ApiScope.of(context);
    _espera = Timer(const Duration(milliseconds: 250), () {
      api
          .pcs(nombre: texto)
          .then((l) => completer.complete(l.take(8).toList()), onError: (_) => completer.complete(const []));
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Autocomplete<Pc>(
      initialValue: TextEditingValue(text: widget.textoInicial),
      displayStringForOption: (pc) => pc.nombre,
      optionsBuilder: (valor) => _sugerencias(valor.text),
      onSelected: widget.onElegido,
      fieldViewBuilder: (context, controller, foco, alEnviar) => TextFormField(
        controller: controller,
        focusNode: foco,
        enabled: widget.habilitado,
        decoration: const InputDecoration(
          labelText: 'PC conectada (opcional)',
          hintText: '[NOMBRE EQUIPO]',
          helperText: 'Vacío si no está conectado a una PC.',
          prefixIcon: Icon(Icons.desktop_windows_outlined),
        ),
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        onChanged: widget.onEscrito,
        onFieldSubmitted: (_) => alEnviar(),
        validator: widget.validator,
      ),
      optionsViewBuilder: (context, alElegir, opciones) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          color: tema.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 528),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final pc in opciones)
                  ListTile(
                    minTileHeight: 52,
                    title: Text(pc.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [pc.area?.nombre, if (pc.piso != null) 'Piso ${pc.piso}'].whereType<String>().join(' · '),
                    ),
                    onTap: () => alElegir(pc),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
