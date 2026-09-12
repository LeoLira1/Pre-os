import 'package:intl/intl.dart';

import 'texto.dart';

final NumberFormat _moeda =
    NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);
final NumberFormat _decimal = NumberFormat.decimalPattern('pt_BR');

/// R$ 1.234,56
String formatarMoeda(double? valor) {
  if (valor == null) return '--';
  return _moeda.format(valor);
}

/// R$ 3,99/kg
String formatarPrecoRef(double? valor, String? unidadeRef) {
  if (valor == null) return '--';
  final unidade = (unidadeRef ?? '').trim();
  if (unidade.isEmpty) return formatarMoeda(valor);
  return '${formatarMoeda(valor)}/$unidade';
}

/// Converte uma data ISO (yyyy-MM-dd) para dd/MM/yyyy.
/// Se o texto nao for uma data valida, devolve o proprio texto.
String formatarData(String? isoData) {
  if (isoData == null || isoData.isEmpty) return '--';
  final data = DateTime.tryParse(isoData);
  if (data == null) return isoData;
  return DateFormat('dd/MM/yyyy').format(data);
}

/// 500 g, 1,5 L, 12 un
String formatarEmbalagem(double? qtd, String? unidade) {
  final u = (unidade ?? '').trim();
  if (qtd == null) return u;
  final q = _decimal.format(qtd);
  return u.isEmpty ? q : '$q $u';
}

/// Descricao curta do produto usada em listas: marca + embalagem.
String descreverProduto({
  String? marca,
  double? embalagemQtd,
  String? embalagemUnidade,
}) {
  final partes = <String>[];
  if ((marca ?? '').trim().isNotEmpty) partes.add(marca!.trim());
  final emb = formatarEmbalagem(embalagemQtd, embalagemUnidade);
  if (emb.trim().isNotEmpty) partes.add(emb);
  return partes.join(' - ');
}

/// "Zupp 1 L · R$ 2,49": qual embalagem deu o menor preco de referencia.
///
/// Usado no card do grupo generico, embaixo do preco por litro ou por quilo.
String descreverEmbalagemDoMenorPreco({
  String? marca,
  double? embalagemQtd,
  String? embalagemUnidade,
  required double? preco,
}) {
  final embalagem = descreverProduto(
    marca: marca,
    embalagemQtd: embalagemQtd,
    embalagemUnidade: embalagemUnidade,
  ).replaceAll(' - ', ' ');
  final valor = formatarMoeda(preco);
  return embalagem.isEmpty ? valor : '$embalagem · $valor';
}

/// Nome curto da loja para caber nas listas.
///
/// Tira "Supermercado" ou "Supermercados" do comeco:
/// "Supermercado Varejao" vira "Varejao".
String nomeCurtoLoja(String? nome) {
  final texto = (nome ?? '').trim();
  if (texto.isEmpty) return '';
  final semPrefixo = texto.replaceFirst(
    RegExp(r'^supermercados?\s+', caseSensitive: false),
    '',
  );
  final limpo = semPrefixo.trim();
  // Se a loja se chama so "Supermercado", mantem o nome original.
  return limpo.isEmpty ? texto : limpo;
}

/// Rotulo amigavel para o tipo do registro de preco.
String rotuloTipo(String? tipo) {
  switch (tipo) {
    case 'oferta':
      return 'Oferta';
    case 'prateleira':
      return 'Prateleira';
    case 'cupom':
      return 'Cupom';
    default:
      return tipo ?? '--';
  }
}

/// Verdadeiro quando o termo buscado aparece no texto, ignorando acentos
/// e maiusculas.
bool contemBusca(String? texto, String termoNormalizado) {
  if (termoNormalizado.isEmpty) return true;
  return normalizar(texto).contains(termoNormalizado);
}
