import 'package:diacritic/diacritic.dart';

/// Deixa um texto em minusculas, sem acentos e sem espacos duplicados.
///
/// Usado tanto para montar a chave unica do produto quanto para a busca
/// da tela de produtos, para que "Café" e "cafe" sejam a mesma coisa.
String normalizar(String? texto) {
  if (texto == null) return '';
  return removeDiacritics(texto)
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Formata um numero da forma mais curta possivel: 1.0 vira "1", 1.5 vira "1.5".
///
/// Sem isto "1" e "1.0" gerariam duas chaves diferentes para o mesmo produto.
String formatarNumeroCanonico(double? valor) {
  if (valor == null) return '';
  if (valor == valor.roundToDouble() && valor.abs() < 1e15) {
    return valor.toInt().toString();
  }
  return valor
      .toString()
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Monta a chave unica de um produto:
/// nome + marca + embalagem_qtd + embalagem_unidade, normalizados.
String montarChaveProduto({
  required String nome,
  String? marca,
  double? embalagemQtd,
  String? embalagemUnidade,
}) {
  final partes = <String>[
    normalizar(nome),
    normalizar(marca),
    formatarNumeroCanonico(embalagemQtd),
    normalizar(embalagemUnidade),
  ];
  return partes.where((p) => p.isNotEmpty).join(' ');
}
