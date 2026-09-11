import 'dart:io';

import 'package:flutter/material.dart';

/// Abre a foto em tela cheia, com zoom de dois dedos.
///
/// Serve para conferir os centavos em fonte pequena sem sair do app.
Future<void> abrirFotoTelaCheia(BuildContext context, File arquivo) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FotoTelaCheia(arquivo: arquivo),
    ),
  );
}

class _FotoTelaCheia extends StatelessWidget {
  const _FotoTelaCheia({required this.arquivo});

  final File arquivo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto do tabloide'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 8,
          child: Image.file(
            arquivo,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text(
              'Nao consegui abrir esta foto.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
