import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../api/api_scope.dart';

/// Alta de un área: solo el nombre.
class CargarAreaScreen extends StatefulWidget {
  const CargarAreaScreen({super.key});

  @override
  State<CargarAreaScreen> createState() => _CargarAreaScreenState();
}

class _CargarAreaScreenState extends State<CargarAreaScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _foco = FocusNode();

  bool _guardando = false;
  bool _intentado = false;
  String? _errorNombre;
  String? _errorGeneral;

  @override
  void dispose() {
    _nombre.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _intentado = true;
      _errorNombre = null;
      _errorGeneral = null;
    });
    if (!_form.currentState!.validate()) return;

    final nombre = _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    setState(() => _guardando = true);
    try {
      await ApiScope.of(context).crearArea(nombre);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Área $nombre agregada.')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        if (e.esDuplicado) {
          _errorNombre = 'Ya existe un área con ese nombre.';
          _foco.requestFocus();
        } else {
          _errorGeneral = e.mensaje;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar área')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              autovalidateMode: _intentado ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  TextFormField(
                    controller: _nombre,
                    focusNode: _foco,
                    autofocus: true,
                    enabled: !_guardando,
                    decoration: InputDecoration(
                      labelText: 'Nombre Área',
                      hintText: '[NOMBRE ÁREA]',
                      errorText: _errorNombre,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    onChanged: (_) {
                      if (_errorNombre != null) setState(() => _errorNombre = null);
                    },
                    onFieldSubmitted: (_) => _guardar(),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresá el nombre del área.' : null,
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
        ),
      ),
    );
  }
}
