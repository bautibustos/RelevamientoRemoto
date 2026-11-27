import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';

import 'api/api_client.dart';
import 'api/api_demo.dart';
import 'api/api_scope.dart';
import 'config.dart';
import 'rutas.dart' show generarRuta;
import 'theme.dart';

const _demo = bool.fromEnvironment('DEMO');

void main() {
  final api = _demo
      ? ApiClient(baseUrl: 'http://demo/api/v1', client: clienteDemo())
      : ApiClient(baseUrl: apiBaseUrl());
  runApp(InventarioApp(api: api));
}

class InventarioApp extends StatelessWidget {
  const InventarioApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ApiScope(
      client: api,
      child: MaterialApp(
        title: 'Inventario',
        debugShowCheckedModeBanner: false,
        theme: temaClaro,
        darkTheme: temaOscuro,
        onGenerateRoute: generarRuta,
        // en la compu también se puede arrastrar la lista con el mouse (para "arrastrar y actualizar")
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {...PointerDeviceKind.values},
        ),
      ),
    );
  }
}
