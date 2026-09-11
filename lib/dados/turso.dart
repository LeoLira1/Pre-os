import 'package:libsql_dart/libsql_dart.dart';

import '../core/csv_importacao.dart';
import '../core/texto.dart';
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
  });

  final List<Loja> lojas;
  final List<Produto> produtos;
  final List<Preco> precos;
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

  Future<void> _criarEsquema(LibsqlClient cliente) async {
    for (final comando in comandosEsquema) {
      await cliente.execute(comando);
    }
  }

  /// Baixa todo o banco para guardar no cache do aparelho.
  Future<Fotografia> baixarTudo() async {
    final cliente = await _conectar();
    await _criarEsquema(cliente);

    final lojas = await cliente.query('SELECT * FROM lojas ORDER BY nome');
    final produtos = await cliente.query('SELECT * FROM produtos ORDER BY nome');
    final precos = await cliente.query('SELECT * FROM precos ORDER BY data');

    return Fotografia(
      lojas: lojas.map(Loja.doMapa).toList(),
      produtos: produtos.map(Produto.doMapa).toList(),
      precos: precos.map(Preco.doMapa).toList(),
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
