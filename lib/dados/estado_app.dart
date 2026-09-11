import 'package:flutter/foundation.dart';

import '../core/formato.dart';
import '../core/texto.dart';
import '../modelos/modelos.dart';
import 'cache_local.dart';
import 'preferencias.dart';
import 'turso.dart';

/// Um produto junto com o resumo do seu historico, pronto para a lista.
class ProdutoResumo {
  const ProdutoResumo({
    required this.produto,
    required this.estatisticas,
    this.ultimoRegistro,
  });

  final Produto produto;
  final EstatisticasProduto estatisticas;

  /// Registro de preco mais recente deste produto, quando houver.
  final Preco? ultimoRegistro;
}

/// Estado central do aplicativo: le do cache, sincroniza com o Turso e
/// avisa as telas quando algo muda.
class EstadoApp extends ChangeNotifier {
  EstadoApp({
    Preferencias? preferencias,
    CacheLocal? cache,
  })  : _preferencias = preferencias ?? Preferencias(),
        _cache = cache ?? CacheLocal();

  final Preferencias _preferencias;
  final CacheLocal _cache;

  String url = '';
  String token = '';
  String chaveDeepseek = '';

  CacheConteudo _conteudo = CacheConteudo.vazio;
  bool carregando = true;
  bool sincronizando = false;
  String? ultimoErro;

  CacheConteudo get conteudo => _conteudo;
  DateTime? get atualizadoEm => _conteudo.atualizadoEm;
  bool get temCredenciais => url.trim().isNotEmpty && token.trim().isNotEmpty;
  bool get temDados => !_conteudo.estaVazio;

  Map<int, Loja> get lojasPorId => {for (final l in _conteudo.lojas) l.id: l};

  /// Chama no inicio do app: le as credenciais e o cache, sem exigir internet.
  Future<void> iniciar() async {
    url = await _preferencias.lerUrl();
    token = await _preferencias.lerToken();
    chaveDeepseek = await _preferencias.lerChaveDeepseek();
    _conteudo = await _cache.ler();
    carregando = false;
    notifyListeners();
  }

  Future<void> salvarConfiguracao({
    required String novaUrl,
    required String novoToken,
    required String novaChaveDeepseek,
  }) async {
    await _preferencias.salvar(
      url: novaUrl,
      token: novoToken,
      chaveDeepseek: novaChaveDeepseek,
    );
    url = novaUrl.trim();
    token = novoToken.trim();
    chaveDeepseek = novaChaveDeepseek.trim();
    notifyListeners();
  }

  /// Cria uma conexao nova com as credenciais guardadas.
  /// Lanca [EstadoError] se ainda nao houver credenciais.
  Turso abrirConexao() {
    if (!temCredenciais) {
      throw const EstadoError(
        'Preencha a URL e o token do Turso na tela Configuracao.',
      );
    }
    return Turso(url: url, token: token);
  }

  /// Baixa tudo do Turso e regrava o cache local.
  Future<void> sincronizar() async {
    sincronizando = true;
    ultimoErro = null;
    notifyListeners();
    Turso? conexao;
    try {
      conexao = abrirConexao();
      final fotografia = await conexao.baixarTudo();
      _conteudo = await _cache.gravar(fotografia);
    } catch (erro) {
      ultimoErro = erro is EstadoError ? erro.mensagem : erro.toString();
      rethrow;
    } finally {
      await conexao?.fechar();
      sincronizando = false;
      notifyListeners();
    }
  }

  Future<void> limparCache() async {
    await _cache.limpar();
    _conteudo = CacheConteudo.vazio;
    notifyListeners();
  }

  /// Todos os precos de um produto, do mais antigo para o mais novo.
  List<Preco> precosDoProduto(int produtoId) {
    final lista =
        _conteudo.precos.where((p) => p.produtoId == produtoId).toList();
    lista.sort((a, b) => a.data.compareTo(b.data));
    return lista;
  }

  /// Categorias presentes nos produtos, em ordem alfabetica.
  List<String> get categorias {
    final nomes = _conteudo.produtos
        .map((p) => (p.categoria ?? '').trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    nomes.sort((a, b) => normalizar(a).compareTo(normalizar(b)));
    return nomes;
  }

  /// Lista da tela inicial, ja filtrada pela busca e pela categoria.
  List<ProdutoResumo> produtosFiltrados({
    String busca = '',
    String? categoria,
  }) {
    final termo = normalizar(busca);
    final precosPorProduto = <int, List<Preco>>{};
    for (final preco in _conteudo.precos) {
      precosPorProduto.putIfAbsent(preco.produtoId, () => <Preco>[]).add(preco);
    }

    final resultado = <ProdutoResumo>[];
    for (final produto in _conteudo.produtos) {
      if (categoria != null && (produto.categoria ?? '') != categoria) continue;
      if (termo.isNotEmpty &&
          !contemBusca(produto.nome, termo) &&
          !contemBusca(produto.marca, termo)) {
        continue;
      }
      final precos = precosPorProduto[produto.id] ?? const <Preco>[];
      final ordenados = [...precos]..sort((a, b) => a.data.compareTo(b.data));
      resultado.add(
        ProdutoResumo(
          produto: produto,
          estatisticas: EstatisticasProduto.calcular(ordenados),
          ultimoRegistro: ordenados.isEmpty ? null : ordenados.last,
        ),
      );
    }

    resultado.sort((a, b) {
      final dataA = a.estatisticas.dataUltimo ?? '';
      final dataB = b.estatisticas.dataUltimo ?? '';
      final porData = dataB.compareTo(dataA);
      if (porData != 0) return porData;
      return normalizar(a.produto.nome).compareTo(normalizar(b.produto.nome));
    });
    return resultado;
  }

  Produto? produtoPorId(int id) {
    for (final p in _conteudo.produtos) {
      if (p.id == id) return p;
    }
    return null;
  }

  String nomeDaLoja(int lojaId) => lojasPorId[lojaId]?.nome ?? 'Loja $lojaId';
}

/// Erro de uso do app com mensagem pronta para mostrar na tela.
class EstadoError implements Exception {
  const EstadoError(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}
