import 'dart:convert';

import 'texto.dart';

/// Categorias que o modelo pode usar. Fora desta lista, a categoria vira null.
const List<String> categoriasPermitidas = <String>[
  'Mercearia',
  'Café',
  'Bebidas',
  'Frios e Laticínios',
  'Congelados',
  'Açougue Bovino',
  'Açougue Suíno',
  'Aves',
  'Peixaria',
  'Hortifruti',
  'Padaria',
  'Limpeza',
  'Higiene',
  'Aromatizantes',
  'Utilidades',
  'Kits',
];

const List<String> unidadesEmbalagem = <String>['g', 'kg', 'ml', 'L', 'un', 'rolo'];

const List<String> unidadesVenda = <String>[
  'un',
  'kg',
  'bandeja',
  'pacote',
  'caixa',
  'fardo',
  'kit',
  'cartela',
];

/// Um produto lido de uma foto, antes de virar registro no banco.
class ItemExtraido {
  ItemExtraido({
    required this.textoOriginal,
    required this.produto,
    this.marca,
    this.categoria,
    this.embalagemQtd,
    this.embalagemUnidade,
    this.unidadeVenda,
    required this.preco,
    this.ean,
    this.limitePorCliente,
    this.observacao,
    this.confianca = 'media',
  });

  String textoOriginal;
  String produto;
  String? marca;
  String? categoria;
  double? embalagemQtd;
  String? embalagemUnidade;
  String? unidadeVenda;
  double? preco;
  String? ean;
  int? limitePorCliente;
  String? observacao;
  String confianca;

  ItemExtraido copiar() => ItemExtraido(
        textoOriginal: textoOriginal,
        produto: produto,
        marca: marca,
        categoria: categoria,
        embalagemQtd: embalagemQtd,
        embalagemUnidade: embalagemUnidade,
        unidadeVenda: unidadeVenda,
        preco: preco,
        ean: ean,
        limitePorCliente: limitePorCliente,
        observacao: observacao,
        confianca: confianca,
      );

  Map<String, dynamic> paraMapa() => {
        'texto_original': textoOriginal,
        'produto': produto,
        'marca': marca,
        'categoria': categoria,
        'embalagem_qtd': embalagemQtd,
        'embalagem_unidade': embalagemUnidade,
        'unidade_venda': unidadeVenda,
        'preco': preco,
        'ean': ean,
        'limite_por_cliente': limitePorCliente,
        'observacao': observacao,
        'confianca': confianca,
      };

  factory ItemExtraido.doMapa(Map<String, dynamic> m) => ItemExtraido(
        textoOriginal: _texto(m['texto_original']) ?? '',
        produto: _texto(m['produto']) ?? _texto(m['texto_original']) ?? '',
        marca: _texto(m['marca']),
        categoria: _categoria(m['categoria']),
        embalagemQtd: _numero(m['embalagem_qtd']),
        embalagemUnidade: _daLista(m['embalagem_unidade'], unidadesEmbalagem),
        unidadeVenda: _daLista(m['unidade_venda'], unidadesVenda),
        preco: _numero(m['preco']),
        ean: _texto(m['ean']),
        limitePorCliente: _inteiro(m['limite_por_cliente']),
        observacao: _texto(m['observacao']),
        confianca: _confianca(m['confianca']),
      );
}

/// O que o modelo devolveu para uma foto.
class ExtracaoFoto {
  const ExtracaoFoto({
    required this.itens,
    this.dataOferta,
    this.loja,
  });

  final List<ItemExtraido> itens;
  final String? dataOferta;
  final String? loja;

  static const ExtracaoFoto vazia = ExtracaoFoto(itens: <ItemExtraido>[]);

  Map<String, dynamic> paraMapa() => {
        'data_oferta': dataOferta,
        'loja': loja,
        'itens': itens.map((i) => i.paraMapa()).toList(),
      };

  factory ExtracaoFoto.doMapa(Map<String, dynamic> m) => ExtracaoFoto(
        dataOferta: _data(m['data_oferta']),
        loja: _texto(m['loja']),
        itens: (m['itens'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ItemExtraido.doMapa(Map<String, dynamic>.from(e)))
            .where((i) => i.produto.trim().isNotEmpty || i.preco != null)
            .toList(),
      );
}

/// Erro quando a resposta do modelo nao e um JSON aproveitavel.
class RespostaInvalidaException implements Exception {
  const RespostaInvalidaException(this.detalhe);

  final String detalhe;

