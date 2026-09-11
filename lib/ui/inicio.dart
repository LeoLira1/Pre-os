import 'package:flutter/material.dart';

import '../dados/estado_app.dart';
import 'configuracao_pagina.dart';
import 'importar_hub_pagina.dart';
import 'produtos_pagina.dart';

/// Casca do aplicativo com as tres abas: Produtos, Importar e Configuracao.
class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        final paginas = <Widget>[
          ProdutosPagina(estado: widget.estado),
          ImportarHubPagina(estado: widget.estado),
          ConfiguracaoPagina(estado: widget.estado),
        ];
        return Scaffold(
          body: SafeArea(child: paginas[_aba]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _aba,
            onDestinationSelected: (indice) => setState(() => _aba = indice),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shopping_basket_outlined),
                selectedIcon: Icon(Icons.shopping_basket),
                label: 'Produtos',
              ),
              NavigationDestination(
                icon: Icon(Icons.upload_file_outlined),
                selectedIcon: Icon(Icons.upload_file),
                label: 'Importar',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Configuracao',
              ),
            ],
          ),
        );
      },
    );
  }
}
