import 'package:flutter/material.dart';

import '../core/comparacao_lojas.dart';
import '../core/formato.dart';
import '../dados/estado_app.dart';
import '../modelos/modelos.dart';
import 'widgets/grafico_precos.dart';

/// Tela de um produto: cabecalho, numeros, grafico e historico.
class ProdutoPagina extends StatelessWidget {
  const ProdutoPagina({
    super.key,
    required this.estado,
    required this.grupoId,
  });

  final EstadoApp estado;
  final int grupoId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final grupo = estado.grupoPorId(grupoId);
        if (grupo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Produto')),
            body: const Center(
              child: Text('Este produto não está mais no cache local.'),
            ),
          );
        }

        final produtos = estado.produtosDoGrupo(grupoId);
        final precos = estado.precosDoGrupo(grupoId);
        final estatisticas = EstatisticasProduto.calcular(precos);
        final historico = precos.reversed.toList();

        return Scaffold(
          appBar: AppBar(title: Text(grupo.nome)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Cabecalho(grupo: grupo, produtos: produtos),
              const SizedBox(height: 12),
              _ProdutosDoGrupo(
                estado: estado,
                grupo: grupo,
                produtos: produtos,
              ),
              const SizedBox(height: 16),
              _Numeros(
                estatisticas: estatisticas,
                porLoja: compararLojas(
                  precos: precos,
                  nomeDaLoja: estado.nomeDaLoja,
                  nomeDoProduto: (id) =>
                      estado.produtoPorId(id)?.nome ?? 'Produto $id',
                ),
                nomeCurtoDaLoja: (id) =>
                    nomeCurtoLoja(estado.nomeDaLoja(id)),
              ),
              const SizedBox(height: 24),
              Text(
                'Histórico de preço',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (estatisticas.usandoPrecoRef)
                Text(
                  'Valores por ${estatisticas.unidadeRef ?? 'unidade de referência'}.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Text(
                  'Sem preço de referência: mostrando o preço cheio.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              GraficoPrecos(
                precos: precos,
                unidadeRef: estatisticas.unidadeRef,
                nomeDaLoja: estado.nomeDaLoja,
              ),
              const SizedBox(height: 24),
              Text(
                'Registros (${historico.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (historico.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum registro de preço para este produto.'),
                  ),
                )
              else
                for (final preco in historico)
                  _ItemHistorico(
                    preco: preco,
                    loja: nomeCurtoLoja(estado.nomeDaLoja(preco.lojaId)),
                    produto: estado.produtoPorId(preco.produtoId)?.nome,
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.grupo, required this.produtos});

  final Grupo grupo;
  final List<Produto> produtos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final linhas = <String>[
      if ((grupo.unidadeRef ?? '').trim().isNotEmpty)
        'Unidade de comparação: ${grupo.unidadeRef}',
      '${produtos.length} produto${produtos.length == 1 ? '' : 's'} neste grupo',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              grupo.nome,
              style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if ((grupo.categoria ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(grupo.categoria!),
                visualDensity: VisualDensity.compact,
              ),
            ],
            if (linhas.isNotEmpty) const SizedBox(height: 8),
            for (final linha in linhas)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  linha,
                  style:
                      textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProdutosDoGrupo extends StatelessWidget {
  const _ProdutosDoGrupo({
    required this.estado,
    required this.grupo,
    required this.produtos,
  });

  final EstadoApp estado;
  final Grupo grupo;
  final List<Produto> produtos;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Produtos vinculados',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Renomear grupo',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _renomear(context),
                ),
              ],
            ),
            for (final produto in produtos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(produto.nome),
                subtitle: Text([
                  if ((produto.marca ?? '').isNotEmpty) produto.marca!,
                  if (estado.gruposDoProduto(produto.id).length > 1)
                    '${estado.gruposDoProduto(produto.id).length} grupos',
                ].join(' · ')),
                trailing: PopupMenuButton<String>(
                  onSelected: (acao) {
                    if (acao == 'juntar') _juntar(context, produto);
                    if (acao == 'separar') _separar(context, produto);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'juntar',
                      child: Text('Juntar com outro produto'),
                    ),
                    PopupMenuItem(
                      value: 'separar',
                      child: Text('Separar deste grupo'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _renomear(BuildContext context) async {
    final controle = TextEditingController(text: grupo.nome);
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear produto base'),
        content: TextField(controller: controle, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controle.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controle.dispose();
    if (nome == null || nome.trim().isEmpty || !context.mounted) return;
    await _executar(context, () => estado.renomearGrupo(grupo.id, nome));
  }

  Future<void> _juntar(BuildContext context, Produto produto) async {
    var busca = '';
    final escolhido = await showDialog<Produto>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final termo = busca.toLowerCase().trim();
          final candidatos = estado.produtos
              .where((p) => p.id != produto.id &&
                  (termo.isEmpty || p.nome.toLowerCase().contains(termo)))
              .take(20)
              .toList();
          return AlertDialog(
            title: const Text('Juntar com outro produto'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar em todas as lojas',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (valor) => setState(() => busca = valor),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final candidato in candidatos)
                          ListTile(
                            title: Text(candidato.nome),
                            subtitle: Text(
                              estado.gruposDoProduto(candidato.id)
                                  .map((g) => g.nome)
                                  .join(', '),
                            ),
                            onTap: () => Navigator.pop(context, candidato),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ],
          );
        },
      ),
    );
    if (escolhido == null || !context.mounted) return;
    final destinos = estado.gruposDoProduto(escolhido.id);
    if (destinos.isEmpty) return;
    await _executar(context, () => estado.juntarManual(produto.id, destinos.first.id));
  }

  Future<void> _separar(BuildContext context, Produto produto) async {
    await _executar(context, () => estado.separarDoGrupo(produto.id, grupo.id));
  }

  Future<void> _executar(
    BuildContext context,
    Future<void> Function() acao,
  ) async {
    try {
      await acao();
    } catch (erro) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$erro')));
    }
  }
}

class _Numeros extends StatelessWidget {
  const _Numeros({
    required this.estatisticas,
    required this.porLoja,
    required this.nomeCurtoDaLoja,
  });

  final EstatisticasProduto estatisticas;

  /// Ultimo preco em cada loja, da mais barata para a mais cara.
  final List<PrecoNaLoja> porLoja;
  final String Function(int lojaId) nomeCurtoDaLoja;

  @override
  Widget build(BuildContext context) {
    final unidade = estatisticas.unidadeRef;
    final cores = Theme.of(context).colorScheme;
    final verde = Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade700;
    final barata = porLoja.isEmpty ? null : porLoja.first;

    final cartoes = <Widget>[
      // Onde comprar agora, que e o que interessa na hora da compra.
      _Cartao(
        titulo: 'Mais barato hoje',
        valor: barata == null
            ? '--'
            : formatarPrecoRef(barata.precoRef ?? barata.preco,
                barata.precoRef == null ? null : barata.unidadeRef),
        rodape: barata?.nomeLoja,
        cor: verde,
      ),
      _Cartao(
        titulo: 'Menor',
        valor: formatarPrecoRef(estatisticas.menor, unidade),
        rodape: estatisticas.lojaIdMenor == null
            ? null
            : nomeCurtoDaLoja(estatisticas.lojaIdMenor!),
        cor: cores.tertiary,
      ),
      _Cartao(
        titulo: 'Maior',
        valor: formatarPrecoRef(estatisticas.maior, unidade),
        rodape: estatisticas.lojaIdMaior == null
            ? null
            : nomeCurtoDaLoja(estatisticas.lojaIdMaior!),
        cor: cores.error,
      ),
      _Cartao(
        titulo: 'Média',
        valor: formatarPrecoRef(estatisticas.media, unidade),
        cor: cores.secondary,
      ),
      _Cartao(
        titulo: 'Registros',
        valor: '${estatisticas.registros}',
        cor: cores.onSurfaceVariant,
      ),
    ];

    return LayoutBuilder(
      builder: (context, restricoes) {
        // Duas colunas no celular, tres quando houver espaco.
        final colunas = restricoes.maxWidth >= 520 ? 3 : 2;
        const espaco = 12.0;
        final largura =
            (restricoes.maxWidth - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final cartao in cartoes)
              SizedBox(width: largura, child: cartao),
          ],
        );
      },
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.titulo,
    required this.valor,
    required this.cor,
    this.rodape,
  });

  final String titulo;
  final String valor;
  final Color cor;

  /// Linha pequena embaixo do valor, usada para o nome da loja.
  final String? rodape;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valor,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cor,
                    ),
              ),
            ),
            if (rodape != null && rodape!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                rodape!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemHistorico extends StatelessWidget {
  const _ItemHistorico({
    required this.preco,
    required this.loja,
    this.produto,
  });

  final Preco preco;
  final String loja;
  final String? produto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                        formatarData(preco.data),
                        style: textos.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loja,
                        style: textos.bodySmall
                            ?.copyWith(color: cores.onSurfaceVariant),
                      ),
                      if ((produto ?? '').isNotEmpty)
                        Text(
                          produto!,
                          style: textos.labelSmall
                              ?.copyWith(color: cores.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatarMoeda(preco.preco),
                      style: textos.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cores.primary,
                      ),
                    ),
                    if (preco.precoRef != null)
                      Text(
                        formatarPrecoRef(preco.precoRef, preco.unidadeRef),
                        style: textos.bodySmall
                            ?.copyWith(color: cores.onSurfaceVariant),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Etiqueta(texto: rotuloTipo(preco.tipo)),
                if (preco.limitePorCliente != null)
                  _Etiqueta(texto: 'Limite ${preco.limitePorCliente} un'),
              ],
            ),
            if ((preco.observacao ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                preco.observacao!,
                style:
                    textos.bodySmall?.copyWith(color: cores.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cores.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: cores.onSurfaceVariant),
      ),
    );
  }
}
