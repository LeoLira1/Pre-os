import 'package:flutter/foundation.dart';

import '../core/comparacao_lojas.dart';
import '../core/custo.dart';
import '../core/formato.dart';
import '../core/generico.dart';
import '../core/grupos.dart';
import '../core/rota_compras.dart';
import '../core/texto.dart';
import '../core/vinculo.dart';
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
    this.porLoja = const <PrecoNaLoja>[],
  });

  final Produto produto;
  final EstatisticasProduto estatisticas;

  /// Registro de preco mais recente deste produto, quando houver.
  final Preco? ultimoRegistro;

  /// Ultimo preco em cada loja, do mais barato para o mais caro.
  final List<PrecoNaLoja> porLoja;

  /// A loja onde esta mais barato, quando ha precos.
  PrecoNaLoja? get maisBarata => porLoja.isEmpty ? null : porLoja.first;

  bool get temVariasLojas => porLoja.length > 1;
}

class GrupoResumo {
  const GrupoResumo({
    required this.grupo,
    required this.produtos,
    required this.estatisticas,
    required this.porLoja,
    this.empatados = const <int>{},
    this.ultimoRegistro,
  });

  final Grupo grupo;
  final List<Produto> produtos;
  final EstatisticasProduto estatisticas;
  final List<PrecoNaLoja> porLoja;

  /// Indices de [porLoja] praticamente empatados com o mais barato.
  final Set<int> empatados;
  final Preco? ultimoRegistro;

  PrecoNaLoja? get maisBarata => porLoja.isEmpty ? null : porLoja.first;
  bool get temVariasLojas => porLoja.length > 1;

  /// Grupo generico: compara marcas e embalagens diferentes entre si.
  bool get generico => grupo.ignoraMarca;

  /// Quantas marcas diferentes estao neste grupo.
  int get quantidadeDeMarcas => produtos
      .map((p) => normalizar(p.marca))
      .where((m) => m.isNotEmpty)
      .toSet()
      .length;
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

  /// Modo de raciocinio do modelo na extracao por foto.
  bool raciocinio = false;

  /// Precos da API usados para estimar o custo.
  TabelaPrecos precosApi = const TabelaPrecos();

  /// Loja escolhida na ultima importacao por foto.
  String ultimaLoja = '';

  /// Os grupos genericos aceitos na tela Juntar ja nascem comparando marcas.
  bool compararMarcasPadrao = true;

  CacheConteudo _conteudo = CacheConteudo.vazio;
  bool carregando = true;
  bool sincronizando = false;
  String? ultimoErro;

  CacheConteudo get conteudo => _conteudo;
  DateTime? get atualizadoEm => _conteudo.atualizadoEm;
  bool get temCredenciais => url.trim().isNotEmpty && token.trim().isNotEmpty;
  bool get temDados => !_conteudo.estaVazio;
  bool get temChaveDeepseek => chaveDeepseek.trim().isNotEmpty;

  List<Produto> get produtos => _conteudo.produtos;
  List<Grupo> get grupos => _conteudo.grupos;
  List<ProdutoGrupo> get produtoGrupos => _conteudo.produtoGrupos;
  List<Apelido> get apelidos => _conteudo.apelidos;
  List<Loja> get lojas => _conteudo.lojas;
  double get custoAcumuladoUsd => _conteudo.custoAcumuladoUsd;

  /// Nomes das lojas em ordem alfabetica, para o seletor da importacao.
  List<String> get nomesDasLojas {
    final nomes = _conteudo.lojas.map((l) => l.nome).toList();
    nomes.sort((a, b) => normalizar(a).compareTo(normalizar(b)));
    return nomes;
  }

  /// Media historica do produto, na mesma base usada nas estatisticas
  /// (preco_ref quando existe, senao preco). Null quando nao ha historico.
  double? mediaHistorica(int produtoId) {
    final precos = precosDoProduto(produtoId);
    if (precos.isEmpty) return null;
    final soma = precos.fold<double>(0, (t, p) => t + p.valorComparavel);
    return soma / precos.length;
  }

