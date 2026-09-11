import 'package:libsql_dart/libsql_dart.dart';

import '../core/csv_importacao.dart';
import '../core/custo.dart';
import '../core/texto.dart';
import '../core/vinculo.dart';
import '../modelos/modelos.dart';
import 'esquema.dart';

/// Resumo do que aconteceu numa importacao de CSV.
class ResultadoImportacao {
  const ResultadoImportacao({
    required this.precosInseridos,
    required this.produtosCriados,
    required this.lojasCriadas,
    required this.duplicadosIgnorados,
  });

  final int precosInseridos;
  final int produtosCriados;
  final int lojasCriadas;
  final int duplicadosIgnorados;
}

/// Tudo o que existe no banco, baixado de uma vez para o cache local.
class Fotografia {
  const Fotografia({
    required this.lojas,
    required this.produtos,
    required this.precos,
    this.apelidos = const <Apelido>[],
    this.custoAcumuladoUsd = 0,
  });

  final List<Loja> lojas;
  final List<Produto> produtos;
  final List<Preco> precos;

  /// Textos de tabloide ja vinculados a um produto.
  final List<Apelido> apelidos;

  /// Soma do custo estimado de todas as importacoes por foto.
  final double custoAcumuladoUsd;
}

/// Conexao direta com o banco Turso, sem servidor no meio.
class Turso {
  Turso({required this.url, required this.token});

  final String url;
  final String token;

  LibsqlClient? _cliente;

  Future<LibsqlClient> _conectar() async {
    final existente = _cliente;
    if (existente != null) return existente;
    final novo = LibsqlClient(url.trim(), authToken: token.trim());
    await novo.connect();
    _cliente = novo;
    return novo;
  }

  /// Conexao aberta e com o esquema conferido. Usada pela extension de
  /// importacao por foto, que fica fora da classe.
  Future<LibsqlClient> conexaoPronta() async {
    final cliente = await _conectar();
    await _criarEsquema(cliente);
    return cliente;
  }

  Future<void> fechar() async {
    await _cliente?.dispose();
    _cliente = null;
  }

  /// Conecta, cria as tabelas que faltarem e devolve uma contagem simples.
  /// Usado pelo botao "Testar conexao".
  Future<String> testarConexao() async {
    final cliente = await _conectar();
    await _criarEsquema(cliente);
    final produtos = await cliente.query('SELECT COUNT(*) AS total FROM produtos');
    final precos = await cliente.query('SELECT COUNT(*) AS total FROM precos');
    final totalProdutos = comoInt(produtos.first['total']) ?? 0;
    final totalPrecos = comoInt(precos.first['total']) ?? 0;
    return 'Conectado. $totalProdutos produtos e $totalPrecos registros de preco.';
  }

  bool _esquemaConferido = false;

  /// Cria o que faltar e acrescenta colunas novas.
  ///
  /// Nunca apaga nem recria tabela: tudo e CREATE TABLE IF NOT EXISTS e
  /// ALTER TABLE ADD COLUMN so quando a coluna ainda nao existe. Roda uma
  /// vez por conexao.
  Future<void> _criarEsquema(LibsqlClient cliente) async {
    if (_esquemaConferido) return;
    for (final comando in comandosEsquema) {
      await cliente.execute(comando);
    }
    for (final nova in colunasNovas) {
      if (!await _colunaExiste(cliente, nova.tabela, nova.coluna)) {
        await cliente.execute(nova.comando);
      }
    }
    _esquemaConferido = true;
  }

  Future<bool> _colunaExiste(
    LibsqlClient cliente,
    String tabela,
    String coluna,
  ) async {
    final colunas = await cliente.query('PRAGMA table_info($tabela)');
    return colunas.any(
      (c) => normalizar(comoTexto(c['name'])) == normalizar(coluna),
    );
  }

  /// Baixa todo o banco para guardar no cache do aparelho.
  Future<Fotografia> baixarTudo() async {
    final cliente = await _conectar();
    await _criarEsquema(cliente);

    final lojas = await cliente.query('SELECT * FROM lojas ORDER BY nome');
    final produtos = await cliente.query('SELECT * FROM produtos ORDER BY nome');
    final precos = await cliente.query('SELECT * FROM precos ORDER BY data');
    final apelidos = await cliente.query(
      'SELECT produto_id, loja_id, texto_original FROM produto_apelidos',
    );
    final custo = await cliente.query(
      'SELECT COALESCE(SUM(custo_estimado_usd), 0) AS total FROM importacoes',
    );

    return Fotografia(
      lojas: lojas.map(Loja.doMapa).toList(),
      produtos: produtos.map(Produto.doMapa).toList(),
      precos: precos.map(Preco.doMapa).toList(),
      apelidos: apelidos.map(Apelido.doMapa).toList(),
      custoAcumuladoUsd: comoDouble(custo.first['total']) ?? 0,
    );
  }

