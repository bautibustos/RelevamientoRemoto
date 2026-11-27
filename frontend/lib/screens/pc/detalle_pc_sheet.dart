import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../api/api_scope.dart';
import '../../theme.dart';
import '../../models/pc.dart';
import '../../models/sistema.dart';
import '../../widgets/estado_carga.dart';
import '../../widgets/etiqueta_estado.dart';
import 'editar_pc_screen.dart';

/// Abre el detalle de una PC en una hoja inferior. Trae los discos de la API.
/// Desde el detalle se puede volver a relevar o pasar a editar.
/// Devuelve true si la PC cambió (para refrescar la lista).
Future<bool> mostrarDetallePc(BuildContext context, Pc resumen) async {
  var relevada = false;
  final paraEditar = await showModalBottomSheet<Pc>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          _HojaDetalle(resumen: resumen, scroll: scroll, onRelevada: () => relevada = true),
    ),
  );
  if (paraEditar == null || !context.mounted) return relevada;
  final guardada = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => EditarPcScreen(pc: paraEditar)));
  return guardada == true || relevada;
}

class _HojaDetalle extends StatefulWidget {
  const _HojaDetalle({required this.resumen, required this.scroll, required this.onRelevada});

  final Pc resumen;
  final ScrollController scroll;
  final VoidCallback onRelevada;

  @override
  State<_HojaDetalle> createState() => _HojaDetalleState();
}

/// Cada cuánto se vuelve a consultar la PC mientras el validador no terminó.
const _cadaCuantoConsultar = Duration(seconds: 3);

class _HojaDetalleState extends State<_HojaDetalle> {
  late ApiClient _api;
  Future<Pc>? _detalle;
  bool _relevando = false;
  ResultadoRelevamiento? _resultado;

  /// Modo de la API y validadores (null si la API no lo informa).
  EstadoSistema? _sistema;

