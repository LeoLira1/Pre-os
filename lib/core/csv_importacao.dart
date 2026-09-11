import 'package:csv/csv.dart';

import 'texto.dart';

/// Cabecalho exigido no arquivo CSV, exatamente nesta ordem.
const List<String> cabecalhoEsperado = <String>[
  'data_oferta',
  'loja',
  'categoria',
  'produto',
  'marca',
  'embalagem_qtd',
  'embalagem_unidade',
  'unidade_venda',
  'preco',
  'preco_ref',
  'unidade_ref',
  'ean',
  'observacao',
];

/// Uma linha do CSV ja validada e pronta para virar registros no banco.
class LinhaCsv {
  const LinhaCsv({
    required this.numeroLinha,
    required this.dataOferta,
    required this.loja,
    required this.produto,
    required this.preco,
    required this.chaveProduto,
    this.categoria,
    this.marca,
    this.embalagemQtd,
    this.embalagemUnidade,
    this.unidadeVenda,
    this.precoRef,
    this.unidadeRef,
    this.ean,
    this.observacao,
    this.limitePorCliente,
  });

  /// Numero da linha no arquivo, contando o cabecalho como linha 1.
  final int numeroLinha;
  final String dataOferta;
  final String loja;
  final String produto;
  final double preco;
  final String chaveProduto;
  final String? categoria;
  final String? marca;
  final double? embalagemQtd;
  final String? embalagemUnidade;
  final String? unidadeVenda;
  final double? precoRef;
  final String? unidadeRef;
  final String? ean;
  final String? observacao;
  final int? limitePorCliente;

  /// Identifica o registro de preco para efeito de duplicidade:
  /// mesmo produto, mesma loja, mesma data e mesmo tipo.
  String get identidadePreco => '$chaveProduto|${normalizar(loja)}|$dataOferta';
}

/// Uma linha que nao pode ser importada, com o motivo em portugues simples.
class ErroLinha {
  const ErroLinha({
    required this.numeroLinha,
    required this.motivo,
    this.conteudo = '',
  });

  final int numeroLinha;
  final String motivo;
  final String conteudo;
}

/// Resultado da leitura do arquivo, antes de olhar o banco de dados.
class ResultadoLeituraCsv {
  const ResultadoLeituraCsv({
    required this.linhas,
    required this.erros,
    required this.totalLinhas,
  });

  /// Linhas validas, ja sem as repetidas dentro do proprio arquivo.
  final List<LinhaCsv> linhas;
  final List<ErroLinha> erros;

  /// Total de linhas de dados encontradas (sem contar o cabecalho).
  final int totalLinhas;
}

/// Erro lancado quando o arquivo escolhido nao tem o cabecalho esperado.
class CabecalhoInvalidoException implements Exception {
  const CabecalhoInvalidoException(this.encontrado);

  final List<String> encontrado;

  @override
  String toString() =>
      'O cabecalho do arquivo nao confere.\n'
      'Esperado: ${cabecalhoEsperado.join(',')}\n'
      'Encontrado: ${encontrado.join(',')}';
}

final Csv _csv = Csv(
  fieldDelimiter: ',',
  autoDetect: false,
  skipEmptyLines: true,
);

final RegExp _regexData = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _regexLimite = RegExp(r'limite\s*(\d+)\s*un', caseSensitive: false);

