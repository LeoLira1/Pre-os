import 'conferir.dart';
import 'extracao_json.dart';
import 'preco_ref.dart';
import 'vinculo.dart';

/// Um item da foto na tela de revisao, com o que o usuario ja mexeu nele.
class ItemRevisao {
  ItemRevisao({
    required this.fotoId,
    required this.item,
    required this.vinculo,
    this.manual = false,
  });

  /// A qual foto do lote este item pertence.
  final String fotoId;

  ItemExtraido item;
  Vinculo vinculo;

  /// Item digitado a mao, nao lido pelo modelo.
  final bool manual;

  /// Marcado para nao ser gravado.
  bool excluido = false;

  /// Produto escolhido na mao, quando o usuario troca o vinculo.
  int? produtoEscolhido;

  /// Verdadeiro quando o usuario disse explicitamente "criar produto novo".
  bool forcarProdutoNovo = false;

  /// Produto ao qual este item vai ser ligado, ou null para criar um novo.
  int? get produtoId {
    if (forcarProdutoNovo) return null;
    return produtoEscolhido ?? vinculo.produtoId;
  }

  bool get produtoNovo => produtoId == null;

  /// O app ligou sozinho por semelhanca alta: vale mostrar o aviso.
  bool get vinculadoAutomaticamente =>
      !forcarProdutoNovo &&
      produtoEscolhido == null &&
      vinculo.tipo == TipoVinculo.automatico;

  /// Ha sugestoes para o usuario escolher.
  bool get temSugestoes =>
      produtoEscolhido == null &&
      !forcarProdutoNovo &&
      vinculo.tipo == TipoVinculo.sugestao &&
      vinculo.sugestoes.isNotEmpty;

  /// Preco por kg, L, un ou rolo, calculado pelo app.
  PrecoReferencia get precoRef => calcularPrecoRef(
        preco: item.preco,
        embalagemQtd: item.embalagemQtd,
        embalagemUnidade: item.embalagemUnidade,
      );

  /// Valor usado para comparar com o historico.
  double? get valorComparavel => precoRef.valor ?? item.preco;

  /// Motivos do selo ambar "Conferir".
  ///
  /// [mediaHistorica] e a media do produto vinculado, ou null quando o
  /// produto e novo ou ainda nao tem historico.
  Set<MotivoConferir> conferir({double? mediaHistorica}) =>
      motivosParaConferir(
        preco: item.preco,
        confianca: item.confianca,
        valorComparavel: valorComparavel,
        mediaHistorica: mediaHistorica,
      );
}

/// Contagens mostradas no topo da tela de revisao.
class ResumoRevisao {
  const ResumoRevisao({
    required this.itens,
    required this.novos,
    required this.paraConferir,
    required this.jaRegistrados,
  });

  final int itens;
  final int novos;
  final int paraConferir;
  final int jaRegistrados;
}