  /// Preco ja gravado para este produto nesta loja, data e tipo.
  /// Null quando ainda nao existe registro.
  Preco? precoJaRegistrado({
    required int produtoId,
    required int lojaId,
    required String data,
    required String tipo,
  }) {
    for (final preco in _conteudo.precos) {
      if (preco.produtoId == produtoId &&
          preco.lojaId == lojaId &&
          preco.data == data &&
          preco.tipo == tipo) {
        return preco;
      }
    }
    return null;
  }

  /// Id da loja pelo nome, ignorando acentos e maiusculas. Null se for nova.
  int? idDaLoja(String nome) {
    final alvo = normalizar(nome);
    for (final loja in _conteudo.lojas) {
      if (normalizar(loja.nome) == alvo) return loja.id;
    }
    return null;
  }

  Map<int, Loja> get lojasPorId => {for (final l in _conteudo.lojas) l.id: l};

  /// Chama no inicio do app: le as credenciais e o cache, sem exigir internet.
  Future<void> iniciar() async {
    url = await _preferencias.lerUrl();
    token = await _preferencias.lerToken();
    chaveDeepseek = await _preferencias.lerChaveDeepseek();
    raciocinio = await _preferencias.lerRaciocinio();
    precosApi = await _preferencias.lerPrecos();
    ultimaLoja = await _preferencias.lerUltimaLoja();
    compararMarcasPadrao = await _preferencias.lerCompararMarcas();
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

  Future<void> salvarRaciocinio(bool ligado) async {
    await _preferencias.salvarRaciocinio(ligado);
    raciocinio = ligado;
    notifyListeners();
  }

  Future<void> salvarPrecosApi(TabelaPrecos novos) async {
    await _preferencias.salvarPrecos(novos);
    precosApi = novos;
    notifyListeners();
  }

  Future<void> salvarCompararMarcasPadrao(bool ligado) async {
    await _preferencias.salvarCompararMarcas(ligado);
    compararMarcasPadrao = ligado;
    notifyListeners();
  }

  Future<void> salvarUltimaLoja(String loja) async {
    await _preferencias.salvarUltimaLoja(loja);
    ultimaLoja = loja.trim();
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
    final nomes = _conteudo.grupos
        .map((p) => (p.categoria ?? '').trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    nomes.sort((a, b) => normalizar(a).compareTo(normalizar(b)));
    return nomes;
  }

  /// Lista da tela inicial, ja filtrada pela busca e pela categoria.
  List<GrupoResumo> produtosFiltrados({
    String busca = '',
    String? categoria,
    int? lojaId,
  }) {
    final termo = normalizar(busca);
    final resultado = <GrupoResumo>[];
    for (final grupo in _conteudo.grupos) {
      final membros = produtosDoGrupo(grupo.id);
      if (membros.isEmpty) continue;
      if (categoria != null && (grupo.categoria ?? '') != categoria) continue;
      if (termo.isNotEmpty &&
          !contemBusca(grupo.nome, termo) &&
          !contemBusca(grupo.nomeGenerico, termo) &&
          !membros.any((p) =>
              contemBusca(p.nome, termo) || contemBusca(p.marca, termo))) {
        continue;
      }
      final precos = precosDoGrupo(grupo.id);
      // Filtro por loja: so entra quem tem preco naquela loja.
      if (lojaId != null && !precos.any((p) => p.lojaId == lojaId)) continue;

      final ordenados = [...precos]..sort((a, b) => a.data.compareTo(b.data));
      final porLoja = compararLojas(
        precos: ordenados,
        nomeDaLoja: nomeDaLoja,
        nomeDoProduto: (id) => produtoPorId(id)?.nome ?? 'Produto $id',
        produtoPorId: produtoPorId,
      );
      resultado.add(
        GrupoResumo(
          grupo: grupo,
          produtos: membros,
          estatisticas: EstatisticasProduto.calcular(ordenados),
          ultimoRegistro: ordenados.isEmpty ? null : ordenados.last,
          porLoja: porLoja,
          empatados: indicesEmpatados(porLoja),
        ),
      );
    }

    resultado.sort((a, b) {
      final dataA = a.estatisticas.dataUltimo ?? '';
      final dataB = b.estatisticas.dataUltimo ?? '';
      final porData = dataB.compareTo(dataA);
      if (porData != 0) return porData;
      return normalizar(a.grupo.nomeParaMostrar)
          .compareTo(normalizar(b.grupo.nomeParaMostrar));
    });
    return resultado;
  }

  Produto? produtoPorId(int id) {
    for (final p in _conteudo.produtos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Grupo? grupoPorId(int id) {
    for (final grupo in _conteudo.grupos) {
      if (grupo.id == id) return grupo;
    }
    return null;
  }

  List<Grupo> gruposDoProduto(int produtoId) {
    final ids = _conteudo.produtoGrupos
        .where((v) => v.produtoId == produtoId)
        .map((v) => v.grupoId)
        .toSet();
    return _conteudo.grupos.where((g) => ids.contains(g.id)).toList();
  }

  List<Produto> produtosDoGrupo(int grupoId) {
    final ids = _conteudo.produtoGrupos
        .where((v) => v.grupoId == grupoId)
        .map((v) => v.produtoId)
        .toSet();
    return _conteudo.produtos.where((p) => ids.contains(p.id)).toList();
  }

  List<Preco> precosDoGrupo(int grupoId) {
    final ids = produtosDoGrupo(grupoId).map((p) => p.id).toSet();
    final lista = _conteudo.precos.where((p) => ids.contains(p.produtoId)).toList();
    lista.sort((a, b) => a.data.compareTo(b.data));
    return lista;
  }

  String? unidadeDoProduto(int produtoId) {
    final precos = precosDoProduto(produtoId).where((p) =>
        (p.unidadeRef ?? '').trim().isNotEmpty).toList();
    return precos.isEmpty ? null : precos.last.unidadeRef;
  }

  // As duas listas de sugestao sao caras de montar e as telas pedem elas a
  // cada rebuild. Como so mudam quando o conteudo muda, ficam guardadas.
  CacheConteudo? _conteudoDasSugestoes;
  List<SugestaoGrupo> _sugestoes = const <SugestaoGrupo>[];
  List<SugestaoGenerica> _genericas = const <SugestaoGenerica>[];

  void _calcularSugestoes() {
    if (identical(_conteudoDasSugestoes, _conteudo)) return;

    _genericas = gerarSugestoesGenericas(
      grupos: _conteudo.grupos,
      produtosDoGrupo: produtosDoGrupo,
      unidadeDoGrupo: unidadeDoGrupo,
      rejeitadas: {
        for (final r in _conteudo.sugestoesGenericasRejeitadas) r.identidade,
      },
    );

    // Um grupo que ja esta numa sugestao generica nao precisa aparecer
    // tambem produto a produto: juntar os grupos resolve os dois casos.
    final gruposNasGenericas = <int>{
      for (final generica in _genericas)
        for (final grupo in generica.grupos) grupo.id,
    };
    _sugestoes = <SugestaoGrupo>[
      for (final sugestao in gerarSugestoesGrupos(
        produtos: _conteudo.produtos,
        grupos: _conteudo.grupos,
        vinculos: _conteudo.produtoGrupos,
        rejeitadas: _conteudo.sugestoesRejeitadas,
        unidadeDoProduto: unidadeDoProduto,
      ))
        if (!(sugestao.generica &&
            gruposNasGenericas.contains(sugestao.grupo.id)))
          sugestao,
    ];
    _conteudoDasSugestoes = _conteudo;
  }

  List<SugestaoGrupo> get sugestoesPendentes {
    _calcularSugestoes();
    return _sugestoes;
  }

  SugestaoGrupo? melhorSugestaoParaProduto(int produtoId) {
    final vinculos = _conteudo.produtoGrupos
        .where((v) => v.produtoId == produtoId)
        .toList();
    if (vinculos.any((v) => v.origem != 'automatico')) return null;
    for (final sugestao in sugestoesPendentes) {
      if (sugestao.produto.id == produtoId) return sugestao;
    }
    return null;
  }

  Future<void> aceitarSugestao(SugestaoGrupo sugestao) async {
    final conexao = abrirConexao();
    try {
      await conexao.aceitarSugestao(sugestao.produto.id, sugestao.grupo.id);
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  Future<void> rejeitarSugestao(SugestaoGrupo sugestao) async {
    final conexao = abrirConexao();
    try {
      await conexao.rejeitarSugestao(sugestao.produto.id, sugestao.grupo.id);
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  Future<void> juntarManual(int produtoId, int grupoId) async {
    final conexao = abrirConexao();
    try {
      await conexao.juntarManual(produtoId, grupoId);
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  Future<void> separarDoGrupo(int produtoId, int grupoId) async {
    final conexao = abrirConexao();
    try {
      await conexao.separarDoGrupo(produtoId, grupoId);
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  Future<void> renomearGrupo(int grupoId, String nome) async {
    final conexao = abrirConexao();
    try {
      await conexao.renomearGrupo(grupoId, nome);
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  /// Liga ou desliga o botao "Comparar entre marcas" de um grupo.
  Future<void> alternarCompararMarcas(int grupoId, bool ligado) async {
    final grupo = grupoPorId(grupoId);
    final resumo = grupo == null
        ? null
        : descreverGrupo(grupo: grupo, produtos: produtosDoGrupo(grupoId));
    final conexao = abrirConexao();
    try {
      await conexao.definirIgnoraMarca(
        grupoId,
        ligado,
        // Ao ligar, o nome que aparece passa a ser o nome sem marca.
        nomeGenerico: ligado ? resumo?.nome : null,
      );
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  /// Sugestoes de juntar grupos de marcas diferentes num grupo generico.
  List<SugestaoGenerica> get sugestoesGenericas {
    _calcularSugestoes();
    return _genericas;
  }

  /// Unidade de referencia do grupo: a gravada, ou a do preco mais recente.
  String? unidadeDoGrupo(int grupoId) {
    final gravada = (grupoPorId(grupoId)?.unidadeRef ?? '').trim();
    if (gravada.isNotEmpty) return gravada;
    for (final produto in produtosDoGrupo(grupoId)) {
      final unidade = unidadeDoProduto(produto.id);
      if ((unidade ?? '').trim().isNotEmpty) return unidade;
    }
    return null;
  }

  Future<void> aceitarSugestaoGenerica(SugestaoGenerica sugestao) async {
    final conexao = abrirConexao();
    try {
      await conexao.juntarGruposGenerico(
        grupoIds: sugestao.idsParaJuntar,
        nomeGenerico: sugestao.nomeGenerico,
        ignoraMarca: compararMarcasPadrao,
      );
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  /// Aceita varias sugestoes de uma vez, numa conexao so.
  Future<void> aceitarSugestoesGenericas(
    List<SugestaoGenerica> sugestoes,
  ) async {
    if (sugestoes.isEmpty) return;
    final conexao = abrirConexao();
    try {
      for (final sugestao in sugestoes) {
        await conexao.juntarGruposGenerico(
          grupoIds: sugestao.idsParaJuntar,
          nomeGenerico: sugestao.nomeGenerico,
          ignoraMarca: compararMarcasPadrao,
        );
      }
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  Future<void> rejeitarSugestaoGenerica(SugestaoGenerica sugestao) async {
    final conexao = abrirConexao();
    try {
      await conexao.rejeitarSugestaoGenerica(sugestao.identidade);
    } finally {
      await conexao.fechar();
    }
    await sincronizar();
  }

  /// Monta a rota de compras dos grupos escolhidos.
  ///
  /// Num grupo generico a resposta ja vem com a marca e a embalagem mais
  /// baratas por unidade de referencia.
  List<ItemDaRota> itensDaRota(Iterable<int> grupoIds) {
    final itens = <ItemDaRota>[];
    for (final grupoId in grupoIds) {
      final grupo = grupoPorId(grupoId);
      if (grupo == null) continue;
      itens.add(
        montarItemDaRota(
          grupo: grupo,
          precos: precosDoGrupo(grupoId),
          nomeDaLoja: nomeDaLoja,
          produtoPorId: produtoPorId,
        ),
      );
    }
    return itens;
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
