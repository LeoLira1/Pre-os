/// Preco de referencia calculado pelo proprio app, nunca pelo modelo.
class PrecoReferencia {
  const PrecoReferencia({this.valor, this.unidade});

  final double? valor;
  final String? unidade;

  static const PrecoReferencia nenhum = PrecoReferencia();

  bool get existe => valor != null;
}

/// Calcula o preco por kg, L, un ou rolo a partir da embalagem.
///
/// Regras:
/// - g   -> preco / (qtd/1000), em "kg"
/// - ml  -> preco / (qtd/1000), em "L"
/// - kg  -> preco / qtd, em "kg"
/// - L   -> preco / qtd, em "L"
/// - un  -> preco / qtd, em "un"
/// - rolo-> preco / qtd, em "rolo"
/// - sem embalagem -> null
///
/// O resultado sai arredondado em 2 casas.
PrecoReferencia calcularPrecoRef({
  required double? preco,
  required double? embalagemQtd,
  required String? embalagemUnidade,
}) {
  if (preco == null || embalagemQtd == null || embalagemQtd <= 0) {
    return PrecoReferencia.nenhum;
  }
  final unidade = (embalagemUnidade ?? '').trim().toLowerCase();
  if (unidade.isEmpty) return PrecoReferencia.nenhum;

  final double divisor;
  final String unidadeRef;
  switch (unidade) {
    case 'g':
      divisor = embalagemQtd / 1000;
      unidadeRef = 'kg';
    case 'kg':
      divisor = embalagemQtd;
      unidadeRef = 'kg';
    case 'ml':
      divisor = embalagemQtd / 1000;
      unidadeRef = 'L';
    case 'l':
      divisor = embalagemQtd;
      unidadeRef = 'L';
    case 'un':
      divisor = embalagemQtd;
      unidadeRef = 'un';
    case 'rolo':
      divisor = embalagemQtd;
      unidadeRef = 'rolo';
    default:
      return PrecoReferencia.nenhum;
  }

  if (divisor <= 0) return PrecoReferencia.nenhum;
  return PrecoReferencia(
    valor: arredondar2(preco / divisor),
    unidade: unidadeRef,
  );
}

/// Arredonda para 2 casas decimais.
double arredondar2(double valor) => (valor * 100).roundToDouble() / 100;
