/// Converte o valor vindo do banco (ou do cache) para int, com seguranca.
int? comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is BigInt) return valor.toInt();
  if (valor is double) return valor.toInt();
  return int.tryParse(valor.toString());
}

/// Converte o valor vindo do banco (ou do cache) para double, com seguranca.
double? comoDouble(dynamic valor) {
  if (valor == null) return null;
  if (valor is double) return valor;
  if (valor is int) return valor.toDouble();
  if (valor is BigInt) return valor.toDouble();
  return double.tryParse(valor.toString());
}

String? comoTexto(dynamic valor) {
  if (valor == null) return null;
  final texto = valor.toString();
  return texto.isEmpty ? null : texto;
}

class Loja {
  const Loja({required this.id, required this.nome});

  final int id;
  final String nome;

  factory Loja.doMapa(Map<String, dynamic> m) =>
      Loja(id: comoInt(m['id'])!, nome: comoTexto(m['nome']) ?? '');

  Map<String, dynamic> paraMapa() => {'id': id, 'nome': nome};
}

class Produto {
  const Produto({
    required this.id,
    required this.chave,
    required this.nome,
    this.marca,
    this.categoria,
    this.embalagemQtd,
    this.embalagemUnidade,
    this.unidadeVenda,
    this.ean,
    this.criadoEm,
  });

  final int id;
  final String chave;
  final String nome;
  final String? marca;
  final String? categoria;
  final double? embalagemQtd;
  final String? embalagemUnidade;
  final String? unidadeVenda;
  final String? ean;
  final String? criadoEm;

  factory Produto.doMapa(Map<String, dynamic> m) => Produto(
        id: comoInt(m['id'])!,
        chave: comoTexto(m['chave']) ?? '',
        nome: comoTexto(m['nome']) ?? '',
        marca: comoTexto(m['marca']),
        categoria: comoTexto(m['categoria']),
        embalagemQtd: comoDouble(m['embalagem_qtd']),
        embalagemUnidade: comoTexto(m['embalagem_unidade']),
        unidadeVenda: comoTexto(m['unidade_venda']),
        ean: comoTexto(m['ean']),
        criadoEm: comoTexto(m['criado_em']),
      );

  Map<String, dynamic> paraMapa() => {
        'id': id,
        'chave': chave,
        'nome': nome,
        'marca': marca,
        'categoria': categoria,
        'embalagem_qtd': embalagemQtd,
        'embalagem_unidade': embalagemUnidade,
        'unidade_venda': unidadeVenda,
        'ean': ean,
        'criado_em': criadoEm,
      };
}

/// Produto base usado para comparar nomes diferentes entre lojas.
class Grupo {
  const Grupo({
    required this.id,
    required this.nome,
    this.categoria,
    this.unidadeRef,
    this.ignoraMarca = false,
    this.nomeGenerico,
    this.criadoEm,
  });

  final int id;
  final String nome;
  final String? categoria;
  final String? unidadeRef;

  /// Grupo generico: aceita produtos de marcas diferentes e de tamanhos de
  /// embalagem diferentes, desde que a unidade de referencia seja a mesma.
  final bool ignoraMarca;

  /// O nome sem marca e sem embalagem ("Agua Sanitaria"). So e preenchido
  /// nos grupos genericos.
  final String? nomeGenerico;
  final String? criadoEm;

  /// O que mostrar na tela: o nome generico quando existe.
  String get nomeParaMostrar {
    final generico = (nomeGenerico ?? '').trim();
    return generico.isEmpty ? nome : generico;
  }

  factory Grupo.doMapa(Map<String, dynamic> m) => Grupo(
        id: comoInt(m['id'])!,
        nome: comoTexto(m['nome']) ?? '',
        categoria: comoTexto(m['categoria']),
        unidadeRef: comoTexto(m['unidade_ref']),
        ignoraMarca: (comoInt(m['ignora_marca']) ?? 0) != 0,
        nomeGenerico: comoTexto(m['nome_generico']),
        criadoEm: comoTexto(m['criado_em']),
      );

  Map<String, dynamic> paraMapa() => {
        'id': id,
        'nome': nome,
        'categoria': categoria,
        'unidade_ref': unidadeRef,
        'ignora_marca': ignoraMarca ? 1 : 0,
        'nome_generico': nomeGenerico,
        'criado_em': criadoEm,
      };
}

class ProdutoGrupo {
  const ProdutoGrupo({
    required this.produtoId,
    required this.grupoId,
    required this.origem,
  });

  final int produtoId;
  final int grupoId;
  final String origem;

  factory ProdutoGrupo.doMapa(Map<String, dynamic> m) => ProdutoGrupo(
        produtoId: comoInt(m['produto_id'])!,
        grupoId: comoInt(m['grupo_id'])!,
        origem: comoTexto(m['origem']) ?? 'automatico',
      );

  Map<String, dynamic> paraMapa() => {
        'produto_id': produtoId,
        'grupo_id': grupoId,
        'origem': origem,
      };
}

class SugestaoRejeitada {
  const SugestaoRejeitada({
    required this.produtoId,
    required this.grupoId,
    this.criadoEm,
  });

  final int produtoId;
  final int grupoId;
  final String? criadoEm;

  factory SugestaoRejeitada.doMapa(Map<String, dynamic> m) =>
      SugestaoRejeitada(
        produtoId: comoInt(m['produto_id'])!,
        grupoId: comoInt(m['grupo_id'])!,
        criadoEm: comoTexto(m['criado_em']),
      );

