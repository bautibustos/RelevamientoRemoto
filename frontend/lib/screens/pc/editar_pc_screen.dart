import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../api/api_scope.dart';
import '../../models/area.dart';
import '../../models/pc.dart';
import '../../widgets/aviso.dart';
import '../../widgets/estado_carga.dart';

const _tiposRam = ['DDR1', 'DDR2', 'DDR3', 'DDR4', 'DDR5'];
const _buses = ['NVMe', 'SATA', 'ATA', 'SAS', 'SCSI', 'RAID', 'otro'];
const _tecnologias = ['SSD', 'HDD', 'desconocido'];

/// Campos de texto de la PC que se editan tal cual (clave = nombre en la API).
const _textos = [
  'piso',
  'nombre',
  'red',
  'so',
  'usuario',
  'cpu_familia',
  'cpu_modelo',
  'cpu_ghz',
  'placa_fabricante',
  'placa_modelo',
  'video',
];

/// Convierte "3,6" o "3.6" a número; null si está vacío o no es un número.
double? _numero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

class _ModuloEdit {
  _ModuloEdit({String gb = '', String mhz = ''})
    : gb = TextEditingController(text: gb),
      mhz = TextEditingController(text: mhz);
  final TextEditingController gb;
  final TextEditingController mhz;

  String get firma => '${gb.text.trim()}|${mhz.text.trim()}';
  Map<String, dynamic> toJson() => {'capacidad_gb': _numero(gb.text), 'mhz': _numero(mhz.text)?.round()};
  void dispose() {
    gb.dispose();
    mhz.dispose();
  }
}

class _DiscoEdit {
  _DiscoEdit({String marca = '', String gb = '', this.tecnologia = 'SSD', this.bus = 'SATA'})
    : marca = TextEditingController(text: marca),
      gb = TextEditingController(text: gb);
  final TextEditingController marca;
  final TextEditingController gb;
  String tecnologia;
  String? bus;

  String get firma => '${marca.text.trim()}|${gb.text.trim()}|$tecnologia|$bus';
  Map<String, dynamic> toJson() {
    final m = marca.text.trim();
    return {'marca': m.isEmpty ? null : m, 'tecnologia': tecnologia, 'bus': bus, 'capacidad_gb': _numero(gb.text)};
  }

  void dispose() {
    marca.dispose();
    gb.dispose();
  }
}

/// Edición de una PC: ubicación, hardware, módulos de RAM y discos.
/// Solo se envían a la API los datos que cambiaron.
class EditarPcScreen extends StatefulWidget {
  const EditarPcScreen({super.key, required this.pc});

  /// PC con su detalle completo (módulos y discos).
  final Pc pc;

  @override
  State<EditarPcScreen> createState() => _EditarPcScreenState();
}

class _EditarPcScreenState extends State<EditarPcScreen> {
  static final _nombreValido = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  final _form = GlobalKey<FormState>();
  final _ctrl = {for (final k in _textos) k: TextEditingController()};
  late final Map<String, String> _orig;
  final _modulos = <_ModuloEdit>[];
  final _discos = <_DiscoEdit>[];
  late final List<String> _firmaModulos;
  late final List<String> _firmaDiscos;

  Future<List<Area>>? _areas;
  int? _areaId;
  String? _ramTipo;
  bool _guardando = false;
  int _version = 0; // cambia al descartar, para recrear los campos con los datos guardados
  String? _errorNombre;
  String? _errorGeneral;

  Pc get pc => widget.pc;

