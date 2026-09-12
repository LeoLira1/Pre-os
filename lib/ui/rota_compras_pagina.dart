import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../core/rota_compras.dart';
import '../dados/estado_app.dart';
import '../modelos/modelos.dart';

/// Rota de compras: escolha os produtos e veja em que loja (e de qual marca)
/// cada um sai mais barato por litro, quilo ou unidade.
class RotaComprasPagina extends StatefulWidget {
  const RotaComprasPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<RotaComprasPagina> createState() => _RotaComprasPaginaState();
}

class _RotaComprasPaginaState extends State<RotaComprasPagina> {
  final Set<int> _escolhidos = <int>{};

  /// Grupos que valem a pena oferecer: os que tem pelo menos um produto.
  List<Grupo> get _gruposDisponiveis {
    final lista = widget.estado.grupos
        .where((g) => widget.estado.produtosDoGrupo(g.id).isNotEmpty)
        .toList();
    lista.sort((a, b) => a.nomeParaMostrar
        .toLowerCase()
        .compareTo(b.nomeParaMostrar.toLowerCase()));
    return lista;
  }

  Future<void> _escolher() async {
    final disponiveis = _gruposDisponiveis;
    var busca = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, refazer) {
          final termo = busca.trim();
          final visiveis = disponiveis
              .where((g) =>
                  contemBusca(g.nomeParaMostrar, termo.toLowerCase()) ||
                  contemBusca(g.nome, termo.toLowerCase()))
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(contexto).size.height * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Buscar produto',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (valor) => refazer(() => busca = valor),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visiveis.length,
                      itemBuilder: (contexto, indice) {
                        final grupo = visiveis[indice];
                        return CheckboxListTile(
                          value: _escolhidos.contains(grupo.id),
                          title: Text(grupo.nomeParaMostrar),
                          subtitle: Text([
                            if (grupo.ignoraMarca) 'compara marcas',
                            if ((grupo.unidadeRef ?? '').isNotEmpty)
                              'por ${grupo.unidadeRef}',
                          ].join(' · ')),
                          secondary: grupo.ignoraMarca
                              ? const Icon(Icons.compare_arrows)
                              : null,
                          onChanged: (marcado) {
                            refazer(() {
                              if (marcado ?? false) {
                                _escolhidos.add(grupo.id);
                              } else {
                                _escolhidos.remove(grupo.id);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(contexto),
                      child: const Text('Pronto'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itens = widget.estado.itensDaRota(_escolhidos);
    final paradas = montarRota(itens);
    final semPreco = itens.where((i) => i.melhor == null).toList();
    final total = paradas.fold<double>(0, (soma, p) => soma + p.total);

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
                    Text(
                      'Rota de compras',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      _escolhidos.isEmpty
                          ? 'Escolha os produtos da lista'
                          : '${_escolhidos.length} produto'
                              '${_escolhidos.length == 1 ? '' : 's'} · '
                              '${formatarMoeda(total)}',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _escolher,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Escolher'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _escolhidos.isEmpty
              ? const _Vazio()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  children: [
                    for (final parada in paradas)
                      _CartaoParada(parada: parada),
                    if (semPreco.isNotEmpty)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sem preço registrado',
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              for (final item in semPreco)
                                Text('• ${item.grupo.nomeParaMostrar}'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Tudo o que compensa levar numa loja só.
class _CartaoParada extends StatelessWidget {
  const _CartaoParada({required this.parada});

  final ParadaDaRota parada;

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
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parada.nomeLoja,
                    style: textos.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatarMoeda(parada.total),
                  style: textos.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cores.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${parada.itens.length} item'
              '${parada.itens.length == 1 ? '' : 's'}',
              style: textos.bodySmall?.copyWith(color: cores.onSurfaceVariant),
            ),
            const Divider(),
            for (final item in parada.itens) _LinhaDoItem(item: item),
          ],
        ),
      ),
    );
  }
}

class _LinhaDoItem extends StatelessWidget {
  const _LinhaDoItem({required this.item});

  final ItemDaRota item;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final melhor = item.melhor!;
    final empatadas = item.empatadasComOMelhor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                      item.grupo.nomeParaMostrar,
                      style: textos.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    // Num grupo generico o que interessa e qual marca levar.
                    if (melhor.marcaEEmbalagem.isNotEmpty)
                      Text(
                        melhor.marcaEEmbalagem,
                        style: textos.labelMedium
                            ?.copyWith(color: cores.onSurfaceVariant),
                      )
                    else if ((melhor.nomeProduto ?? '').isNotEmpty)
                      Text(
                        melhor.nomeProduto!,
                        style: textos.labelMedium
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
                    formatarMoeda(melhor.preco),
                    style: textos.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (melhor.precoRef != null)
                    Text(
                      formatarPrecoRef(melhor.precoRef, melhor.unidadeRef),
                      style: textos.labelSmall
                          ?.copyWith(color: cores.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          ),
          // Diferenca menor que 2%: tanto faz, leve o que estiver na mao.
          if (empatadas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Empate com ${empatadas.map((e) => '${e.nomeLoja}'
                    '${e.marcaEEmbalagem.isEmpty ? '' : ' (${e.marcaEEmbalagem})'}').join(', ')}',
                style: textos.labelSmall?.copyWith(color: cores.tertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Monte a lista da semana',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Toque em "Escolher" e marque os produtos. Num grupo genérico '
              'como "Água Sanitária", o app diz em qual loja e de qual marca '
              'sai mais barato por litro.',
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