  @override
  String toString() =>
      'O modelo respondeu num formato que o app nao entendeu. $detalhe';
}

/// Le a resposta do modelo.
///
/// Aceita o JSON puro e tambem quando ele vem embrulhado em ```json ... ```
/// ou com alguma frase antes ou depois.
ExtracaoFoto lerRespostaModelo(String? conteudo) {
  final texto = (conteudo ?? '').trim();
  if (texto.isEmpty) {
    throw const RespostaInvalidaException('A resposta veio vazia.');
  }

  final candidatos = <String>[texto, ..._extrairBlocos(texto)];
  for (final candidato in candidatos) {
    final decodificado = _tentarDecodificar(candidato);
    if (decodificado != null) {
      return ExtracaoFoto.doMapa(decodificado);
    }
  }
  final amostra = texto.length > 200 ? '${texto.substring(0, 200)}...' : texto;
  throw RespostaInvalidaException('Resposta recebida: $amostra');
}

Map<String, dynamic>? _tentarDecodificar(String texto) {
  try {
    final valor = jsonDecode(texto);
    if (valor is Map<String, dynamic>) return valor;
    // Alguns modelos devolvem so a lista de itens.
    if (valor is List) return {'itens': valor};
  } catch (_) {
    // Tenta o proximo candidato.
  }
  return null;
}

/// Pedacos que podem conter o JSON: dentro de ``` ``` ou entre { e }.
List<String> _extrairBlocos(String texto) {
  final blocos = <String>[];

  final cerca = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
  for (final achado in cerca.allMatches(texto)) {
    final interno = achado.group(1)?.trim();
    if (interno != null && interno.isNotEmpty) blocos.add(interno);
  }

  // Cerca aberta e nao fechada (resposta cortada no meio).
  final aberta = RegExp(r'```(?:json)?\s*([\s\S]*)$', caseSensitive: false)
      .firstMatch(texto)
      ?.group(1)
      ?.trim();
  if (aberta != null && aberta.isNotEmpty) blocos.add(aberta);

  final primeiraChave = texto.indexOf('{');
  final ultimaChave = texto.lastIndexOf('}');
  if (primeiraChave >= 0 && ultimaChave > primeiraChave) {
    blocos.add(texto.substring(primeiraChave, ultimaChave + 1));
  }

  final primeiroColchete = texto.indexOf('[');
  final ultimoColchete = texto.lastIndexOf(']');
  if (primeiroColchete >= 0 && ultimoColchete > primeiroColchete) {
    blocos.add(texto.substring(primeiroColchete, ultimoColchete + 1));
  }

  return blocos;
}

String? _texto(dynamic valor) {
  if (valor == null) return null;
  final texto = valor.toString().trim();
  if (texto.isEmpty) return null;
  // O modelo as vezes escreve a palavra "null" em vez do valor nulo.
  if (texto.toLowerCase() == 'null') return null;
  return texto;
}

/// Aceita numero ou texto ("29.99", "29,99", "R$ 29,99").
double? _numero(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  var texto = valor.toString().trim();
  if (texto.isEmpty || texto.toLowerCase() == 'null') return null;
  texto = texto.replaceAll(RegExp(r'[R$\s]'), '');
  if (texto.contains(',') && texto.contains('.')) {
    texto = texto.replaceAll('.', '').replaceAll(',', '.');
  } else if (texto.contains(',')) {
    texto = texto.replaceAll(',', '.');
  }
  return double.tryParse(texto);
}

int? _inteiro(dynamic valor) {
  final numero = _numero(valor);
  return numero?.round();
}

/// So aceita valores da lista permitida, comparando sem acento e sem caixa.
String? _daLista(dynamic valor, List<String> permitidos) {
  final texto = _texto(valor);
  if (texto == null) return null;
  for (final permitido in permitidos) {
    if (normalizar(permitido) == normalizar(texto)) {
      return permitido;
    }
  }
  return null;
}

String? _categoria(dynamic valor) => _daLista(valor, categoriasPermitidas);

String _confianca(dynamic valor) {
  final texto = normalizar(_texto(valor) ?? '');
  if (texto == 'alta' || texto == 'baixa' || texto == 'media') return texto;
  return 'media';
}

/// Aceita "2026-09-11" e tambem "11/09/2026".
String? _data(dynamic valor) {
  final texto = _texto(valor);
  if (texto == null) return null;

  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) {
    return DateTime.tryParse(texto) == null ? null : texto;
  }
  final brasileira = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(texto);
  if (brasileira != null) {
    final dia = brasileira.group(1)!.padLeft(2, '0');
    final mes = brasileira.group(2)!.padLeft(2, '0');
    final ano = brasileira.group(3)!;
    final iso = '$ano-$mes-$dia';
    return DateTime.tryParse(iso) == null ? null : iso;
  }
  return null;
}
