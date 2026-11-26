import 'package:material_ui/material_ui.dart';

/// Paleta neutra (grises con leve tinte frío) y un único acento petróleo.
abstract final class Paleta {
  static const acento = Color(0xFF0F6E7A); // 5,9:1 sobre blanco
  static const acentoOscuro = Color(0xFF5CC3CF);

  static const fondo = Color(0xFFF4F6F7);
  static const superficie = Color(0xFFFFFFFF);
  static const texto = Color(0xFF17232B);
  static const textoSecundario = Color(0xFF51616A); // 6,2:1 sobre blanco
  static const borde = Color(0xFFC5D0D6);

  static const fondoOscuro = Color(0xFF11181D);
  static const superficieOscura = Color(0xFF182229);
  static const textoOscuro = Color(0xFFE3EAEE);
  static const textoSecundarioOscuro = Color(0xFF9DADB6);
  static const bordeOscuro = Color(0xFF34444F);
}

/// Colores de estado (no son el acento: indican el resultado del relevamiento).
class ColoresEstado extends ThemeExtension<ColoresEstado> {
  const ColoresEstado({
    required this.ok,
    required this.okFondo,
    required this.alerta,
    required this.alertaFondo,
    required this.error,
    required this.errorFondo,
    required this.neutro,
    required this.neutroFondo,
  });

  final Color ok, okFondo, alerta, alertaFondo, error, errorFondo, neutro, neutroFondo;

  static const claro = ColoresEstado(
    ok: Color(0xFF256B3E), okFondo: Color(0xFFE2F1E7),
    alerta: Color(0xFF7D5508), alertaFondo: Color(0xFFF7ECD5),
    error: Color(0xFFA3262A), errorFondo: Color(0xFFF8E3E3),
    neutro: Color(0xFF4F5D66), neutroFondo: Color(0xFFE8ECEE),
  );

  static const oscuro = ColoresEstado(
    ok: Color(0xFF7FD69C), okFondo: Color(0xFF173023),
    alerta: Color(0xFFE6BA62), alertaFondo: Color(0xFF33290F),
    error: Color(0xFFF19A9C), errorFondo: Color(0xFF3A1C1D),
    neutro: Color(0xFFB4C0C7), neutroFondo: Color(0xFF26323A),
  );

  @override
  ColoresEstado copyWith() => this;

  @override
  ColoresEstado lerp(ColoresEstado? other, double t) => t < 0.5 ? this : (other ?? this);
}

ThemeData _tema({
  required Brightness brillo,
  required Color acento,
  required Color fondo,
  required Color superficie,
  required Color texto,
  required Color textoSecundario,
  required Color borde,
  required ColoresEstado estados,
}) {
  final esquema = ColorScheme.fromSeed(
    seedColor: Paleta.acento,
    brightness: brillo,
    primary: acento,
    onPrimary: brillo == Brightness.light ? Colors.white : const Color(0xFF00363C),
    surface: superficie,
    onSurface: texto,
    onSurfaceVariant: textoSecundario,
    outline: borde,
    outlineVariant: borde,
    error: estados.error,
  );

  const radio = BorderRadius.all(Radius.circular(8));
  OutlineInputBorder bordeInput(Color color, [double ancho = 1]) =>
      OutlineInputBorder(borderRadius: radio, borderSide: BorderSide(color: color, width: ancho));

  return ThemeData(
    colorScheme: esquema,
    scaffoldBackgroundColor: fondo,
    extensions: [estados],
    appBarTheme: AppBarTheme(
      backgroundColor: superficie,
      foregroundColor: texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: borde)),
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: texto),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: superficie, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(color: textoSecundario, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: textoSecundario),
      border: bordeInput(borde),
      enabledBorder: bordeInput(borde),
      focusedBorder: bordeInput(acento, 2),
      errorBorder: bordeInput(estados.error),
      focusedErrorBorder: bordeInput(estados.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const RoundedRectangleBorder(borderRadius: radio),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: texto,
        side: BorderSide(color: borde),
        shape: const RoundedRectangleBorder(borderRadius: radio),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: acento,
      foregroundColor: esquema.onPrimary,
      extendedTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

final temaClaro = _tema(
  brillo: Brightness.light,
  acento: Paleta.acento,
  fondo: Paleta.fondo,
  superficie: Paleta.superficie,
  texto: Paleta.texto,
  textoSecundario: Paleta.textoSecundario,
  borde: Paleta.borde,
  estados: ColoresEstado.claro,
);

final temaOscuro = _tema(
  brillo: Brightness.dark,
  acento: Paleta.acentoOscuro,
  fondo: Paleta.fondoOscuro,
  superficie: Paleta.superficieOscura,
  texto: Paleta.textoOscuro,
  textoSecundario: Paleta.textoSecundarioOscuro,
  borde: Paleta.bordeOscuro,
  estados: ColoresEstado.oscuro,
);
