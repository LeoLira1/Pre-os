import 'package:flutter/material.dart';

import '../core/comparacao_lojas.dart';
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
  int? _lojaId;

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
    final lojas = estado.lojas;
    final produtos = estado.produtosFiltrados(
      busca: _busca.text,
      categoria: _categoria,
      lojaId: _lojaId,
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
        if (lojas.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('Todas as lojas'),
                    selected: _lojaId == null,
                    onSelected: (_) => setState(() => _lojaId = null),
                  ),
                ),
                for (final loja in lojas)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(nomeCurtoLoja(loja.nome)),
                      selected: _lojaId == loja.id,
                      onSelected: (marcada) => setState(
                        () => _lojaId = marcada ? loja.id : null,
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
                              grupoId: item.grupo.id,
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

  bool get _temFiltro =>
      _busca.text.isNotEmpty || _categoria != null || _lojaId != null;
}

class _CartaoProduto extends StatelessWidget {
  const _CartaoProduto({required this.resumo, required this.onTap});

  final GrupoResumo resumo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grupo = resumo.grupo;
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final detalhe = '${resumo.produtos.length} produto${resumo.produtos.length == 1 ? '' : 's'} vinculado${resumo.produtos.length == 1 ? '' : 's'}';
    final barata = resumo.maisBarata;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grupo.nome,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // O preco grande e o da loja mais barata.
                      Text(
                        formatarMoeda(barata?.preco),
                        style: textos.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cores.primary,
                        ),
                      ),
                      if (barata?.precoRef != null)
                        Text(
                          formatarPrecoRef(
                            barata!.precoRef,
                            barata.unidadeRef,
                          ),
                          style: textos.bodySmall
                              ?.copyWith(color: cores.onSurfaceVariant),
                        ),
                    ],
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              if (resumo.temVariasLojas)
                _ListaDeLojas(lojas: resumo.porLoja)
              else if (barata != null)
                // Preco em uma loja so: basta dizer qual e.
                Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 14,
                      color: cores.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            barata.nomeLoja,
                            style: textos.bodySmall
                                ?.copyWith(color: cores.onSurfaceVariant),
                          ),
                          if ((barata.nomeProduto ?? '').isNotEmpty)
                            Text(
                              barata.nomeProduto!,
                              style: textos.labelSmall
                                  ?.copyWith(color: cores.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      formatarData(barata.data),
                      style: textos.labelSmall
                          ?.copyWith(color: cores.onSurfaceVariant),
                    ),
                  ],
                )
              else
                Text(
                  'Sem preco registrado',
                  style: textos.bodySmall
                      ?.copyWith(color: cores.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uma linha por loja, da mais barata para a mais cara.
class _ListaDeLojas extends StatelessWidget {
  const _ListaDeLojas({required this.lojas});

  final List<PrecoNaLoja> lojas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    // Verde que funciona tanto no tema claro quanto no escuro.
    final verde = Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade700;

    return Column(
      children: [
        for (var i = 0; i < lojas.length; i++)
          Builder(
            builder: (context) {
              final loja = lojas[i];
              final ehMaisBarata = i == 0;
              final antiga = estaDesatualizada(loja, lojas);
              final cor = ehMaisBarata ? verde : cores.onSurfaceVariant;

              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: ehMaisBarata
                      ? verde.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ehMaisBarata
                        ? verde.withValues(alpha: 0.35)
                        : cores.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            loja.nomeLoja,
                            style: textos.bodySmall?.copyWith(
                              color: cor,
                              fontWeight: ehMaisBarata
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (ehMaisBarata)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: verde.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'mais barato',
                                style: textos.labelSmall?.copyWith(
                                  color: verde,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          // So marca a data quando a loja esta com preco
                          // mais velho que o das outras.
                          if (antiga)
                            Text(
                              formatarData(loja.data),
                              style: textos.labelSmall?.copyWith(
                                color: cores.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatarMoeda(loja.preco),
                          style: textos.bodySmall?.copyWith(
                            color: cor,
                            fontWeight: ehMaisBarata
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        if (loja.precoRef != null)
                          Text(
                            formatarPrecoRef(loja.precoRef, loja.unidadeRef),
                            style: textos.labelSmall
                                ?.copyWith(color: cores.onSurfaceVariant),
                          ),
                        if ((loja.nomeProduto ?? '').isNotEmpty)
                          Text(
                            loja.nomeProduto!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textos.labelSmall
                                ?.copyWith(color: cores.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
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
