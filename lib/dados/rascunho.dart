import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/custo.dart';
import '../core/extracao_json.dart';

/// Situacao de cada foto dentro do lote.
enum SituacaoFoto { pendente, enviando, pronta, erro }

/// Uma foto do lote, com o que ja foi lido dela.
class FotoDoLote {
  FotoDoLote({
    required this.id,
    required this.nomeArquivo,
    required this.caminho,
    this.situacao = SituacaoFoto.pendente,
    this.itens = const <ItemExtraido>[],
    this.erro,
    this.uso = const UsoTokens(),
    this.custoUsd = 0,
    this.dataLida,
    this.lojaLida,
  });

  /// Hash do conteudo da foto: a mesma foto nunca e enviada duas vezes.
  final String id;
  final String nomeArquivo;

  /// Copia da foto guardada na pasta do app, para sobreviver ao fechamento.
  final String caminho;

  SituacaoFoto situacao;
  List<ItemExtraido> itens;
  String? erro;
  UsoTokens uso;
  double custoUsd;

  /// Data e loja que o modelo leu nesta foto (podem ajudar a preencher o lote).
  String? dataLida;
  String? lojaLida;

  bool get concluida => situacao == SituacaoFoto.pronta;

  File get arquivo => File(caminho);

  Map<String, dynamic> paraMapa() => {
        'id': id,
        'nome_arquivo': nomeArquivo,
        'caminho': caminho,
        'situacao': situacao.name,
        'erro': erro,
        'uso': uso.paraMapa(),
        'custo_usd': custoUsd,
        'data_lida': dataLida,
        'loja_lida': lojaLida,
        'itens': itens.map((i) => i.paraMapa()).toList(),
      };

  factory FotoDoLote.doMapa(Map<String, dynamic> m) => FotoDoLote(
        id: m['id']?.toString() ?? '',
        nomeArquivo: m['nome_arquivo']?.toString() ?? 'foto',
        caminho: m['caminho']?.toString() ?? '',
        situacao: SituacaoFoto.values.firstWhere(
          (s) => s.name == m['situacao'],
          orElse: () => SituacaoFoto.pendente,
        ),
        erro: m['erro']?.toString(),
        uso: UsoTokens.doMapa(
          Map<String, dynamic>.from(m['uso'] as Map? ?? const {}),
        ),
        custoUsd: (m['custo_usd'] as num?)?.toDouble() ?? 0,
        dataLida: m['data_lida']?.toString(),
        lojaLida: m['loja_lida']?.toString(),
        itens: (m['itens'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ItemExtraido.doMapa(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Um lote de fotos em andamento, salvo no aparelho.
///
/// Existe para uma coisa so: se o app fechar no meio, nada do que ja foi
/// extraido (e pago) se perde.
class LoteFotos {
  LoteFotos({
    required this.criadoEm,
    required this.fotos,
    this.loja = '',
    this.tipo = 'oferta',
    this.data,
  });

  final DateTime criadoEm;
  final List<FotoDoLote> fotos;
  String loja;
  String tipo;
  String? data;

  bool get vazio => fotos.isEmpty;

  int get prontas => fotos.where((f) => f.concluida).length;

  int get totalItens =>
      fotos.fold(0, (soma, foto) => soma + foto.itens.length);

  UsoTokens get usoTotal =>
      fotos.fold(const UsoTokens(), (soma, foto) => soma.mais(foto.uso));

  double get custoTotalUsd =>
      fotos.fold(0.0, (soma, foto) => soma + foto.custoUsd);

  Map<String, dynamic> paraMapa() => {
        'criado_em': criadoEm.toIso8601String(),
        'loja': loja,
        'tipo': tipo,
        'data': data,
        'fotos': fotos.map((f) => f.paraMapa()).toList(),
      };

  factory LoteFotos.doMapa(Map<String, dynamic> m) => LoteFotos(
        criadoEm:
            DateTime.tryParse(m['criado_em']?.toString() ?? '') ?? DateTime.now(),
        loja: m['loja']?.toString() ?? '',
        tipo: m['tipo']?.toString() ?? 'oferta',
        data: m['data']?.toString(),
        fotos: (m['fotos'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => FotoDoLote.doMapa(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Guarda o lote em andamento e as copias das fotos.
class RascunhoImportacao {
  static const _nomeArquivo = 'rascunho_fotos.json';
  static const _pastaFotos = 'fotos_importacao';

  Future<Directory> _pasta() async {
    final base = await getApplicationDocumentsDirectory();
    final pasta = Directory('${base.path}/$_pastaFotos');
    if (!await pasta.exists()) await pasta.create(recursive: true);
    return pasta;
  }

  Future<File> _arquivoRascunho() async {
    final base = await getApplicationDocumentsDirectory();
    return File('${base.path}/$_nomeArquivo');
  }

  /// Copia a foto ja reduzida para a pasta do app.
  Future<String> guardarFoto(String id, Uint8List bytes) async {
    final pasta = await _pasta();
    final arquivo = File('${pasta.path}/$id.jpg');
    await arquivo.writeAsBytes(bytes);
    return arquivo.path;
  }

  Future<void> salvar(LoteFotos lote) async {
    final arquivo = await _arquivoRascunho();
    await arquivo.writeAsString(jsonEncode(lote.paraMapa()));
  }

  /// Devolve o lote pendente, ou null se nao houver nada para continuar.
  Future<LoteFotos?> ler() async {
    try {
      final arquivo = await _arquivoRascunho();
      if (!await arquivo.exists()) return null;
      final texto = await arquivo.readAsString();
      if (texto.trim().isEmpty) return null;
      final lote =
          LoteFotos.doMapa(jsonDecode(texto) as Map<String, dynamic>);
      if (lote.vazio) return null;

      // Se as copias das fotos sumiram, o rascunho nao serve mais.
      final existentes = <FotoDoLote>[];
      for (final foto in lote.fotos) {
        if (await foto.arquivo.exists()) existentes.add(foto);
      }
      if (existentes.isEmpty) return null;
      return LoteFotos(
        criadoEm: lote.criadoEm,
        fotos: existentes,
        loja: lote.loja,
        tipo: lote.tipo,
        data: lote.data,
      );
    } catch (_) {
      // Rascunho corrompido nao pode travar o app.
      return null;
    }
  }

  /// Apaga o rascunho e as copias das fotos.
  Future<void> limpar() async {
    try {
      final arquivo = await _arquivoRascunho();
      if (await arquivo.exists()) await arquivo.delete();
      final pasta = await _pasta();
      if (await pasta.exists()) await pasta.delete(recursive: true);
    } catch (_) {
      // Se nao der para apagar, o proximo lote sobrescreve.
    }
  }
}
