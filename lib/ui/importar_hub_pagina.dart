import 'package:flutter/material.dart';

import '../dados/estado_app.dart';
import 'importar_fotos_pagina.dart';
import 'importar_pagina.dart';

/// Aba de importacao: fotos do tabloide (o caminho principal) ou arquivo CSV.
class ImportarHubPagina extends StatefulWidget {
  const ImportarHubPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<ImportarHubPagina> createState() => _ImportarHubPaginaState();
}

class _ImportarHubPaginaState extends State<ImportarHubPagina> {
  bool _porFoto = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Fotos'),
                icon: Icon(Icons.photo_camera_outlined),
              ),
              ButtonSegment(
                value: false,
                label: Text('CSV'),
                icon: Icon(Icons.table_chart_outlined),
              ),
            ],
            selected: {_porFoto},
            onSelectionChanged: (escolha) =>
                setState(() => _porFoto = escolha.first),
          ),
        ),
        Expanded(
          child: _porFoto
              ? ImportarFotosPagina(estado: widget.estado)
              : ImportarPagina(estado: widget.estado),
        ),
      ],
    );
  }
}
