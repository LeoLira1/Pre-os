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
    this.produtoId,
    this.nomeProduto,
    this.marca,
    this.embalagemQtd,
    this.embalagemUnidade,
  });

  final int lojaId;

  /// Nome curto, sem "Supermercado" na frente.
  final String nomeLoja;
  final double preco;
  final String data;
  final double? precoRef;
  final String? unidadeRef;
  final int? produtoId;
  final String? nomeProduto;

  /// Marca e embalagem do produto que deu este preco. Num grupo generico e
  /// o que diz qual marca esta mais barata.
  final String? marca;
  final double? embalagemQtd;
  final String? embalagemUnidade;

  /// Valor usado para comparar as lojas: o preco de referencia quando
  /// existe, senao o preco cheio.
  double get valorComparavel => precoRef ?? preco;

  /// "Zupp 1 L" — a marca e a embalagem, para o grupo generico.
  String get marcaEEmbalagem => descreverProduto(
        marca: marca,
        embalagemQtd: embalagemQtd,
        embalagemUnidade: embalagemUnidade,
      ).replaceAll(' - ', ' ');
}

/// Monta a comparacao entre lojas de um produto.
///
/// Pega o registro mais recente de cada loja e ordena do mais barato para o
/// mais caro, comparando sempre pelo preco de referencia (por kg, L ou un)
/// quando ele existe.
List<PrecoNaLoja> compararLojas({
  required List<Preco> precos,
  required String Function(int lojaId) nomeDaLoja,
  String Function(int produtoId)? nomeDoProduto,
  Produto? Function(int produtoId)? produtoPorId,
}) {
  // Guarda so o registro mais recente de cada loja.
  final maisRecentePorLoja = <int, Preco>{};
  for (final preco in precos) {
    final atual = maisRecentePorLoja[preco.lojaId];
    if (atual == null ||
        preco.data.compareTo(atual.data) > 0 ||
        (preco.data == atual.data &&
            preco.valorComparavel < atual.valorComparavel)) {
      maisRecentePorLoja[preco.lojaId] = preco;
    }
  }

  final lista = <PrecoNaLoja>[
    for (final preco in maisRecentePorLoja.values)
      _montar(
        preco: preco,
        nomeDaLoja: nomeDaLoja,
        nomeDoProduto: nomeDoProduto,
        produtoPorId: produtoPorId,
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

PrecoNaLoja _montar({
  required Preco preco,
  required String Function(int lojaId) nomeDaLoja,
  String Function(int produtoId)? nomeDoProduto,
  Produto? Function(int produtoId)? produtoPorId,
}) {
  final produto = produtoPorId?.call(preco.produtoId);
  return PrecoNaLoja(
    lojaId: preco.lojaId,
    nomeLoja: nomeCurtoLoja(nomeDaLoja(preco.lojaId)),
    preco: preco.preco,
    data: preco.data,
    precoRef: preco.precoRef,
    unidadeRef: preco.unidadeRef,
    produtoId: preco.produtoId,
    nomeProduto: nomeDoProduto?.call(preco.produtoId) ?? produto?.nome,
    marca: produto?.marca,
    // A embalagem do registro manda: e ela que gerou o preco de referencia.
    embalagemQtd: preco.embalagemQtd ?? produto?.embalagemQtd,
    embalagemUnidade: preco.embalagemUnidade ?? produto?.embalagemUnidade,
  );
}

/// Quanto duas lojas podem diferir no preco de referencia e ainda contarem
/// como empate: 2%.
const double toleranciaDeEmpate = 0.02;

/// Quais lojas estao tecnicamente empatadas com a mais barata.
///
/// Numa comparacao entre marcas, R$ 2,49/L e R$ 2,50/L nao sao precos
/// diferentes na pratica: as duas voltam marcadas como empate. Quando so
/// uma esta na frente, o resultado vem vazio.
Set<int> indicesEmpatados(
  List<PrecoNaLoja> lojas, {
  double tolerancia = toleranciaDeEmpate,
}) {
  if (lojas.length < 2) return const <int>{};
  final menor = lojas.first.valorComparavel;
  if (menor <= 0) return const <int>{};

  final empatados = <int>{};
  for (var i = 0; i < lojas.length; i++) {
    final diferenca = (lojas[i].valorComparavel - menor) / menor;
    if (diferenca < tolerancia) empatados.add(i);
  }
  return empatados.length < 2 ? const <int>{} : empatados;
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