/// Le o texto de um arquivo CSV e devolve as linhas validas e os erros.
///
/// Lanca [CabecalhoInvalidoException] se o cabecalho nao for o esperado.
ResultadoLeituraCsv lerCsv(String conteudo) {
  final texto = conteudo.startsWith('﻿') ? conteudo.substring(1) : conteudo;
  final tabela = _csv.decode(texto);

  if (tabela.isEmpty) {
    throw const CabecalhoInvalidoException(<String>[]);
  }

  final cabecalho =
      tabela.first.map((c) => normalizar(c?.toString())).toList(growable: false);
  if (cabecalho.length != cabecalhoEsperado.length ||
      !_listasIguais(cabecalho, cabecalhoEsperado)) {
    throw CabecalhoInvalidoException(cabecalho);
  }

  final linhas = <LinhaCsv>[];
  final erros = <ErroLinha>[];
  final vistasNoArquivo = <String, int>{};
  var totalLinhas = 0;

  for (var i = 1; i < tabela.length; i++) {
    final bruta = tabela[i];
    final numeroLinha = i + 1;

    // Linha totalmente em branco: ignora sem reclamar.
    if (bruta.every((c) => _limpar(c) == null)) continue;
    totalLinhas++;

    if (bruta.length != cabecalhoEsperado.length) {
      erros.add(
        ErroLinha(
          numeroLinha: numeroLinha,
          motivo:
              'A linha tem ${bruta.length} colunas e deveria ter ${cabecalhoEsperado.length}.',
          conteudo: _resumo(bruta),
        ),
      );
      continue;
    }

    final campos = bruta.map(_limpar).toList(growable: false);
    final motivo = _validar(campos);
    if (motivo != null) {
      erros.add(
        ErroLinha(
          numeroLinha: numeroLinha,
          motivo: motivo,
          conteudo: _resumo(bruta),
        ),
      );
      continue;
    }

    final observacao = campos[12];
    final linha = LinhaCsv(
      numeroLinha: numeroLinha,
      dataOferta: campos[0]!,
      loja: campos[1]!,
      categoria: campos[2],
      produto: campos[3]!,
      marca: campos[4],
      embalagemQtd: converterDecimal(campos[5]),
      embalagemUnidade: campos[6],
      unidadeVenda: campos[7],
      preco: converterDecimal(campos[8])!,
      precoRef: converterDecimal(campos[9]),
      unidadeRef: campos[10],
      ean: campos[11],
      observacao: observacao,
      limitePorCliente: extrairLimite(observacao),
      chaveProduto: montarChaveProduto(
        nome: campos[3]!,
        marca: campos[4],
        embalagemQtd: converterDecimal(campos[5]),
        embalagemUnidade: campos[6],
      ),
    );

    final jaVista = vistasNoArquivo[linha.identidadePreco];
    if (jaVista != null) {
      erros.add(
        ErroLinha(
          numeroLinha: numeroLinha,
          motivo:
              'Repetida dentro do proprio arquivo (igual a linha $jaVista): mesmo produto, loja e data.',
          conteudo: _resumo(bruta),
        ),
      );
      continue;
    }
    vistasNoArquivo[linha.identidadePreco] = numeroLinha;
    linhas.add(linha);
  }

  return ResultadoLeituraCsv(
    linhas: linhas,
    erros: erros,
    totalLinhas: totalLinhas,
  );
}

/// Devolve o motivo do erro, ou null se a linha estiver boa.
String? _validar(List<String?> campos) {
  final data = campos[0];
  if (data == null) return 'A coluna data_oferta esta vazia.';
  if (!_regexData.hasMatch(data) || DateTime.tryParse(data) == null) {
    return 'A data "$data" nao esta no formato AAAA-MM-DD.';
  }
  if (campos[1] == null) return 'A coluna loja esta vazia.';
  if (campos[3] == null) return 'A coluna produto esta vazia.';

  final preco = campos[8];
  if (preco == null) return 'A coluna preco esta vazia.';
  final precoNumero = converterDecimal(preco);
  if (precoNumero == null) return 'O preco "$preco" nao e um numero valido.';
  if (precoNumero <= 0) return 'O preco "$preco" precisa ser maior que zero.';

  if (campos[5] != null && converterDecimal(campos[5]) == null) {
    return 'A embalagem_qtd "${campos[5]}" nao e um numero valido.';
  }
  if (campos[9] != null && converterDecimal(campos[9]) == null) {
    return 'O preco_ref "${campos[9]}" nao e um numero valido.';
  }
  return null;
}

/// Converte texto em numero. Aceita ponto como separador decimal (padrao do
/// arquivo) e tambem virgula, para o caso de uma planilha exportar assim.
double? converterDecimal(String? valor) {
  if (valor == null) return null;
  var texto = valor.trim();
  if (texto.isEmpty) return null;
  texto = texto.replaceAll(RegExp(r'[R$\s]'), '');
  if (texto.contains(',') && texto.contains('.')) {
    // 1.234,56 -> 1234.56
    texto = texto.replaceAll('.', '').replaceAll(',', '.');
  } else if (texto.contains(',')) {
    texto = texto.replaceAll(',', '.');
  }
  return double.tryParse(texto);
}

/// Procura "Limite 3 un" na observacao e devolve o numero 3.
int? extrairLimite(String? observacao) {
  if (observacao == null) return null;
  final achado = _regexLimite.firstMatch(observacao);
  if (achado == null) return null;
  return int.tryParse(achado.group(1)!);
}

/// Campo vazio vira null; o resto vem sem espacos nas pontas.
String? _limpar(dynamic valor) {
  if (valor == null) return null;
  final texto = valor.toString().trim();
  return texto.isEmpty ? null : texto;
}

String _resumo(List<dynamic> bruta) {
  final texto = bruta.map((c) => c?.toString() ?? '').join(',');
  return texto.length <= 120 ? texto : '${texto.substring(0, 120)}...';
}

bool _listasIguais(List<String> a, List<String> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
