import '../modelos/modelos.dart';
import 'formato.dart';

/// O ultimo preco de um produto numa loja.
class PrecoNaLoja {
  const PrecoNaLoja({
    required this.lojaId,
    required this.nomeLoja,
    required this.preco,
    required this.data,
    this.precoRef,
    this.unidadeRef,
  });

  final int lojaId;

  /// Nome curto, sem "Supermercado" na frente.
  final String nomeLoja;
  final double preco;
  final String data;
  final double? precoRef;
  final String? unidadeRef;

  /// Valor usado para comparar as lojas: o preco de referencia quando
  /// existe, senao o preco cheio.
  double get valorComparavel => precoRef ?? preco;
}

/// Monta a comparacao entre lojas de um produto.
///
/// Pega o registro mais recente de cada loja e ordena do mais barato para o
/// mais caro, comparando sempre pelo preco de referencia (por kg, L ou un)
/// quando ele existe.
List<PrecoNaLoja> compararLojas({
  required List<Preco> precos,
  required String Function(int lojaId) nomeDaLoja,
}) {
  // Guarda so o registro mais recente de cada loja.
  final maisRecentePorLoja = <int, Preco>{};
  for (final preco in precos) {
    final atual = maisRecentePorLoja[preco.lojaId];
    if (atual == null || preco.data.compareTo(atual.data) > 0) {
      maisRecentePorLoja[preco.lojaId] = preco;
    }
  }

  final lista = <PrecoNaLoja>[
    for (final preco in maisRecentePorLoja.values)
      PrecoNaLoja(
        lojaId: preco.lojaId,
        nomeLoja: nomeCurtoLoja(nomeDaLoja(preco.lojaId)),
        preco: preco.preco,
        data: preco.data,
        precoRef: preco.precoRef,
        unidadeRef: preco.unidadeRef,
      ),
  ];

  lista.sort((a, b) {
    final porValor = a.valorComparavel.compareTo(b.valorComparavel);
    if (porValor != 0) return porValor;
    // Empate no preco: a loja com registro mais novo vem primeiro.
    return b.data.compareTo(a.data);
  });
  return lista;
}

/// A data mais recente entre as lojas comparadas.
///
/// Serve para marcar quais lojas estao com preco antigo, para nao comparar
/// oferta velha com preco de agora.
String? dataMaisRecente(List<PrecoNaLoja> lojas) {
  String? maior;
  for (final loja in lojas) {
    if (maior == null || loja.data.compareTo(maior) > 0) maior = loja.data;
  }
  return maior;
}

/// Verdadeiro quando esta loja tem registro mais antigo que outra da lista.
bool estaDesatualizada(PrecoNaLoja loja, List<PrecoNaLoja> todas) {
  final maisNova = dataMaisRecente(todas);
  return maisNova != null && loja.data.compareTo(maisNova) < 0;
}
