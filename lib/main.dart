import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'dados/estado_app.dart';
import 'ui/inicio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final estado = EstadoApp();
  await estado.iniciar();
  runApp(AplicativoPrecos(estado: estado));
}

class AplicativoPrecos extends StatelessWidget {
  const AplicativoPrecos({super.key, required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Precos de Mercado',
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      // Acompanha o tema claro/escuro do sistema.
      themeMode: ThemeMode.system,
      home: TelaInicio(estado: estado),
    );
  }

  ThemeData _tema(Brightness brilho) {
    final esquema = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00695C),
      brightness: brilho,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
