import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../dados/estado_app.dart';
import '../modelos/modelos.dart';
import 'widgets/grafico_precos.dart';

/// Tela de um produto: cabecalho, numeros, grafico e historico.
class ProdutoPagina extends StatelessWidget {
  const ProdutoPagina({
    super.key,
    required this.estado,
    required this.produtoId,
  });

  final EstadoApp estado;
  final int produtoId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final produto = estado.produtoPorId(produtoId);
        if (produto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Produto')),
            body: const Center(
              child: Text('Este produto nao esta mais no cache local.'),
            ),
          );
        }

        final precos = estado.precosDoProduto(produtoId);
        final estatisticas = EstatisticasProduto.calcular(precos);
        final historico = precos.reversed.toList();

        return Scaffold(
          appBar: AppBar(title: Text(produto.nome)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Cabecalho(produto: produto),
              const SizedBox(height: 16),
              _Numeros(estatisticas: estatisticas),
              const SizedBox(height: 24),
              Text(
                'Historico de preco',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (estatisticas.usandoPrecoRef)
                Text(
                  'Valores por ${estatisticas.unidadeRef ?? 'unidade de referencia'}.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Text(
                  'Sem preco de referencia: mostrando o preco cheio.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              GraficoPrecos(precos: precos, unidadeRef: estatisticas.unidadeRef),
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
                    child: Text('Nenhum registro de preco para este produto.'),
                  ),
                )
              else
                for (final preco in historico)
                  _ItemHistorico(
                    preco: preco,
                    loja: estado.nomeDaLoja(preco.lojaId),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final linhas = <String>[
      if ((produto.marca ?? '').trim().isNotEmpty) 'Marca: ${produto.marca}',
      if (produto.embalagemQtd != null ||
          (produto.embalagemUnidade ?? '').trim().isNotEmpty)
        'Embalagem: ${formatarEmbalagem(produto.embalagemQtd, produto.embalagemUnidade)}',
      if ((produto.unidadeVenda ?? '').trim().isNotEmpty)
        'Venda por: ${produto.unidadeVenda}',
      if ((produto.ean ?? '').trim().isNotEmpty) 'EAN: ${produto.ean}',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              produto.nome,
              style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if ((produto.categoria ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(produto.categoria!),
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

class _Numeros extends StatelessWidget {
  const _Numeros({required this.estatisticas});

  final EstatisticasProduto estatisticas;

  @override
  Widget build(BuildContext context) {
    final unidade = estatisticas.unidadeRef;
    final cores = Theme.of(context).colorScheme;
    final cartoes = <Widget>[
      _Cartao(
        titulo: 'Ultimo',
        valor: formatarPrecoRef(estatisticas.ultimo, unidade),
        cor: cores.primary,
      ),
      _Cartao(
        titulo: 'Menor',
        valor: formatarPrecoRef(estatisticas.menor, unidade),
        cor: cores.tertiary,
      ),
      _Cartao(
        titulo: 'Maior',
        valor: formatarPrecoRef(estatisticas.maior, unidade),
        cor: cores.error,
      ),
      _Cartao(
        titulo: 'Media',
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
  const _Cartao({required this.titulo, required this.valor, required this.cor});

  final String titulo;
  final String valor;
  final Color cor;

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
          ],
        ),
      ),
    );
  }
}

class _ItemHistorico extends StatelessWidget {
  const _ItemHistorico({required this.preco, required this.loja});

  final Preco preco;
  final String loja;

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
