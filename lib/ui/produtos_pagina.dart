import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../dados/estado_app.dart';
import 'produto_pagina.dart';

/// Tela inicial: busca, filtro por categoria e lista de produtos.
class ProdutosPagina extends StatefulWidget {
  const ProdutosPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<ProdutosPagina> createState() => _ProdutosPaginaState();
}

class _ProdutosPaginaState extends State<ProdutosPagina> {
  final TextEditingController _busca = TextEditingController();
  String? _categoria;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _sincronizar() async {
    try {
      await widget.estado.sincronizar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados atualizados.')),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel sincronizar: $erro'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final categorias = estado.categorias;
    final produtos = estado.produtosFiltrados(
      busca: _busca.text,
      categoria: _categoria,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Produtos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Sincronizar',
                onPressed: estado.sincronizando ? null : _sincronizar,
                icon: estado.sincronizando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou marca',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busca.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _busca.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        if (categorias.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Todas'),
                    selected: _categoria == null,
                    onSelected: (_) => setState(() => _categoria = null),
                  ),
                ),
                for (final categoria in categorias)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(categoria),
                      selected: _categoria == categoria,
                      onSelected: (marcada) => setState(
                        () => _categoria = marcada ? categoria : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: produtos.isEmpty
              ? _Vazio(estado: estado, filtrando: _temFiltro)
              : RefreshIndicator(
                  onRefresh: _sincronizar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    itemCount: produtos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, indice) {
                      final item = produtos[indice];
                      return _CartaoProduto(
                        resumo: item,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProdutoPagina(
                              estado: estado,
                              produtoId: item.produto.id,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  bool get _temFiltro => _busca.text.isNotEmpty || _categoria != null;
}

class _CartaoProduto extends StatelessWidget {
  const _CartaoProduto({required this.resumo, required this.onTap});

  final ProdutoResumo resumo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final produto = resumo.produto;
    final estatisticas = resumo.estatisticas;
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final detalhe = descreverProduto(
      marca: produto.marca,
      embalagemQtd: produto.embalagemQtd,
      embalagemUnidade: produto.embalagemUnidade,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produto.nome,
                      style: textos.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (detalhe.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detalhe,
                        style: textos.bodySmall
                            ?.copyWith(color: cores.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      formatarData(estatisticas.dataUltimo),
                      style: textos.labelSmall
                          ?.copyWith(color: cores.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatarMoeda(resumo.ultimoRegistro?.preco),
                    style: textos.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cores.primary,
                    ),
                  ),
                  if (estatisticas.unidadeRef != null)
                    Text(
                      formatarPrecoRef(
                        estatisticas.ultimo,
                        estatisticas.unidadeRef,
                      ),
                      style: textos.bodySmall
                          ?.copyWith(color: cores.onSurfaceVariant),
                    ),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.estado, required this.filtrando});

  final EstadoApp estado;
  final bool filtrando;

  @override
  Widget build(BuildContext context) {
    final String titulo;
    final String texto;
    if (filtrando) {
      titulo = 'Nenhum produto encontrado';
      texto = 'Tente outro termo de busca ou toque em "Todas" nas categorias.';
    } else if (!estado.temCredenciais) {
      titulo = 'Falta configurar o banco';
      texto = 'Va em Configuracao, informe a URL e o token do Turso e toque '
          'em "Testar conexao".';
    } else if (!estado.temDados) {
      titulo = 'Nenhum produto ainda';
      texto = 'Toque em Importar para carregar seu primeiro arquivo CSV, ou '
          'em Sincronizar para baixar o que ja esta no Turso.';
    } else {
      titulo = 'Nada para mostrar';
      texto = 'Ajuste os filtros.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