  /// Consulta periódica mientras la PC está en la cola del validador o siendo relevada.
  Timer? _seguimiento;
  EstadoPc? _ultimoEstado;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = ApiScope.of(context);
    _detalle ??= _cargarDetalle();
  }

  @override
  void dispose() {
    _seguimiento?.cancel();
    super.dispose();
  }

  Future<Pc> _cargarDetalle() async {
    final sistema = _api.sistema();
    final pc = await _api.pc(widget.resumen.id);
    _sistema = await sistema;
    _ultimoEstado = pc.estado;
    _seguirSiHaceFalta(pc);
    return pc;
  }

  /// Se sigue la PC solo si alguien la va a relevar: API en modo "carga" o un validador vivo.
  void _seguirSiHaceFalta(Pc pc) {
    final hayQuienReleve = _sistema != null && (_sistema!.modoCarga || _sistema!.hayValidadorActivo);
    if (pc.estado.enCurso && hayQuienReleve) {
      _seguimiento ??= Timer.periodic(_cadaCuantoConsultar, (_) => _consultar());
    } else {
      _seguimiento?.cancel();
      _seguimiento = null;
    }
  }

  Future<void> _consultar() async {
    try {
      final pc = await _api.pc(widget.resumen.id);
      if (!mounted) return;
      final antes = _ultimoEstado;
      _ultimoEstado = pc.estado;
      setState(() {
        _detalle = Future.value(pc);
        if (antes != null && antes.enCurso && !pc.estado.enCurso) {
          // el validador terminó: se avisa el resultado y se refresca la lista al cerrar
          widget.onRelevada();
          _resultado = ResultadoRelevamiento(
            ok: pc.estado == EstadoPc.ok,
            detalle: pc.estado == EstadoPc.ok
                ? 'El validador relevó el equipo y guardó el hardware.'
                : (pc.ultimoError ?? 'Quedó como "${pc.estado.etiqueta}".'),
          );
        }
      });
      _seguirSiHaceFalta(pc);
    } on ApiException {
      // sin conexión momentánea: se reintenta en la próxima vuelta
    }
  }

  Future<void> _relevar() async {
    setState(() {
      _relevando = true;
      _resultado = null;
    });
    try {
      final (pc, resultado) = await _api.relevarPc(widget.resumen.id);
      widget.onRelevada();
      if (!mounted) return;
      _ultimoEstado = pc.estado;
      setState(() {
        _detalle = Future.value(pc);
        _resultado = resultado;
      });
      _seguirSiHaceFalta(pc);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _resultado = ResultadoRelevamiento(ok: false, detalle: e.mensaje));
    } finally {
      if (mounted) setState(() => _relevando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Pc>(
      future: _detalle,
      builder: (context, snapshot) {
        // mientras llega el detalle se muestra lo que ya trajo la lista
        final pc = snapshot.data ?? widget.resumen;
        final listo = snapshot.hasData && !_relevando;
        return _Detalle(
          pc: pc,
          scroll: widget.scroll,
          cargandoDiscos: snapshot.connectionState != ConnectionState.done,
          error: snapshot.hasError ? snapshot.error.toString() : null,
          // se edita con el detalle completo (módulos y discos), no con el resumen de la lista
          onEditar: listo ? () => Navigator.of(context).pop(snapshot.data) : null,
          // mientras el validador la tiene no se vuelve a encolar
          onRelevar: listo && _seguimiento == null ? _relevar : null,
          relevando: _relevando,
          resultado: _resultado,
          siguiendo: _seguimiento != null,
          sinValidador: _sistema != null && _sistema!.modoCarga && !_sistema!.hayValidadorActivo,
        );
      },
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({
    required this.pc,
    required this.scroll,
    required this.cargandoDiscos,
    this.error,
    this.onEditar,
    this.onRelevar,
    this.relevando = false,
    this.resultado,
    this.siguiendo = false,
    this.sinValidador = false,
  });

  final Pc pc;
  final VoidCallback? onEditar;
  final VoidCallback? onRelevar;
  final bool relevando;
  final ResultadoRelevamiento? resultado;

  /// Se está consultando la PC periódicamente esperando al validador.
  final bool siguiendo;

  /// La API está en modo "carga" y no hay ningún validador vivo dentro de la red.
  final bool sinValidador;
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
    final ram = [
      if (pc.ramTotalGb != null) '${gbTexto(pc.ramTotalGb!)} GB',
      pc.ramTipo,
      if (pc.memorias.isNotEmpty) '(${pc.memorias.map((m) => m.texto).join(' + ')})',
    ].whereType<String>().join(' ');
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Editar'),
            ),
            OutlinedButton.icon(
              onPressed: onRelevar,
              icon: relevando
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 20),
              label: Text(relevando ? 'Relevando…' : 'Volver a relevar'),
            ),
          ],
        ),
        if (relevando)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Consultando el equipo por la red. Puede tardar hasta un minuto.',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        if (resultado != null) _AvisoRelevamiento(resultado!),
        if (siguiendo)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pc.estado == EstadoPc.relevando
                        ? 'Relevando en ${pc.relevandoPor ?? 'el validador'}…'
                        : 'En cola: esperando que el validador de adentro de la red la tome…',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        if (sinValidador && pc.estado.enCurso)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No hay ningún validador activo dentro de la red: la PC va a quedar en cola hasta que se inicie uno.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: (tema.extension<ColoresEstado>() ?? ColoresEstado.claro).alerta),
            ),
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
                [d.marca, if (d.capacidadGb != null) '${gbTexto(d.capacidadGb!)} GB', d.bus]
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

/// Resultado de volver a relevar, dentro de la hoja (un aviso inferior quedaría tapado por la hoja).
class _AvisoRelevamiento extends StatelessWidget {
  const _AvisoRelevamiento(this.resultado);

  final ResultadoRelevamiento resultado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.extension<ColoresEstado>() ?? ColoresEstado.claro;
    final (icono, color, fondo, titulo) = resultado.enCola
        ? (Icons.schedule, c.neutro, c.neutroFondo, 'En cola del validador')
        : resultado.ok
            ? (Icons.check_circle, c.ok, c.okFondo, 'Relevamiento completo')
            : (Icons.warning_amber_rounded, c.alerta, c.alertaFondo, 'No se pudo relevar');
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tema.textTheme.titleSmall?.copyWith(color: color)),
                const SizedBox(height: 2),
                Text(resultado.detalle, style: tema.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
