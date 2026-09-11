/// Por que um item precisa de conferencia antes de gravar.
enum MotivoConferir {
  /// O modelo disse que nao leu com seguranca.
  confiancaBaixa,

  /// Preco muito fora da media historica do produto.
  foraDaFaixa,

  /// Preco impossivel: zero, negativo ou acima de mil reais.
  precoImplausivel,
}

extension MotivoConferirTexto on MotivoConferir {
  /// Frase curta mostrada na tela de revisao.
  String get descricao {
    switch (this) {
      case MotivoConferir.confiancaBaixa:
        return 'O modelo nao leu com seguranca';
      case MotivoConferir.foraDaFaixa:
        return 'Preco bem diferente do historico';
      case MotivoConferir.precoImplausivel:
        return 'Preco fora do esperado';
    }
  }
}

/// Preco acima disto quase certamente e erro de leitura do tabloide.
const double precoMaximoPlausivel = 1000;

/// Decide se o item merece o selo ambar "Conferir".
///
/// [mediaHistorica] e a media dos precos ja registrados do produto vinculado
/// (sobre preco_ref quando existe, senao preco), ou null quando o produto e
/// novo ou ainda nao tem historico.
///
/// [valorComparavel] precisa estar na mesma base da media: se a media veio de
/// preco_ref, passe o preco_ref calculado deste item.
Set<MotivoConferir> motivosParaConferir({
  required double? preco,
  required String confianca,
  double? valorComparavel,
  double? mediaHistorica,
}) {
  final motivos = <MotivoConferir>{};

  if (confianca.toLowerCase() == 'baixa') {
    motivos.add(MotivoConferir.confiancaBaixa);
  }

  if (preco == null || preco <= 0 || preco > precoMaximoPlausivel) {
    motivos.add(MotivoConferir.precoImplausivel);
  }

  final valor = valorComparavel ?? preco;
  if (valor != null &&
      valor > 0 &&
      mediaHistorica != null &&
      mediaHistorica > 0) {
    // Fora da faixa de metade ate o dobro da media.
    if (valor < mediaHistorica * 0.5 || valor > mediaHistorica * 2) {
      motivos.add(MotivoConferir.foraDaFaixa);
    }
  }

  return motivos;
}
