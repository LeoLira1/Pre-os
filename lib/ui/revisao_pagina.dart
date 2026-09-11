import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/conferir.dart';
import '../core/custo.dart';
import '../core/extracao_json.dart';
import '../core/formato.dart';
import '../core/revisao.dart';
import '../core/vinculo.dart';
import '../dados/estado_app.dart';
import '../dados/rascunho.dart';
import '../dados/turso.dart';
import '../modelos/modelos.dart';
import 'widgets/editor_item.dart';
import 'widgets/foto_tela_cheia.dart';

/// Tela de conferencia: mostra tudo o que foi lido, agrupado por foto, e so
/// grava depois que o usuario confirma.
class RevisaoPagina extends StatefulWidget {
  const RevisaoPagina({super.key, required this.estado, required this.lote});

  final EstadoApp estado;
  final LoteFotos lote;

  @override
  State<RevisaoPagina> createState() => _RevisaoPaginaState();
}

class _RevisaoPaginaState extends State<RevisaoPagina> {
  final List<ItemRevisao> _itens = [];
  bool _gravando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _montarItens();
  }

  /// Liga cada item lido a um produto do banco (ou marca como novo).
  void _montarItens() {
    final lojaId = widget.estado.idDaLoja(widget.lote.loja);
    for (final foto in widget.lote.fotos) {
      for (final item in foto.itens) {
        _itens.add(
          ItemRevisao(
            fotoId: foto.id,
            item: item,
            vinculo: procurarProduto(
              item: item,
              produtos: widget.estado.produtos,
              apelidos: widget.estado.apelidos,
              lojaId: lojaId,
            ),
          ),
        );
      }
    }
  }

  String get _data {
    final bruta = widget.lote.data;
    if (bruta != null && bruta.isNotEmpty && DateTime.tryParse(bruta) != null) {
      return bruta;
    }
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  List<ItemRevisao> get _ativos => _itens.where((i) => !i.excluido).toList();

  double? _mediaDe(ItemRevisao revisao) {
    final id = revisao.produtoId;
    return id == null ? null : widget.estado.mediaHistorica(id);
  }

  Preco? _jaRegistrado(ItemRevisao revisao) {
    final produtoId = revisao.produtoId;
    final lojaId = widget.estado.idDaLoja(widget.lote.loja);
    if (produtoId == null || lojaId == null) return null;
    return widget.estado.precoJaRegistrado(
      produtoId: produtoId,
      lojaId: lojaId,
      data: _data,
      tipo: widget.lote.tipo,
    );
  }

  ResumoRevisao get _resumo {
    var novos = 0;
    var conferir = 0;
    var jaRegistrados = 0;
    for (final revisao in _ativos) {
      if (revisao.produtoNovo) novos++;
      if (revisao.conferir(mediaHistorica: _mediaDe(revisao)).isNotEmpty) {
        conferir++;
      }
      if (_jaRegistrado(revisao) != null) jaRegistrados++;
    }
    return ResumoRevisao(
      itens: _ativos.length,
      novos: novos,
      paraConferir: conferir,
      jaRegistrados: jaRegistrados,
    );
  }

  Future<void> _editar(ItemRevisao revisao) async {
    final mudou = await abrirEditorItem(
      context: context,
      estado: widget.estado,
      revisao: revisao,
    );
    if (mudou == true && mounted) setState(() {});
  }

  Future<void> _adicionarManual(FotoDoLote foto) async {
    final novo = ItemRevisao(
      fotoId: foto.id,
      item: ItemExtraido(
        textoOriginal: '',
        produto: '',
        preco: null,
        confianca: 'alta',
      ),
      vinculo: Vinculo.produtoNovo,
      manual: true,
    );
    final salvou = await abrirEditorItem(
      context: context,
      estado: widget.estado,
      revisao: novo,
      novoItem: true,
    );
    if (salvou == true && mounted) {
      setState(() => _itens.add(novo));
    }
  }

  Future<void> _salvarTudo() async {
    final paraGravar = <ItemParaGravar>[];
    var ignorados = 0;

    for (final revisao in _ativos) {
      if (_jaRegistrado(revisao) != null) {
        // Ja existe registro deste produto nesta loja, data e tipo:
        // nao sobrescreve.
        ignorados++;
        continue;
      }
      final preco = revisao.item.preco;
      if (preco == null || preco <= 0) {
        ignorados++;
        continue;
      }
      paraGravar.add(
        ItemParaGravar(
          produtoId: revisao.produtoId,
          nome: revisao.item.produto.trim().isEmpty
              ? revisao.item.textoOriginal
              : revisao.item.produto,
          textoOriginal: revisao.item.textoOriginal,
          preco: preco,
          marca: revisao.item.marca,
          categoria: revisao.item.categoria,
          embalagemQtd: revisao.item.embalagemQtd,
          embalagemUnidade: revisao.item.embalagemUnidade,
          unidadeVenda: revisao.item.unidadeVenda,
          precoRef: revisao.precoRef.valor,
          unidadeRef: revisao.precoRef.unidade,
          ean: revisao.item.ean,
          limitePorCliente: revisao.item.limitePorCliente,
          observacao: revisao.item.observacao,
        ),
      );
    }

    if (paraGravar.isEmpty) {
      setState(
        () => _erro = ignorados > 0
            ? 'Todos os itens ja estao registrados nesta loja e data.'
            : 'Nao ha itens para gravar.',
      );
      return;
    }

    setState(() {
      _gravando = true;
      _erro = null;
    });

    Turso? conexao;
    try {
      conexao = widget.estado.abrirConexao();
      final resultado = await conexao.salvarImportacaoFotos(
        loja: widget.lote.loja,
        data: _data,
        tipo: widget.lote.tipo,
        itens: paraGravar,
        qtdFotos: widget.lote.fotos.length,
        uso: widget.lote.usoTotal,
        custoUsd: widget.lote.custoTotalUsd,
      );
      await conexao.fechar();
      conexao = null;
      await widget.estado.sincronizar();
      if (!mounted) return;
      await _mostrarResumo(resultado, ignorados);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = erro.toString());
    } finally {
      await conexao?.fechar();
      if (mounted) setState(() => _gravando = false);
    }
  }

  Future<void> _mostrarResumo(
    ResultadoImportacaoFotos resultado,
    int ignorados,
  ) {
    return showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Importacao concluida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${resultado.precosInseridos} precos gravados.'),
            Text('${resultado.produtosCriados} produtos novos.'),
            Text('${resultado.apelidosCriados} nomes de tabloide aprendidos.'),
            if (resultado.jaRegistrados + ignorados > 0)
              Text(
                '${resultado.jaRegistrados + ignorados} ignorados por ja '
                'existirem.',
              ),
            const SizedBox(height: 12),
            Text(
              'Custo estimado desta importacao: '
              '${formatarUsd(resultado.custoUsd)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _resumo;
    final comItens =
        widget.lote.fotos.where((f) => f.itens.isNotEmpty || f.concluida);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar antes de gravar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _BarraResumo(resumo: resumo, lote: widget.lote),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        children: [
          if (_erro != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _erro!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final foto in comItens) ...[
            _GrupoFoto(
              foto: foto,
              itens: _itens
                  .where((i) => i.fotoId == foto.id && !i.excluido)
                  .toList(),
              mediaDe: _mediaDe,
              jaRegistradoDe: _jaRegistrado,
              onEditar: _editar,
              onAdicionar: () => _adicionarManual(foto),
              nomeProduto: (id) => widget.estado.produtoPorId(id)?.nome,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _gravando || resumo.itens == 0 ? null : _salvarTudo,
            icon: _gravando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              _gravando
                  ? 'Gravando...'
                  : 'Salvar tudo (${resumo.itens - resumo.jaRegistrados})',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarraResumo extends StatelessWidget {
  const _BarraResumo({required this.resumo, required this.lote});

  final ResumoRevisao resumo;
  final LoteFotos lote;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _Pastilha(texto: '${resumo.itens} itens'),
              _Pastilha(texto: '${resumo.novos} novos', cor: cores.primary),
              if (resumo.paraConferir > 0)
                _Pastilha(
                  texto: '${resumo.paraConferir} para conferir',
                  cor: Colors.amber.shade800,
                ),
              if (resumo.jaRegistrados > 0)
                _Pastilha(
                  texto: '${resumo.jaRegistrados} ja registrados',
                  cor: cores.outline,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${lote.loja} - ${rotuloTipo(lote.tipo)} - '
            '${formatarData(lote.data)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Pastilha extends StatelessWidget {
  const _Pastilha({required this.texto, this.cor});

  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final corFinal = cor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: corFinal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: corFinal, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _GrupoFoto extends StatelessWidget {
  const _GrupoFoto({
    required this.foto,
    required this.itens,
    required this.mediaDe,
    required this.jaRegistradoDe,
    required this.onEditar,
    required this.onAdicionar,
    required this.nomeProduto,
  });

  final FotoDoLote foto;
  final List<ItemRevisao> itens;
  final double? Function(ItemRevisao) mediaDe;
  final Preco? Function(ItemRevisao) jaRegistradoDe;
  final void Function(ItemRevisao) onEditar;
  final VoidCallback onAdicionar;
  final String? Function(int) nomeProduto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => abrirFotoTelaCheia(context, foto.arquivo),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      foto.arquivo,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 64,
                        height: 64,
                        color: cores.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          foto.nomeArquivo,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${itens.length} itens - toque para ver a foto',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.zoom_in),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          for (final revisao in itens)
            _CartaoItem(
              revisao: revisao,
              media: mediaDe(revisao),
              jaRegistrado: jaRegistradoDe(revisao),
              nomeProduto: nomeProduto,
              onTap: () => onEditar(revisao),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: TextButton.icon(
              onPressed: onAdicionar,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar item manualmente'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoItem extends StatelessWidget {
  const _CartaoItem({
    required this.revisao,
    required this.media,
    required this.jaRegistrado,
    required this.nomeProduto,
    required this.onTap,
  });

  final ItemRevisao revisao;
  final double? media;
  final Preco? jaRegistrado;
  final String? Function(int) nomeProduto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final item = revisao.item;
    final motivos = revisao.conferir(mediaHistorica: media);
    final ambar = Colors.amber.shade800;

    final detalhe = descreverProduto(
      marca: item.marca,
      embalagemQtd: item.embalagemQtd,
      embalagemUnidade: item.embalagemUnidade,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                        item.produto.isEmpty ? item.textoOriginal : item.produto,
                        style: textos.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (detalhe.isNotEmpty)
                        Text(
                          detalhe,
                          style: textos.bodySmall
                              ?.copyWith(color: cores.onSurfaceVariant),
                        ),
                      if (item.unidadeVenda != null)
                        Text(
                          'Vendido por ${item.unidadeVenda}',
                          style: textos.bodySmall
                              ?.copyWith(color: cores.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatarMoeda(item.preco),
                      style: textos.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cores.primary,
                      ),
                    ),
                    if (revisao.precoRef.existe)
                      Text(
                        formatarPrecoRef(
                          revisao.precoRef.valor,
                          revisao.precoRef.unidade,
                        ),
                        style: textos.bodySmall
                            ?.copyWith(color: cores.onSurfaceVariant),
                      ),
                  ],
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (revisao.produtoNovo)
                  _Selo(texto: 'Novo produto', cor: cores.primary)
                else if (revisao.temSugestoes)
                  _Selo(texto: 'Sugestao de vinculo', cor: ambar)
                else
                  _Selo(
                    texto: revisao.vinculadoAutomaticamente
                        ? 'Vinculado automaticamente'
                        : 'Produto existente',
                    cor: cores.outline,
                  ),
                for (final motivo in motivos)
                  _Selo(texto: 'Conferir: ${motivo.descricao}', cor: ambar),
                if (jaRegistrado != null)
                  _Selo(
                    texto: _textoJaRegistrado(jaRegistrado!, item.preco),
                    cor: cores.error,
                  ),
              ],
            ),
            if (!revisao.produtoNovo && revisao.produtoId != null) ...[
              const SizedBox(height: 6),
              Text(
                'Vinculado a: ${nomeProduto(revisao.produtoId!) ?? '--'}',
                style: textos.bodySmall
                    ?.copyWith(color: cores.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _textoJaRegistrado(Preco existente, double? precoNovo) {
    if (precoNovo != null && (existente.preco - precoNovo).abs() < 0.005) {
      return 'Ja registrado: mesmo preco';
    }
    return 'Ja registrado: preco diferente '
        '(${formatarMoeda(existente.preco)} no banco)';
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: cor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