  /// Busca, para as linhas do CSV, quais chaves de produto ja existem e
  /// quais combinacoes produto+loja+data ja tem registro de oferta.
  Future<PreviaBanco> conferirNoBanco(List<LinhaCsv> linhas) async {
    final cliente = await _conectar();
    await _criarEsquema(cliente);

    final chaves = linhas.map((l) => l.chaveProduto).toSet().toList();
    final chavesExistentes = <String, int>{};
    for (final lote in _emLotes(chaves, 200)) {
      final marcadores = List.filled(lote.length, '?').join(',');
      final achados = await cliente.query(
        'SELECT id, chave FROM produtos WHERE chave IN ($marcadores)',
        positional: lote,
      );
      for (final linha in achados) {
        chavesExistentes[comoTexto(linha['chave'])!] = comoInt(linha['id'])!;
      }
    }

    final lojasExistentes = <String, int>{};
    final lojas = await cliente.query('SELECT id, nome FROM lojas');
    for (final linha in lojas) {
      lojasExistentes[normalizar(comoTexto(linha['nome']))] =
          comoInt(linha['id'])!;
    }

    // Precos ja gravados para as datas presentes no arquivo.
    final datas = linhas.map((l) => l.dataOferta).toSet().toList();
    final precosExistentes = <String>{};
    for (final lote in _emLotes(datas, 200)) {
      final marcadores = List.filled(lote.length, '?').join(',');
      final achados = await cliente.query(
        'SELECT p.produto_id, p.loja_id, p.data, p.tipo, pr.chave, l.nome AS loja_nome '
        'FROM precos p '
        'JOIN produtos pr ON pr.id = p.produto_id '
        'JOIN lojas l ON l.id = p.loja_id '
        "WHERE p.tipo = 'oferta' AND p.data IN ($marcadores)",
        positional: lote,
      );
      for (final linha in achados) {
        precosExistentes.add(
          '${comoTexto(linha['chave'])}|${normalizar(comoTexto(linha['loja_nome']))}|${comoTexto(linha['data'])}',
        );
      }
    }

    return PreviaBanco(
      produtosExistentes: chavesExistentes,
      lojasExistentes: lojasExistentes,
      precosExistentes: precosExistentes,
    );
  }

  /// Grava as linhas do arquivo numa unica transacao.
  ///
  /// Registros repetidos sao ignorados pelo proprio banco, por causa do
  /// UNIQUE(produto_id, loja_id, data, tipo).
  Future<ResultadoImportacao> importarLinhas(List<LinhaCsv> linhas) async {
    final cliente = await _conectar();
    await _criarEsquema(cliente);

    final agora = DateTime.now().toIso8601String();
    final transacao = await cliente.transaction();
    var produtosCriados = 0;
    var lojasCriadas = 0;
    var precosInseridos = 0;

    try {
      final lojasPorNome = <String, int>{};
      final produtosPorChave = <String, int>{};

      for (final linha in linhas) {
        final chaveLoja = normalizar(linha.loja);
        var lojaId = lojasPorNome[chaveLoja];
        if (lojaId == null) {
          // COLLATE NOCASE para "Assai" e "ASSAI" nao virarem duas lojas.
          final achada = await transacao.query(
            'SELECT id FROM lojas WHERE nome = ? COLLATE NOCASE',
            positional: [linha.loja],
          );
          if (achada.isNotEmpty) {
            lojaId = comoInt(achada.first['id'])!;
          } else {
            await transacao.execute(
              'INSERT INTO lojas (nome) VALUES (?)',
              positional: [linha.loja],
            );
            final nova = await transacao.query(
              'SELECT id FROM lojas WHERE nome = ? COLLATE NOCASE',
              positional: [linha.loja],
            );
            lojaId = comoInt(nova.first['id'])!;
            lojasCriadas++;
          }
          lojasPorNome[chaveLoja] = lojaId;
        }

        var produtoId = produtosPorChave[linha.chaveProduto];
        if (produtoId == null) {
          final achado = await transacao.query(
            'SELECT id FROM produtos WHERE chave = ?',
            positional: [linha.chaveProduto],
          );
          if (achado.isNotEmpty) {
            produtoId = comoInt(achado.first['id'])!;
          } else {
            await transacao.execute(
              'INSERT INTO produtos (chave, nome, marca, categoria, embalagem_qtd, '
              'embalagem_unidade, unidade_venda, ean, criado_em) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
              positional: [
                linha.chaveProduto,
                linha.produto,
                linha.marca,
                linha.categoria,
                linha.embalagemQtd,
                linha.embalagemUnidade,
                linha.unidadeVenda,
                linha.ean,
                agora,
              ],
            );
            final novo = await transacao.query(
              'SELECT id FROM produtos WHERE chave = ?',
              positional: [linha.chaveProduto],
            );
            produtoId = comoInt(novo.first['id'])!;
            produtosCriados++;
          }
          produtosPorChave[linha.chaveProduto] = produtoId;
        }

        final afetadas = await transacao.execute(
          'INSERT OR IGNORE INTO precos (produto_id, loja_id, data, preco, preco_ref, '
          'unidade_ref, embalagem_qtd, embalagem_unidade, tipo, limite_por_cliente, '
          'observacao, fonte, criado_em) '
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'oferta', ?, ?, 'csv', ?)",
          positional: [
            produtoId,
            lojaId,
            linha.dataOferta,
            linha.preco,
            linha.precoRef,
            linha.unidadeRef,
            linha.embalagemQtd,
            linha.embalagemUnidade,
            linha.limitePorCliente,
            linha.observacao,
            agora,
          ],
        );
        if (afetadas > 0) precosInseridos++;
      }

      await transacao.commit();
    } catch (erro) {
      await transacao.rollback();
      rethrow;
    }