  Map<String, dynamic> paraMapa() => {
        'produto_id': produtoId,
        'grupo_id': grupoId,
        'criado_em': criadoEm,
      };
}

/// Uma sugestao de grupo generico que o usuario recusou.
///
/// Guardada pela identidade da sugestao (nome generico + unidade de
/// referencia), para nao aparecer de novo a cada sincronizacao.
class SugestaoGenericaRejeitada {
  const SugestaoGenericaRejeitada({required this.identidade, this.criadoEm});

  final String identidade;
  final String? criadoEm;

  factory SugestaoGenericaRejeitada.doMapa(Map<String, dynamic> m) =>
      SugestaoGenericaRejeitada(
        identidade: comoTexto(m['identidade']) ?? '',
        criadoEm: comoTexto(m['criado_em']),
      );

  Map<String, dynamic> paraMapa() => {
        'identidade': identidade,
        'criado_em': criadoEm,
      };
}

class Preco {
  const Preco({
    required this.id,
    required this.produtoId,
    required this.lojaId,
    required this.data,
    required this.preco,
    required this.tipo,
    this.precoRef,
    this.unidadeRef,
    this.embalagemQtd,
    this.embalagemUnidade,
    this.limitePorCliente,
    this.observacao,
    this.fonte,
    this.criadoEm,
  });

  final int id;
  final int produtoId;
  final int lojaId;
  final String data;
  final double preco;
  final String tipo;
  final double? precoRef;
  final String? unidadeRef;
  final double? embalagemQtd;
  final String? embalagemUnidade;
  final int? limitePorCliente;
  final String? observacao;
  final String? fonte;
  final String? criadoEm;

  /// Valor usado nas estatisticas e no grafico: o preco de referencia quando
  /// existe, senao o preco cheio.
  double get valorComparavel => precoRef ?? preco;

  factory Preco.doMapa(Map<String, dynamic> m) => Preco(
        id: comoInt(m['id'])!,
        produtoId: comoInt(m['produto_id'])!,
        lojaId: comoInt(m['loja_id'])!,
        data: comoTexto(m['data']) ?? '',
        preco: comoDouble(m['preco']) ?? 0,
        tipo: comoTexto(m['tipo']) ?? 'oferta',
        precoRef: comoDouble(m['preco_ref']),
        unidadeRef: comoTexto(m['unidade_ref']),
        embalagemQtd: comoDouble(m['embalagem_qtd']),
        embalagemUnidade: comoTexto(m['embalagem_unidade']),
        limitePorCliente: comoInt(m['limite_por_cliente']),
        observacao: comoTexto(m['observacao']),
        fonte: comoTexto(m['fonte']),
        criadoEm: comoTexto(m['criado_em']),
      );

  Map<String, dynamic> paraMapa() => {
        'id': id,
        'produto_id': produtoId,
        'loja_id': lojaId,
        'data': data,
        'preco': preco,
        'preco_ref': precoRef,
        'unidade_ref': unidadeRef,
        'embalagem_qtd': embalagemQtd,
        'embalagem_unidade': embalagemUnidade,
        'tipo': tipo,
        'limite_por_cliente': limitePorCliente,
        'observacao': observacao,
        'fonte': fonte,
        'criado_em': criadoEm,
      };
}

/// Numeros calculados sobre o historico de um produto.
class EstatisticasProduto {
  const EstatisticasProduto({
    required this.registros,
    this.ultimo,
    this.menor,
    this.maior,
    this.media,
    this.unidadeRef,
    this.dataUltimo,
    this.lojaIdMenor,
    this.lojaIdMaior,
    this.usandoPrecoRef = false,
  });

  final int registros;
  final double? ultimo;
  final double? menor;
  final double? maior;
  final double? media;
  final String? unidadeRef;
  final String? dataUltimo;

  /// Em que loja saiu o menor e o maior preco ja registrado.
  final int? lojaIdMenor;
  final int? lojaIdMaior;

  /// Verdadeiro quando pelo menos um registro tinha preco_ref preenchido.
  final bool usandoPrecoRef;

  static const EstatisticasProduto vazio = EstatisticasProduto(registros: 0);

  /// Calcula tudo sobre preco_ref; quando preco_ref e nulo, usa preco.
  factory EstatisticasProduto.calcular(List<Preco> precos) {
    if (precos.isEmpty) return vazio;
    final ordenados = [...precos]..sort((a, b) => a.data.compareTo(b.data));
    final valores = ordenados.map((p) => p.valorComparavel).toList();
    final ultimoRegistro = ordenados.last;

    // Guarda tambem de qual loja veio o menor e o maior preco.
    var registroMenor = ordenados.first;
    var registroMaior = ordenados.first;
    for (final preco in ordenados) {
      if (preco.valorComparavel < registroMenor.valorComparavel) {
        registroMenor = preco;
      }
      if (preco.valorComparavel > registroMaior.valorComparavel) {
        registroMaior = preco;
      }
    }

    return EstatisticasProduto(
      registros: ordenados.length,
      ultimo: ultimoRegistro.valorComparavel,
      menor: registroMenor.valorComparavel,
      maior: registroMaior.valorComparavel,
      media: valores.reduce((a, b) => a + b) / valores.length,
      lojaIdMenor: registroMenor.lojaId,
      lojaIdMaior: registroMaior.lojaId,
      // So mostra "/kg" quando o numero realmente veio de preco_ref.
      unidadeRef:
          ultimoRegistro.precoRef != null ? ultimoRegistro.unidadeRef : null,
      dataUltimo: ultimoRegistro.data,
      usandoPrecoRef: ordenados.any((p) => p.precoRef != null),
    );
  }
}
