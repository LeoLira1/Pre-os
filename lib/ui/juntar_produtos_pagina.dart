import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../core/generico.dart';
import '../core/grupos.dart';
import '../dados/estado_app.dart';
import '../modelos/modelos.dart';

class JuntarProdutosPagina extends StatefulWidget {
  const JuntarProdutosPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<JuntarProdutosPagina> createState() => _JuntarProdutosPaginaState();
}

class _JuntarProdutosPaginaState extends State<JuntarProdutosPagina> {
  bool _ocupado = false;

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir: $erro')),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _aceitarFortes(List<SugestaoGrupo> sugestoes) async {
    final fortes = sugestoes.where((s) => s.forca == ForcaSugestao.forte).toList();
    await _executar(() async {
      for (final sugestao in fortes) {
        await widget.estado.aceitarSugestao(sugestao);
      }
    });
  }

  /// Aceita de uma vez todas as junções genéricas que não são de
  /// concentrado. O concentrado continua sendo aceito um a um, porque o
  /// rendimento é diferente.
  Future<void> _aceitarGenericasComuns(List<SugestaoGenerica> genericas) async {
    final comuns = genericas.where((g) => !g.concentrado).toList();
    await _executar(() => widget.estado.aceitarSugestoesGenericas(comuns));
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes = widget.estado.sugestoesPendentes;
    final genericas = widget.estado.sugestoesGenericas;
    final fortes = sugestoes.where((s) => s.forca == ForcaSugestao.forte).length;
    final comuns = genericas.where((g) => !g.concentrado).length;
    final total = sugestoes.length + genericas.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Juntar produtos', style: Theme.of(context).textTheme.headlineSmall),
                    Text('$total sugestão${total == 1 ? '' : 'ões'} pendente${total == 1 ? '' : 's'}'),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _ocupado || fortes == 0 ? null : () => _aceitarFortes(sugestoes),
                icon: const Icon(Icons.done_all),
                label: Text('Aceitar fortes ($fortes)'),
              ),
            ],
          ),
        ),
        if (_ocupado) const LinearProgressIndicator(),
        Expanded(
          child: total == 0
              ? const Center(child: Text('Nenhuma sugestão pendente.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  children: [
                    if (genericas.isNotEmpty) ...[
                      _TituloSecao(
                        titulo: 'Comparar entre marcas',
                        detalhe:
                            'Mesmo produto, marcas e embalagens diferentes, '
                            'mesma unidade de comparação.',
                        acao: comuns < 2
                            ? null
                            : FilledButton.tonalIcon(
                                onPressed: _ocupado
                                    ? null
                                    : () => _aceitarGenericasComuns(genericas),
                                icon: const Icon(Icons.done_all),
                                label: Text('Aceitar todas ($comuns)'),
                              ),
                      ),
                      for (final generica in genericas)
                        _CartaoGenerica(
                          estado: widget.estado,
                          sugestao: generica,
                          ocupado: _ocupado,
                          juntar: () => _executar(
                            () => widget.estado
                                .aceitarSugestaoGenerica(generica),
                          ),
                          rejeitar: () => _executar(
                            () => widget.estado
                                .rejeitarSugestaoGenerica(generica),
                          ),
                        ),
                    ],
                    if (sugestoes.isNotEmpty) ...[
                      const _TituloSecao(
                        titulo: 'Mesmo produto, nomes diferentes',
                        detalhe: 'Produtos que parecem ser o mesmo item.',
                      ),
                      for (final sugestao in sugestoes)
                        _CartaoSugestao(
                          estado: widget.estado,
                          sugestao: sugestao,
                          ocupado: _ocupado,
                          juntar: () => _executar(
                            () => widget.estado.aceitarSugestao(sugestao),
                          ),
                          rejeitar: () => _executar(
                            () => widget.estado.rejeitarSugestao(sugestao),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao({required this.titulo, required this.detalhe, this.acao});

  final String titulo;
  final String detalhe;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  detalhe,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cores.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (acao != null) ...[const SizedBox(width: 8), acao!],
        ],
      ),
    );
  }
}

/// Sugestão de juntar vários grupos de marcas diferentes num grupo genérico.
class _CartaoGenerica extends StatelessWidget {
  const _CartaoGenerica({
    required this.estado,
    required this.sugestao,
    required this.ocupado,
    required this.juntar,
    required this.rejeitar,
  });

  final EstadoApp estado;
  final SugestaoGenerica sugestao;
  final bool ocupado;
  final VoidCallback juntar;
  final VoidCallback rejeitar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                const Chip(
                  avatar: Icon(Icons.compare_arrows, size: 18),
                  label: Text('Genérica'),
                ),
                Chip(
                  avatar: const Icon(Icons.straighten, size: 18),
                  label: Text('por ${sugestao.unidadeRef}'),
                ),
                if (sugestao.concentrado)
                  Chip(
                    avatar: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Concentrado'),
                    backgroundColor: cores.errorContainer,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              sugestao.nomeGenerico,
              style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '${sugestao.grupos.length} grupos viram um só',
              style: textos.bodySmall?.copyWith(color: cores.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final grupo in sugestao.grupos)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4, right: 6),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    Expanded(child: Text(grupo.nomeParaMostrar)),
                    Text(
                      _menorPreco(grupo.id),
                      style: textos.bodySmall
                          ?.copyWith(color: cores.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            if (sugestao.concentrado) ...[
              const SizedBox(height: 10),
              Text(
                'Atenção: produto concentrado rende diferente do comum. Ele '
                'nunca entra sozinho no grupo genérico do comum.',
                style: TextStyle(
                  color: cores.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: ocupado ? null : rejeitar,
                  child: const Text('Não são iguais'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: ocupado ? null : juntar,
                  child: const Text('Juntar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// O menor preço de referência já registrado para este grupo.
  String _menorPreco(int grupoId) {
    final precos = estado.precosDoGrupo(grupoId);
    if (precos.isEmpty) return 'sem preço';
    var menor = precos.first;
    for (final preco in precos) {
      if (preco.valorComparavel < menor.valorComparavel) menor = preco;
    }
    return formatarPrecoRef(
      menor.valorComparavel,
      menor.precoRef == null ? null : menor.unidadeRef,
    );
  }
}

class _CartaoSugestao extends StatelessWidget {
  const _CartaoSugestao({
    required this.estado,
    required this.sugestao,
    required this.ocupado,
    required this.juntar,
    required this.rejeitar,
  });

  final EstadoApp estado;
  final SugestaoGrupo sugestao;
  final bool ocupado;
  final VoidCallback juntar;
  final VoidCallback rejeitar;

  @override
  Widget build(BuildContext context) {
    final precoProduto = _ultimo(estado.precosDoProduto(sugestao.produto.id));
    final precoGrupo = _ultimo(estado.precosDoGrupo(sugestao.grupo.id));
    final forte = sugestao.forca == ForcaSugestao.forte;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(
                      forte ? Icons.verified_outlined : Icons.help_outline,
                      size: 18),
                  label: Text(forte ? 'Forte' : 'Possível'),
                ),
                if (sugestao.generica)
                  const Chip(
                    avatar: Icon(Icons.compare_arrows, size: 18),
                    label: Text('Genérica'),
                  ),
              ],
            ),
            if (sugestao.parteDoNome != null)
              Text('Parte reconhecida: ${sugestao.parteDoNome}'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Lado(nome: sugestao.produto.nome, preco: precoProduto, estado: estado)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                  child: Icon(Icons.compare_arrows),
                ),
                Expanded(child: _Lado(nome: sugestao.grupo.nomeParaMostrar, preco: precoGrupo, estado: estado)),
              ],
            ),
            if (sugestao.atributosDiferentes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Atenção: ${sugestao.atributosDiferentes.join(' × ')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: ocupado ? null : rejeitar, child: const Text('Não são iguais')),
                const SizedBox(width: 8),
                FilledButton(onPressed: ocupado ? null : juntar, child: const Text('Juntar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Preco? _ultimo(List<Preco> precos) => precos.isEmpty ? null : precos.last;
}

class _Lado extends StatelessWidget {
  const _Lado({required this.nome, required this.preco, required this.estado});
  final String nome;
  final Preco? preco;
  final EstadoApp estado;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nome, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (preco != null) ...[
            Text(nomeCurtoLoja(estado.nomeDaLoja(preco!.lojaId))),
            Text(formatarPrecoRef(preco!.valorComparavel, preco!.precoRef == null ? null : preco!.unidadeRef)),
          ],
        ],
      );
}