    return ResultadoImportacao(
      precosInseridos: precosInseridos,
      produtosCriados: produtosCriados,
      lojasCriadas: lojasCriadas,
      duplicadosIgnorados: linhas.length - precosInseridos,
    );
  }
}

/// O que o banco ja tem, para montar a previa antes de confirmar.
class PreviaBanco {
  const PreviaBanco({
    required this.produtosExistentes,
    required this.lojasExistentes,
    required this.precosExistentes,
  });

  /// chave do produto -> id
  final Map<String, int> produtosExistentes;

  /// nome da loja normalizado -> id
  final Map<String, int> lojasExistentes;

  /// "chaveProduto|lojaNormalizada|data" ja gravados como oferta
  final Set<String> precosExistentes;
}

Iterable<List<T>> _emLotes<T>(List<T> itens, int tamanho) sync* {
  for (var i = 0; i < itens.length; i += tamanho) {
    yield itens.sublist(i, i + tamanho > itens.length ? itens.length : i + tamanho);
  }
}

/// Um item ja revisado, pronto para virar registro de preco.
class ItemParaGravar {
  const ItemParaGravar({
    required this.nome,
    required this.preco,
    required this.textoOriginal,
    this.produtoId,
    this.marca,
    this.categoria,
    this.embalagemQtd,
    this.embalagemUnidade,
    this.unidadeVenda,
    this.precoRef,
    this.unidadeRef,
    this.ean,
    this.limitePorCliente,
    this.observacao,
  });

  /// Quando vem preenchido, usa este produto em vez de criar um novo.
  final int? produtoId;
  final String nome;
  final String textoOriginal;
  final double preco;
  final String? marca;
  final String? categoria;
  final double? embalagemQtd;
  final String? embalagemUnidade;
  final String? unidadeVenda;
  final double? precoRef;
  final String? unidadeRef;
  final String? ean;
  final int? limitePorCliente;
  final String? observacao;

  String get chave => montarChaveProduto(
        nome: nome,
        marca: marca,
        embalagemQtd: embalagemQtd,
        embalagemUnidade: embalagemUnidade,
      );
}

/// O que aconteceu ao gravar uma importacao por foto.
class ResultadoImportacaoFotos {
  const ResultadoImportacaoFotos({
    required this.precosInseridos,
    required this.produtosCriados,
    required this.apelidosCriados,
    required this.jaRegistrados,
    required this.importacaoId,
    required this.custoUsd,
  });

  final int precosInseridos;
  final int produtosCriados;
  final int apelidosCriados;
  final int jaRegistrados;
  final int importacaoId;
  final double custoUsd;
}

