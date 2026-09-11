import 'package:flutter/material.dart';

import '../../core/extracao_json.dart';
import '../../core/formato.dart';
import '../../core/revisao.dart';
import '../../core/similaridade.dart';
import '../../core/texto.dart';
import '../../core/vinculo.dart';
import '../../dados/estado_app.dart';
import '../../modelos/modelos.dart';

/// Abre a folha de edicao de um item.
///
/// Devolve true quando o usuario salvou alguma mudanca.
Future<bool?> abrirEditorItem({
  required BuildContext context,
  required EstadoApp estado,
  required ItemRevisao revisao,
  bool novoItem = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EditorItem(
      estado: estado,
      revisao: revisao,
      novoItem: novoItem,
    ),
  );
}

class _EditorItem extends StatefulWidget {
  const _EditorItem({
    required this.estado,
    required this.revisao,
    required this.novoItem,
  });

  final EstadoApp estado;
  final ItemRevisao revisao;
  final bool novoItem;

  @override
  State<_EditorItem> createState() => _EditorItemState();
}

class _EditorItemState extends State<_EditorItem> {
  late final ItemExtraido _rascunho = widget.revisao.item.copiar();
  late int? _produtoId = widget.revisao.produtoId;
  late bool _forcarNovo = widget.revisao.forcarProdutoNovo;

  late final _produto = TextEditingController(text: _rascunho.produto);
  late final _textoOriginal =
      TextEditingController(text: _rascunho.textoOriginal);
  late final _marca = TextEditingController(text: _rascunho.marca ?? '');
  late final _qtd = TextEditingController(
    text: _rascunho.embalagemQtd == null
        ? ''
        : formatarNumeroCanonico(_rascunho.embalagemQtd),
  );
  late final _preco = TextEditingController(
    text: _rascunho.preco == null ? '' : _rascunho.preco!.toStringAsFixed(2),
  );
  late final _ean = TextEditingController(text: _rascunho.ean ?? '');
  late final _limite = TextEditingController(
    text: _rascunho.limitePorCliente?.toString() ?? '',
  );
  late final _observacao =
      TextEditingController(text: _rascunho.observacao ?? '');

  String _buscaProduto = '';

  @override
  void dispose() {
    _produto.dispose();
    _textoOriginal.dispose();
    _marca.dispose();
    _qtd.dispose();
    _preco.dispose();
    _ean.dispose();
    _limite.dispose();
    _observacao.dispose();
    super.dispose();
  }

  /// Copia o formulario de volta para o item e fecha.
  void _salvar() {
    final item = widget.revisao.item;
    item.produto = _produto.text.trim();
    item.textoOriginal = _textoOriginal.text.trim();
    item.marca = _vazioParaNulo(_marca.text);
    item.embalagemQtd = _numero(_qtd.text);
    item.embalagemUnidade = _rascunho.embalagemUnidade;
    item.unidadeVenda = _rascunho.unidadeVenda;
    item.categoria = _rascunho.categoria;
    item.preco = _numero(_preco.text);
    item.ean = _vazioParaNulo(_ean.text);
    item.limitePorCliente = _numero(_limite.text)?.round();
    item.observacao = _vazioParaNulo(_observacao.text);
    item.confianca = _rascunho.confianca;

    widget.revisao.produtoEscolhido = _forcarNovo ? null : _produtoId;
    widget.revisao.forcarProdutoNovo = _forcarNovo;
    Navigator.pop(context, true);
  }

  void _excluir() {
    widget.revisao.excluido = true;
    Navigator.pop(context, true);
  }

  /// Precos ja calculados na hora, para o usuario ver o efeito da edicao.
  String get _previaPrecoRef {
    final calculado = ItemRevisao(
      fotoId: '',
      item: ItemExtraido(
        textoOriginal: '',
        produto: '',
        preco: _numero(_preco.text),
        embalagemQtd: _numero(_qtd.text),
        embalagemUnidade: _rascunho.embalagemUnidade,
      ),
      vinculo: Vinculo.produtoNovo,
    ).precoRef;
    if (!calculado.existe) return 'Sem preco de referencia';
    return formatarPrecoRef(calculado.valor, calculado.unidade);
  }

