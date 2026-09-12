import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/vinculo.dart';
import '../modelos/modelos.dart';
import 'turso.dart';

/// Conteudo do cache guardado em arquivo no aparelho.
class CacheConteudo {
  const CacheConteudo({
    required this.lojas,
    required this.produtos,
    required this.precos,
    this.grupos = const <Grupo>[],
    this.produtoGrupos = const <ProdutoGrupo>[],
    this.sugestoesRejeitadas = const <SugestaoRejeitada>[],
    this.sugestoesGenericasRejeitadas = const <SugestaoGenericaRejeitada>[],
    this.apelidos = const <Apelido>[],
    this.custoAcumuladoUsd = 0,
    this.atualizadoEm,
  });

  final List<Loja> lojas;
  final List<Produto> produtos;
  final List<Preco> precos;
  final List<Grupo> grupos;
  final List<ProdutoGrupo> produtoGrupos;
  final List<SugestaoRejeitada> sugestoesRejeitadas;

  /// Sugestoes de grupo generico ja recusadas.
  final List<SugestaoGenericaRejeitada> sugestoesGenericasRejeitadas;

  /// Textos de tabloide ja vinculados, usados para reconhecer o produto.
  final List<Apelido> apelidos;

  /// Quanto ja foi gasto na API somando todas as importacoes por foto.
  final double custoAcumuladoUsd;
  final DateTime? atualizadoEm;

  static const CacheConteudo vazio = CacheConteudo(
    lojas: <Loja>[],
    produtos: <Produto>[],
    precos: <Preco>[],
  );

  bool get estaVazio => produtos.isEmpty && precos.isEmpty;
}

/// Guarda uma copia do banco num arquivo JSON dentro da pasta do aplicativo,
/// para que o app abra e consulte mesmo sem internet.
class CacheLocal {
  static const _nomeArquivo = 'cache_precos.json';

  Future<File> _arquivo() async {
    final pasta = await getApplicationDocumentsDirectory();
    return File('${pasta.path}/$_nomeArquivo');
  }

  Future<CacheConteudo> ler() async {
    try {
      final arquivo = await _arquivo();
      if (!await arquivo.exists()) return CacheConteudo.vazio;
      final texto = await arquivo.readAsString();
      if (texto.trim().isEmpty) return CacheConteudo.vazio;
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      return CacheConteudo(
        lojas: (mapa['lojas'] as List<dynamic>? ?? [])
            .map((e) => Loja.doMapa(Map<String, dynamic>.from(e as Map)))
            .toList(),
        produtos: (mapa['produtos'] as List<dynamic>? ?? [])
            .map((e) => Produto.doMapa(Map<String, dynamic>.from(e as Map)))
            .toList(),
        precos: (mapa['precos'] as List<dynamic>? ?? [])
            .map((e) => Preco.doMapa(Map<String, dynamic>.from(e as Map)))
            .toList(),
        grupos: (mapa['grupos'] as List<dynamic>? ?? [])
            .map((e) => Grupo.doMapa(Map<String, dynamic>.from(e as Map)))
            .toList(),
        produtoGrupos: (mapa['produto_grupos'] as List<dynamic>? ?? [])
            .map((e) => ProdutoGrupo.doMapa(Map<String, dynamic>.from(e as Map)))
            .toList(),
        sugestoesRejeitadas:
            (mapa['sugestoes_rejeitadas'] as List<dynamic>? ?? [])
                .map((e) => SugestaoRejeitada.doMapa(
                      Map<String, dynamic>.from(e as Map),
                    ))
                .toList(),
        sugestoesGenericasRejeitadas:
            (mapa['sugestoes_genericas_rejeitadas'] as List<dynamic>? ?? [])
                .map((e) => SugestaoGenericaRejeitada.doMapa(
                      Map<String, dynamic>.from(e as Map),
                    ))
                .toList(),
        apelidos: (mapa['apelidos'] as List<dynamic>? ?? [])
            .map((e) => Apelido.doMapa(Map<String, dynamic>.from(e as Map)))
            .toList(),
        custoAcumuladoUsd:
            (mapa['custo_acumulado_usd'] as num?)?.toDouble() ?? 0,
        atualizadoEm: DateTime.tryParse(mapa['atualizado_em']?.toString() ?? ''),
      );
    } catch (_) {
      // Cache corrompido nao pode impedir o app de abrir.
      return CacheConteudo.vazio;
    }
  }

  Future<CacheConteudo> gravar(Fotografia fotografia) async {
    final agora = DateTime.now();
    final arquivo = await _arquivo();
    await arquivo.writeAsString(
      jsonEncode({
        'atualizado_em': agora.toIso8601String(),
        'lojas': fotografia.lojas.map((e) => e.paraMapa()).toList(),
        'produtos': fotografia.produtos.map((e) => e.paraMapa()).toList(),
        'precos': fotografia.precos.map((e) => e.paraMapa()).toList(),
        'grupos': fotografia.grupos.map((e) => e.paraMapa()).toList(),
        'produto_grupos':
            fotografia.produtoGrupos.map((e) => e.paraMapa()).toList(),
        'sugestoes_rejeitadas':
            fotografia.sugestoesRejeitadas.map((e) => e.paraMapa()).toList(),
        'sugestoes_genericas_rejeitadas': fotografia
            .sugestoesGenericasRejeitadas
            .map((e) => e.paraMapa())
            .toList(),
        'apelidos': fotografia.apelidos.map((e) => e.paraMapa()).toList(),
        'custo_acumulado_usd': fotografia.custoAcumuladoUsd,
      }),
    );
    return CacheConteudo(
      lojas: fotografia.lojas,
      produtos: fotografia.produtos,
      precos: fotografia.precos,
      grupos: fotografia.grupos,
      produtoGrupos: fotografia.produtoGrupos,
      sugestoesRejeitadas: fotografia.sugestoesRejeitadas,
      sugestoesGenericasRejeitadas: fotografia.sugestoesGenericasRejeitadas,
      apelidos: fotografia.apelidos,
      custoAcumuladoUsd: fotografia.custoAcumuladoUsd,
      atualizadoEm: agora,
    );
  }

  Future<void> limpar() async {
    final arquivo = await _arquivo();
    if (await arquivo.exists()) await arquivo.delete();
  }
}