extension ImportacaoPorFoto on Turso {
  /// Grava todos os itens revisados numa unica transacao.
  ///
  /// Registros que ja existem (mesmo produto, loja, data e tipo) sao
  /// ignorados: nada do que ja esta no banco e sobrescrito.
  Future<ResultadoImportacaoFotos> salvarImportacaoFotos({
    required String loja,
    required String data,
    required String tipo,
    required List<ItemParaGravar> itens,
    required int qtdFotos,
    required UsoTokens uso,
    required double custoUsd,
  }) async {
    final cliente = await conexaoPronta();
    final agora = DateTime.now().toIso8601String();
    final transacao = await cliente.transaction();

    var produtosCriados = 0;
    var precosInseridos = 0;
    var apelidosCriados = 0;

    try {
      // Loja do lote: acha ou cria uma vez so.
      int lojaId;
      final achada = await transacao.query(
        'SELECT id FROM lojas WHERE nome = ? COLLATE NOCASE',
        positional: [loja],
      );
      if (achada.isNotEmpty) {
        lojaId = comoInt(achada.first['id'])!;
      } else {
        await transacao.execute(
          'INSERT INTO lojas (nome) VALUES (?)',
          positional: [loja],
        );
        final nova = await transacao.query(
          'SELECT id FROM lojas WHERE nome = ? COLLATE NOCASE',
          positional: [loja],
        );
        lojaId = comoInt(nova.first['id'])!;
      }

      // Registro da importacao, para saber depois quanto custou.
      await transacao.execute(
        'INSERT INTO importacoes (criado_em, loja_id, data_oferta, tipo, '
        'qtd_fotos, qtd_itens_salvos, tokens_entrada, tokens_saida, '
        'tokens_cache, custo_estimado_usd) '
        'VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?)',
        positional: [
          agora,
          lojaId,
          data,
          tipo,
          qtdFotos,
          uso.entradaSemCache,
          uso.saida,
          uso.entradaComCache,
          custoUsd,
        ],
      );
      final criada = await transacao.query(
        'SELECT id FROM importacoes ORDER BY id DESC LIMIT 1',
      );
      final importacaoId = comoInt(criada.first['id'])!;

      final produtosPorChave = <String, int>{};

      for (final item in itens) {
        int produtoId;
        if (item.produtoId != null) {
          produtoId = item.produtoId!;
        } else {
          final chave = item.chave;
          final emCache = produtosPorChave[chave];
          if (emCache != null) {
            produtoId = emCache;
          } else {
            final achado = await transacao.query(
              'SELECT id FROM produtos WHERE chave = ?',
              positional: [chave],
            );
            if (achado.isNotEmpty) {
              produtoId = comoInt(achado.first['id'])!;
            } else {
              await transacao.execute(
                'INSERT INTO produtos (chave, nome, marca, categoria, '
                'embalagem_qtd, embalagem_unidade, unidade_venda, ean, criado_em) '
                'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                positional: [
                  chave,
                  item.nome,
                  item.marca,
                  item.categoria,
                  item.embalagemQtd,
                  item.embalagemUnidade,
                  item.unidadeVenda,
                  item.ean,
                  agora,
                ],
              );
              final novo = await transacao.query(
                'SELECT id FROM produtos WHERE chave = ?',
                positional: [chave],
              );
              produtoId = comoInt(novo.first['id'])!;
              produtosCriados++;
            }
            produtosPorChave[chave] = produtoId;
          }
        }

        final afetadas = await transacao.execute(
          'INSERT OR IGNORE INTO precos (produto_id, loja_id, data, preco, '
          'preco_ref, unidade_ref, embalagem_qtd, embalagem_unidade, tipo, '
          'limite_por_cliente, observacao, fonte, criado_em, importacao_id) '
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'foto', ?, ?)",
          positional: [
            produtoId,
            lojaId,
            data,
            item.preco,
            item.precoRef,
            item.unidadeRef,
            item.embalagemQtd,
            item.embalagemUnidade,
            tipo,
            item.limitePorCliente,
            item.observacao,
            agora,
            importacaoId,
          ],
        );
        if (afetadas > 0) precosInseridos++;

        // Grava o texto do tabloide para que na proxima semana o vinculo
        // seja automatico.
        final texto = item.textoOriginal.trim();
        if (texto.isNotEmpty) {
          final jaTem = await transacao.query(
            'SELECT id FROM produto_apelidos WHERE produto_id = ? '
            'AND loja_id = ? AND texto_original = ? COLLATE NOCASE',
            positional: [produtoId, lojaId, texto],
          );
          if (jaTem.isEmpty) {
            await transacao.execute(
              'INSERT INTO produto_apelidos (produto_id, loja_id, texto_original) '
              'VALUES (?, ?, ?)',
              positional: [produtoId, lojaId, texto],
            );
            apelidosCriados++;
          }
        }
      }

      await transacao.execute(
        'UPDATE importacoes SET qtd_itens_salvos = ? WHERE id = ?',
        positional: [precosInseridos, importacaoId],
      );

      await transacao.commit();

      return ResultadoImportacaoFotos(
        precosInseridos: precosInseridos,
        produtosCriados: produtosCriados,
        apelidosCriados: apelidosCriados,
        jaRegistrados: itens.length - precosInseridos,
        importacaoId: importacaoId,
        custoUsd: custoUsd,
      );
    } catch (erro) {
      await transacao.rollback();
      rethrow;
    }
  }
}