  @override
  Widget build(BuildContext context) {
    final alturaTeclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: alturaTeclado),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, rolagem) => ListView(
          controller: rolagem,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.novoItem ? 'Novo item' : 'Editar item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _produto,
              decoration: const InputDecoration(
                labelText: 'Produto',
                helperText: 'Nome padronizado, com a gramatura',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textoOriginal,
              decoration: const InputDecoration(
                labelText: 'Texto do tabloide',
                helperText: 'Como esta escrito no encarte. E o que o app usa '
                    'para reconhecer o produto na proxima semana.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _marca,
              decoration: const InputDecoration(labelText: 'Marca'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtd,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Embalagem'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _rascunho.embalagemUnidade,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('--'),
                      ),
                      for (final u in unidadesEmbalagem)
                        DropdownMenuItem<String?>(value: u, child: Text(u)),
                    ],
                    onChanged: (valor) =>
                        setState(() => _rascunho.embalagemUnidade = valor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _preco,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Preco',
                      prefixText: r'R$ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _rascunho.unidadeVenda,
                    decoration: const InputDecoration(labelText: 'Vendido por'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('--'),
                      ),
                      for (final u in unidadesVenda)
                        DropdownMenuItem<String?>(value: u, child: Text(u)),
                    ],
                    onChanged: (valor) =>
                        setState(() => _rascunho.unidadeVenda = valor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Preco de referencia: $_previaPrecoRef',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _rascunho.categoria,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sem categoria'),
                ),
                for (final c in categoriasPermitidas)
                  DropdownMenuItem<String?>(value: c, child: Text(c)),
              ],
              onChanged: (valor) => setState(() => _rascunho.categoria = valor),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _limite,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Limite por cliente'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ean,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'EAN'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observacao,
              decoration: const InputDecoration(labelText: 'Observacao'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Text(
              'Produto no banco',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _SeletorProduto(
              estado: widget.estado,
              revisao: widget.revisao,
              produtoId: _forcarNovo ? null : _produtoId,
              forcarNovo: _forcarNovo,
              busca: _buscaProduto,
              nomeDigitado: _produto.text,
              onBusca: (texto) => setState(() => _buscaProduto = texto),
              onEscolher: (id) => setState(() {
                _produtoId = id;
                _forcarNovo = false;
              }),
              onNovo: () => setState(() {
                _forcarNovo = true;
                _produtoId = null;
              }),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.check),
              label: Text(widget.novoItem ? 'Adicionar item' : 'Salvar'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (!widget.novoItem) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _excluir,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir este item'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _vazioParaNulo(String texto) {
    final limpo = texto.trim();
    return limpo.isEmpty ? null : limpo;
  }

  static double? _numero(String texto) {
    var limpo = texto.trim().replaceAll(RegExp(r'[R$\s]'), '');
    if (limpo.isEmpty) return null;
    if (limpo.contains(',') && limpo.contains('.')) {
      limpo = limpo.replaceAll('.', '').replaceAll(',', '.');
    } else if (limpo.contains(',')) {
      limpo = limpo.replaceAll(',', '.');
    }
    return double.tryParse(limpo);
  }
}

/// Escolhe a qual produto do banco este item pertence.
class _SeletorProduto extends StatelessWidget {
  const _SeletorProduto({
    required this.estado,
    required this.revisao,
    required this.produtoId,
    required this.forcarNovo,
    required this.busca,
    required this.nomeDigitado,
    required this.onBusca,
    required this.onEscolher,
    required this.onNovo,
  });

  final EstadoApp estado;
  final ItemRevisao revisao;
  final int? produtoId;
  final bool forcarNovo;
  final String busca;
  final String nomeDigitado;
  final ValueChanged<String> onBusca;
  final ValueChanged<int> onEscolher;
  final VoidCallback onNovo;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final atual = produtoId == null ? null : estado.produtoPorId(produtoId!);

    // Sugestoes: as do vinculo automatico, ou o resultado da busca.
    final List<Candidato<Produto>> opcoes;
    if (busca.trim().isEmpty) {
      opcoes = revisao.vinculo.sugestoes.isNotEmpty
          ? revisao.vinculo.sugestoes
          : ranquearCandidatos<Produto>(
              nomeBuscado: nomeDigitado,
              candidatos: estado.produtos,
              nomeDe: (p) => p.nome,
              limite: 3,
            ).where((c) => c.nota > 0.2).toList();
    } else {
      final termo = normalizar(busca);
      opcoes = estado.produtos
          .where(
            (p) => contemBusca(p.nome, termo) || contemBusca(p.marca, termo),
          )
          .take(8)
          .map((p) => Candidato<Produto>(item: p, nota: 0))
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: forcarNovo || atual == null
              ? cores.primaryContainer
              : cores.surfaceContainerHighest,
          child: ListTile(
            leading: Icon(
              forcarNovo || atual == null
                  ? Icons.fiber_new_outlined
                  : Icons.link,
            ),
            title: Text(
              forcarNovo || atual == null
                  ? 'Sera criado como produto novo'
                  : atual.nome,
            ),
            subtitle: atual == null
                ? null
                : Text(
                    descreverProduto(
                      marca: atual.marca,
                      embalagemQtd: atual.embalagemQtd,
                      embalagemUnidade: atual.embalagemUnidade,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Procurar outro produto',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: onBusca,
        ),
        const SizedBox(height: 8),
        for (final opcao in opcoes)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              opcao.item.id == produtoId
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(opcao.item.nome),
            subtitle: Text(
              [
                descreverProduto(
                  marca: opcao.item.marca,
                  embalagemQtd: opcao.item.embalagemQtd,
                  embalagemUnidade: opcao.item.embalagemUnidade,
                ),
                if (opcao.nota > 0)
                  'parecido ${(opcao.nota * 100).round()}%',
              ].where((t) => t.isNotEmpty).join(' - '),
            ),
            onTap: () => onEscolher(opcao.item.id),
          ),
        if (!forcarNovo)
          TextButton.icon(
            onPressed: onNovo,
            icon: const Icon(Icons.add),
            label: const Text('Criar como produto novo'),
          ),
      ],
    );
  }
}
