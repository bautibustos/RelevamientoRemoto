/// URL base de la API.
///
/// Se puede fijar al compilar: `flutter run --dart-define=API_URL=http://servidor:8000/api/v1`.
/// Si no se indica, se usa el mismo equipo que sirve la app, en el puerto 8000. Así,
/// abriendo la app desde el celular con la IP de la PC, también encuentra la API.
String apiBaseUrl() {
  const definida = String.fromEnvironment('API_URL');
  if (definida.isNotEmpty) return definida;
  final base = Uri.base;
  final host = base.host.isEmpty ? '127.0.0.1' : base.host;
  return Uri(scheme: 'http', host: host, port: 8000, path: '/api/v1').toString();
}
