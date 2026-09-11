import 'package:flutter/material.dart';

import '../core/formato.dart';
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

  @override
  Widget build(BuildContext context) {
    final sugestoes = widget.estado.sugestoesPendentes;
    final fortes = sugestoes.where((s) => s.forca == ForcaSugestao.forte).length;
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
                    Text('${sugestoes.length} sugestão${sugestoes.length == 1 ? '' : 'ões'} pendente${sugestoes.length == 1 ? '' : 's'}'),
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
          child: sugestoes.isEmpty
              ? const Center(child: Text('Nenhuma sugestão pendente.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: sugestoes.length,
                  itemBuilder: (context, indice) {
                    final sugestao = sugestoes[indice];
                    return _CartaoSugestao(
                      estado: widget.estado,
                      sugestao: sugestao,
                      ocupado: _ocupado,
                      juntar: () => _executar(
                        () => widget.estado.aceitarSugestao(sugestao),
                      ),
                      rejeitar: () => _executar(
                        () => widget.estado.rejeitarSugestao(sugestao),
                      ),
                    );
                  },
                ),
        ),
      ],
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
            Chip(
              avatar: Icon(forte ? Icons.verified_outlined : Icons.help_outline, size: 18),
              label: Text(forte ? 'Forte' : 'Possível'),
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
                Expanded(child: _Lado(nome: sugestao.grupo.nome, preco: precoGrupo, estado: estado)),
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
