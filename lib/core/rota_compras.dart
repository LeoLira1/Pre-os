import '../modelos/modelos.dart';
import 'comparacao_lojas.dart';

/// Um item da lista de compras: o grupo escolhido e onde ele esta mais barato.
class ItemDaRota {
  const ItemDaRota({
    required this.grupo,
    required this.opcoes,
    required this.empatados,
  });

  final Grupo grupo;

  /// Uma opcao por loja, da mais barata para a mais cara pelo preco de
  /// referencia (por L, kg ou un).
  final List<PrecoNaLoja> opcoes;

  /// Indices de [opcoes] que estao empatados com o primeiro (menos de 2% de
  /// diferenca no preco de referencia).
  final Set<int> empatados;

  /// A loja e a marca mais baratas por unidade de referencia.
  PrecoNaLoja? get melhor => opcoes.isEmpty ? null : opcoes.first;

  /// Grupo generico compara marcas diferentes entre si.
  bool get generico => grupo.ignoraMarca;

  /// As outras lojas que custam praticamente o mesmo.
  List<PrecoNaLoja> get empatadasComOMelhor => <PrecoNaLoja>[
        for (var i = 1; i < opcoes.length; i++)
          if (empatados.contains(i)) opcoes[i],
      ];
}

/// Uma parada da rota: tudo o que compensa comprar numa loja so.
class ParadaDaRota {
  const ParadaDaRota({
    required this.lojaId,
    required this.nomeLoja,
    required this.itens,
  });

  final int lojaId;
  final String nomeLoja;

  /// Os itens que ficam mais baratos nesta loja.
  final List<ItemDaRota> itens;

  /// Quanto custa levar uma embalagem de cada item desta parada.
  double get total => itens.fold<double>(
        0,
        (soma, item) => soma + (item.melhor?.preco ?? 0),
      );
}

/// Monta um item da rota a partir dos precos do grupo.
ItemDaRota montarItemDaRota({
  required Grupo grupo,
  required List<Preco> precos,
  required String Function(int lojaId) nomeDaLoja,
  Produto? Function(int produtoId)? produtoPorId,
}) {
  final opcoes = compararLojas(
    precos: precos,
    nomeDaLoja: nomeDaLoja,
    produtoPorId: produtoPorId,
  );
  return ItemDaRota(
    grupo: grupo,
    opcoes: opcoes,
    empatados: indicesEmpatados(opcoes),
  );
}

/// Junta os itens por loja, da parada com mais itens para a com menos.
///
/// Itens sem nenhum preco registrado ficam de fora.
List<ParadaDaRota> montarRota(List<ItemDaRota> itens) {
  final porLoja = <int, List<ItemDaRota>>{};
  final nomes = <int, String>{};
  for (final item in itens) {
    final melhor = item.melhor;
    if (melhor == null) continue;
    porLoja.putIfAbsent(melhor.lojaId, () => <ItemDaRota>[]).add(item);
    nomes[melhor.lojaId] = melhor.nomeLoja;
  }

  final paradas = <ParadaDaRota>[
    for (final entrada in porLoja.entries)
      ParadaDaRota(
        lojaId: entrada.key,
        nomeLoja: nomes[entrada.key] ?? 'Loja ${entrada.key}',
        itens: entrada.value,
      ),
  ];

  paradas.sort((a, b) {
    final porQuantidade = b.itens.length.compareTo(a.itens.length);
    if (porQuantidade != 0) return porQuantidade;
    return a.nomeLoja.compareTo(b.nomeLoja);
  });
  return paradas;
}

/// Quanto custaria comprar tudo na mesma loja, quando ela tem todos os itens.
///
/// Serve para dizer se vale a pena dividir a compra entre duas lojas.
double? totalNumaLojaSo(List<ItemDaRota> itens, int lojaId) {
  var total = 0.0;
  for (final item in itens) {
    final naLoja = item.opcoes.where((o) => o.lojaId == lojaId);
    if (naLoja.isEmpty) return null;
    total += naLoja.first.preco;
  }
  return total;
}