  @override
  void initState() {
    super.initState();
    _orig = {
      'piso': pc.piso ?? '',
      'nombre': pc.nombre,
      'red': pc.red ?? '',
      'so': pc.so ?? '',
      'usuario': pc.usuario ?? '',
      'cpu_familia': pc.cpuFamilia ?? '',
      'cpu_modelo': pc.cpuModelo ?? '',
      'cpu_ghz': pc.cpuGhz == null ? '' : '${pc.cpuGhz}'.replaceAll('.', ','),
      'placa_fabricante': pc.placaFabricante ?? '',
      'placa_modelo': pc.placaModelo ?? '',
      'video': pc.video ?? '',
    };
    _reiniciar();
    _firmaModulos = [for (final m in _modulos) m.firma];
    _firmaDiscos = [for (final d in _discos) d.firma];
    for (final c in _ctrl.values) {
      c.addListener(_actualizar);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _areas ??= ApiScope.of(context).areas();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    for (final m in _modulos) {
      m.dispose();
    }
    for (final d in _discos) {
      d.dispose();
    }
    super.dispose();
  }

  void _actualizar() => setState(() {});

  /// Vuelve todos los campos a los datos guardados.
  void _reiniciar() {
    for (final k in _textos) {
      _ctrl[k]!.text = _orig[k]!;
    }
    _areaId = pc.area?.id;
    _ramTipo = pc.ramTipo;
    _version++;
    // los controladores viejos se liberan después del cuadro, cuando ya no hay campos que los usen
    final viejos = [..._modulos, ..._discos];
    if (viejos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final v in viejos) {
          if (v is _ModuloEdit) v.dispose();
          if (v is _DiscoEdit) v.dispose();
        }
      });
    }
    _modulos
      ..clear()
      ..addAll([for (final m in pc.memorias) _ModuloEdit(gb: gbTexto(m.capacidadGb), mhz: m.mhz?.toString() ?? '')]);
    _discos
      ..clear()
      ..addAll([
        for (final d in pc.discos)
          _DiscoEdit(
            marca: d.marca ?? '',
            gb: d.capacidadGb == null ? '' : gbTexto(d.capacidadGb!),
            tecnologia: d.tecnologia,
            bus: d.bus,
          ),
      ]);
    for (final m in _modulos) {
      m.gb.addListener(_actualizar);
      m.mhz.addListener(_actualizar);
    }
    for (final d in _discos) {
      d.marca.addListener(_actualizar);
      d.gb.addListener(_actualizar);
    }
    _errorNombre = null;
    _errorGeneral = null;
  }

  bool _modificado(String campo) => _ctrl[campo]!.text.trim() != _orig[campo]!.trim();

  bool get _modulosCambiaron => !_listasIguales([for (final m in _modulos) m.firma], _firmaModulos);
  bool get _discosCambiaron => !_listasIguales([for (final d in _discos) d.firma], _firmaDiscos);

  static bool _listasIguales(List<String> a, List<String> b) => jsonEncode(a) == jsonEncode(b);

  /// Solo lo que cambió, en el formato de PATCH /pc/{id}.
  Map<String, dynamic> _cambios() {
    final cambios = <String, dynamic>{};
    for (final k in _textos) {
      if (!_modificado(k)) continue;
      final v = _ctrl[k]!.text.trim();
      cambios[k] = switch (k) {
        'nombre' => v.toUpperCase(),
        'cpu_ghz' => _numero(v),
        _ => v.isEmpty ? null : v,
      };
    }
    if (_areaId != pc.area?.id) cambios['area_id'] = _areaId;
    if (_ramTipo != pc.ramTipo) cambios['ram_tipo'] = _ramTipo;
    if (_modulosCambiaron) cambios['memorias'] = [for (final m in _modulos) m.toJson()];
    if (_discosCambiaron) cambios['discos'] = [for (final d in _discos) d.toJson()];
    return cambios;
  }

  Future<bool> _confirmarSalida() async {
    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text('Los cambios que no guardaste se van a perder.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Seguir editando')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Descartar')),
        ],
      ),
    );
    return descartar == true;
  }

  Future<void> _guardar() async {
    setState(() {
      _errorNombre = null;
      _errorGeneral = null;
    });
    if (!_form.currentState!.validate()) return;
    final cambios = _cambios();
    if (cambios.isEmpty) return;

    setState(() => _guardando = true);
    try {
      final guardada = await ApiScope.of(context).editarPc(pc.id, cambios);
      if (!mounted) return;
      mostrarAviso(context, titulo: 'Equipo ${guardada.nombre} actualizado');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        if (e.esDuplicado) {
          _errorNombre = 'Ya existe un equipo con ese nombre.';
        } else {
          _errorGeneral = e.mensaje;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cantidad = _cambios().length;
    return PopScope<bool>(
      canPop: cantidad == 0 || _guardando,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navegador = Navigator.of(context);
        if (await _confirmarSalida()) navegador.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Editar PC'),
              Text(pc.nombre, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<List<Area>>(
            future: _areas,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const EstadoCarga.cargando('Cargando áreas…');
              }
              if (snapshot.hasError) {
                return EstadoCarga.error(
                  snapshot.error.toString(),
                  onReintentar: () => setState(() => _areas = ApiScope.of(context).areas()),
                );
              }
              return _formulario(context, snapshot.data!);
            },
          ),
        ),
        bottomNavigationBar: _barraAcciones(context, cantidad),
      ),
    );
  }

  Widget _barraAcciones(BuildContext context, int cantidad) {
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        // en pantallas anchas los botones quedan alineados con la columna del formulario
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _guardando
                          ? 'Guardando…'
                          : cantidad == 0
                          ? 'Sin cambios'
                          : cantidad == 1
                          ? '1 cambio'
                          : '$cantidad cambios',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: cantidad == 0 ? tema.colorScheme.onSurfaceVariant : tema.colorScheme.primary,
                        fontWeight: cantidad == 0 ? null : FontWeight.w600,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: cantidad == 0 || _guardando ? null : () => setState(_reiniciar),
                    child: const Text('Descartar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20)),
                    onPressed: cantidad == 0 || _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context, List<Area> areas) {
    final tema = Theme.of(context);
    // si el área de la PC no está en la lista (no debería pasar) se deja sin elegir
    final areaValida = areas.any((a) => a.id == _areaId) ? _areaId : null;
    final totalRam = _modulos.fold<double>(0, (s, m) => s + (_numero(m.gb.text) ?? 0));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            key: ValueKey(_version),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Seccion(
                titulo: 'Identificación y ubicación',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          initialValue: areaValida,
                          isExpanded: true,
                          decoration: _deco(context, 'Área', modificado: _areaId != pc.area?.id),
                          items: [
                            for (final a in areas)
                              DropdownMenuItem(
                                value: a.id,
                                child: Text(a.nombre, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: _guardando ? null : (id) => setState(() => _areaId = id),
                          validator: (id) => id == null ? 'Elegí un área.' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _texto('piso', 'Piso', validar: (v) => v.isEmpty ? 'Ingresá el piso.' : null),
                      ),
                    ],
                  ),
                  _texto(
                    'nombre',
                    'Nombre Equipo',
                    mayusculas: true,
                    error: _errorNombre,
                    validar: (v) {
                      if (v.isEmpty) return 'Ingresá el nombre del equipo.';
                      if (!_nombreValido.hasMatch(v)) {
                        return 'Usá solo letras, números, punto, guion o guion bajo (sin espacios).';
                      }
                      return null;
                    },
                  ),
                  _texto('red', 'Red'),
                ],
              ),
              _Seccion(
                titulo: 'Hardware',
                nota:
                    'Estos datos los completa el relevamiento. Editalos a mano solo si el relevamiento '
                    'falló o trajo algo incorrecto.',
                children: [
                  _texto('so', 'Sistema operativo'),
                  _texto('usuario', 'Usuario'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _texto('cpu_familia', 'Procesador')),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: _texto('cpu_modelo', 'Modelo')),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _texto(
                          'cpu_ghz',
                          'GHz',
                          numerico: true,
                          validar: (v) {
                            if (v.isEmpty) return null;
                            final n = _numero(v);
                            return n == null || n <= 0 || n > 10 ? 'Valor inválido.' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _texto('placa_fabricante', 'Placa madre')),
                      const SizedBox(width: 12),
                      Expanded(child: _texto('placa_modelo', 'Modelo placa')),
                    ],
                  ),
                  _texto('video', 'Video'),
                ],
              ),
              _Seccion(
                titulo: 'Memoria RAM',
                detalle: _modulos.isEmpty
                    ? 'Sin módulos'
                    : 'Total ${gbTexto(totalRam)} GB · '
                          '${_modulos.length == 1 ? '1 módulo' : '${_modulos.length} módulos'}',
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: _ramTipo,
                    decoration: _deco(context, 'Tipo', modificado: _ramTipo != pc.ramTipo),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sin dato')),
                      for (final t in _tiposRam) DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: _guardando ? null : (t) => setState(() => _ramTipo = t),
                  ),
                  for (final (i, m) in _modulos.indexed) _filaModulo(context, i, m),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _guardando ? null : _agregarModulo,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar módulo'),
                    ),
                  ),
                ],
              ),
              _Seccion(
                titulo: 'Discos',
                detalle: _discos.length == 1 ? '1 disco' : '${_discos.length} discos',
                children: [
                  for (final (i, d) in _discos.indexed) _tarjetaDisco(context, i, d),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _guardando ? null : _agregarDisco,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar disco'),
                    ),
                  ),
                ],
              ),
              if (_errorGeneral != null)
                Text(_errorGeneral!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
            ],
          ),
        ),
      ),
    );
  }

  void _agregarModulo() {
    final m = _ModuloEdit();
    m.gb.addListener(_actualizar);
    m.mhz.addListener(_actualizar);
    setState(() => _modulos.add(m));
  }

  void _agregarDisco() {
    final d = _DiscoEdit();
    d.marca.addListener(_actualizar);
    d.gb.addListener(_actualizar);
    setState(() => _discos.add(d));
  }

  Widget _filaModulo(BuildContext context, int i, _ModuloEdit m) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            key: ObjectKey(m.gb),
            controller: m.gb,
            enabled: !_guardando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _deco(context, 'Módulo ${i + 1} · GB', hint: '[GB]'),
            validator: (v) {
              final n = _numero(v ?? '');
              return n == null || n <= 0 ? 'Ingresá los GB.' : null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            key: ObjectKey(m.mhz),
            controller: m.mhz,
            enabled: !_guardando,
            keyboardType: TextInputType.number,
            decoration: _deco(context, 'MHz', hint: '[MHZ]'),
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return null;
              final n = _numero(v!);
              return n == null || n <= 0 ? 'Valor inválido.' : null;
            },
          ),
        ),
        IconButton(
          tooltip: 'Quitar módulo ${i + 1}',
          onPressed: _guardando
              ? null
              : () => setState(() {
                  _modulos.removeAt(i).dispose();
                }),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _tarjetaDisco(BuildContext context, int i, _DiscoEdit d) {
    final tema = Theme.of(context);
    return Container(
      key: ObjectKey(d),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      decoration: BoxDecoration(
        border: Border.all(color: tema.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(child: Text('Disco ${i + 1}', style: tema.textTheme.titleSmall)),
              IconButton(
                tooltip: 'Quitar disco ${i + 1}',
                onPressed: _guardando
                    ? null
                    : () => setState(() {
                        _discos.removeAt(i).dispose();
                      }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: d.marca,
                    enabled: !_guardando,
                    decoration: _deco(context, 'Marca', hint: '[MARCA]'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: d.gb,
                    enabled: !_guardando,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _deco(context, 'Capacidad GB', hint: '[GB]'),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return null;
                      final n = _numero(v!);
                      return n == null || n <= 0 ? 'Valor inválido.' : null;
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final t in _tecnologias)
                        ButtonSegment(value: t, label: Text(t == 'desconocido' ? '?' : t), tooltip: t),
                    ],
                    selected: {d.tecnologia},
                    onSelectionChanged: _guardando ? null : (s) => setState(() => d.tecnologia = s.first),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String?>(
                    initialValue: d.bus,
                    isExpanded: true,
                    decoration: _deco(context, 'Conexión'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('—')),
                      for (final b in _buses) DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: _guardando ? null : (b) => setState(() => d.bus = b),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Campo de texto de la PC que se marca con el color de acento si cambió.
  Widget _texto(
    String campo,
    String etiqueta, {
    bool mayusculas = false,
    bool numerico = false,
    String? error,
    String? Function(String v)? validar,
  }) {
    return TextFormField(
      controller: _ctrl[campo],
      enabled: !_guardando,
      decoration: _deco(context, etiqueta, modificado: _modificado(campo), error: error),
      textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.none,
      keyboardType: numerico ? const TextInputType.numberWithOptions(decimal: true) : null,
      autocorrect: false,
      onChanged: campo == 'nombre' && _errorNombre != null ? (_) => setState(() => _errorNombre = null) : null,
      validator: validar == null ? null : (v) => validar((v ?? '').trim()),
    );
  }

  InputDecoration _deco(BuildContext context, String etiqueta, {bool modificado = false, String? hint, String? error}) {
    final tema = Theme.of(context);
    return InputDecoration(
      labelText: etiqueta,
      hintText: hint,
      errorText: error,
      helperText: modificado ? 'Modificado' : null,
      helperStyle: TextStyle(color: tema.colorScheme.primary, fontWeight: FontWeight.w600),
      filled: modificado,
      fillColor: tema.colorScheme.primary.withValues(alpha: 0.08),
    );
  }
}

/// Bloque con título (y un detalle opcional a la derecha) que agrupa campos del formulario.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children, this.detalle, this.nota});

  final String titulo;
  final String? detalle;
  final String? nota;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        border: Border.all(color: tema.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(titulo, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (detalle != null)
                Text(detalle!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ],
          ),
          if (nota != null)
            Text(nota!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ...children,
        ],
      ),
    );
  }
}
