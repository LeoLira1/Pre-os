import '../modelos/modelos.dart';
import 'extracao_json.dart';
import 'similaridade.dart';
import 'texto.dart';

/// Como o item da foto foi ligado a um produto do banco.
enum TipoVinculo {
  /// Achado pelo texto do tabloide ja visto antes nesta loja.
  apelido,

  /// Achado pela chave (nome + marca + embalagem).
  chave,

  /// Um candidato parecido demais para ser outro produto: ligado sozinho.
  automatico,

  /// Ha candidatos, mas quem escolhe e o usuario.
  sugestao,

  /// Nenhum parecido: vai virar produto novo.
  novo,
}

/// Resultado da procura de um produto para o item da foto.
class Vinculo {
  const Vinculo({
    required this.tipo,
    this.produtoId,
    this.sugestoes = const <Candidato<Produto>>[],
  });

  final TipoVinculo tipo;
  final int? produtoId;

  /// As 3 melhores opcoes, quando o app nao tem certeza.
  final List<Candidato<Produto>> sugestoes;

  bool get existente => produtoId != null;

  static const Vinculo produtoNovo = Vinculo(tipo: TipoVinculo.novo);
}

/// Um apelido ja gravado: o texto do tabloide e o produto ao qual pertence.
class Apelido {
  const Apelido({
    required this.produtoId,
    required this.textoOriginal,
    this.lojaId,
  });

  final int produtoId;
  final String textoOriginal;
  final int? lojaId;

  factory Apelido.doMapa(Map<String, dynamic> m) => Apelido(
        produtoId: comoInt(m['produto_id'])!,
        textoOriginal: comoTexto(m['texto_original']) ?? '',
        lojaId: comoInt(m['loja_id']),
      );

  Map<String, dynamic> paraMapa() => {
        'produto_id': produtoId,
        'texto_original': textoOriginal,
        'loja_id': lojaId,
      };
}

/// Procura o produto certo para um item lido da foto.
///
/// A ordem importa e resolve o problema do dia a dia: o mesmo tabloide
/// escreve o produto igual toda semana, mas o nome padronizado pelo modelo
/// pode mudar um pouco. Por isso o texto original manda mais que o nome.
///
/// 1. Texto original ja visto nesta loja (produto_apelidos).
/// 2. Chave exata: nome + marca + embalagem.
/// 3. Candidatos com a mesma embalagem (e mesma marca, se houver),
///    ranqueados por semelhanca de nome.
Vinculo procurarProduto({
  required ItemExtraido item,
  required List<Produto> produtos,
  required List<Apelido> apelidos,
  int? lojaId,
}) {
  final textoNormalizado = normalizar(item.textoOriginal);
  final produtosPorId = {for (final p in produtos) p.id: p};

  // 1. Apelido da mesma loja tem prioridade; depois, apelido de qualquer loja.
  if (textoNormalizado.isNotEmpty) {
    Apelido? daMesmaLoja;
    Apelido? deQualquerLoja;
    for (final apelido in apelidos) {
      if (normalizar(apelido.textoOriginal) != textoNormalizado) continue;
      if (!produtosPorId.containsKey(apelido.produtoId)) continue;
      if (lojaId != null && apelido.lojaId == lojaId) {
        daMesmaLoja = apelido;
        break;
      }
      deQualquerLoja ??= apelido;
    }
    final achado = daMesmaLoja ?? deQualquerLoja;
    if (achado != null) {
      return Vinculo(tipo: TipoVinculo.apelido, produtoId: achado.produtoId);
    }
  }

  // 2. Chave exata.
  final chave = montarChaveProduto(
    nome: item.produto,
    marca: item.marca,
    embalagemQtd: item.embalagemQtd,
    embalagemUnidade: item.embalagemUnidade,
  );
  for (final produto in produtos) {
    if (produto.chave == chave) {
      return Vinculo(tipo: TipoVinculo.chave, produtoId: produto.id);
    }
  }

  // 3. Mesma embalagem (e mesma marca, quando o item tem marca).
  final marcaItem = normalizar(item.marca);
  final candidatos = produtos.where((produto) {
    if (!_mesmaEmbalagem(produto, item)) return false;
    if (marcaItem.isEmpty) return true;
    final marcaProduto = normalizar(produto.marca);
    return marcaProduto.isEmpty || marcaProduto == marcaItem;
  });

  final ranqueados = ranquearCandidatos<Produto>(
    nomeBuscado: item.produto,
    candidatos: candidatos,
    nomeDe: (p) => p.nome,
    limite: 3,
  ).where((c) => c.nota > 0).toList();

  if (ranqueados.isEmpty) return Vinculo.produtoNovo;

  // Um so candidato e muito parecido: liga sozinho, mas mostra o aviso.
  if (ranqueados.first.nota >= limiarVinculoAutomatico &&
      (ranqueados.length == 1 ||
          ranqueados[1].nota < limiarVinculoAutomatico)) {
    return Vinculo(
      tipo: TipoVinculo.automatico,
      produtoId: ranqueados.first.item.id,
      sugestoes: ranqueados,
    );
  }

  return Vinculo(tipo: TipoVinculo.sugestao, sugestoes: ranqueados);
}

bool _mesmaEmbalagem(Produto produto, ItemExtraido item) {
  final mesmaQtd = formatarNumeroCanonico(produto.embalagemQtd) ==
      formatarNumeroCanonico(item.embalagemQtd);
  final mesmaUnidade =
      normalizar(produto.embalagemUnidade) == normalizar(item.embalagemUnidade);
  return mesmaQtd && mesmaUnidade;
}
