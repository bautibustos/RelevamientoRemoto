import 'package:material_ui/material_ui.dart';

import 'api_client.dart';

/// Hace disponible el [ApiClient] a todas las pantallas (y permite reemplazarlo en pruebas).
class ApiScope extends InheritedWidget {
  const ApiScope({super.key, required this.client, required super.child});

  final ApiClient client;

  static ApiClient of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ApiScope>();
    assert(scope != null, 'Falta un ApiScope arriba en el árbol de widgets.');
    return scope!.client;
  }

  @override
  bool updateShouldNotify(ApiScope oldWidget) => client != oldWidget.client;
}
