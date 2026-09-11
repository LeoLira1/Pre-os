/// Precos da API em dolares por milhao de tokens.
///
/// Os padroes sao os valores de fora do horario de pico da DeepSeek para o
/// modelo deepseek-flash. Ficam editaveis na tela de Configuracao porque a
/// tabela de precos pode mudar.
class TabelaPrecos {
  const TabelaPrecos({
    this.entradaSemCache = 0.15,
    this.entradaComCache = 0.003,
    this.saida = 0.60,
    this.picoDobra = true,
  });

  final double entradaSemCache;
  final double entradaComCache;
  final double saida;

  /// No horario de pico a DeepSeek cobra o dobro.
  final bool picoDobra;

  TabelaPrecos copiarCom({
    double? entradaSemCache,
    double? entradaComCache,
    double? saida,
    bool? picoDobra,
  }) =>
      TabelaPrecos(
        entradaSemCache: entradaSemCache ?? this.entradaSemCache,
        entradaComCache: entradaComCache ?? this.entradaComCache,
        saida: saida ?? this.saida,
        picoDobra: picoDobra ?? this.picoDobra,
      );
}

/// Tokens gastos numa chamada, como vem na resposta da API.
class UsoTokens {
  const UsoTokens({
    this.entradaSemCache = 0,
    this.entradaComCache = 0,
    this.saida = 0,
  });

  final int entradaSemCache;
  final int entradaComCache;
  final int saida;

  int get entradaTotal => entradaSemCache + entradaComCache;

  UsoTokens mais(UsoTokens outro) => UsoTokens(
        entradaSemCache: entradaSemCache + outro.entradaSemCache,
        entradaComCache: entradaComCache + outro.entradaComCache,
        saida: saida + outro.saida,
      );

  Map<String, dynamic> paraMapa() => {
        'entrada_sem_cache': entradaSemCache,
        'entrada_com_cache': entradaComCache,
        'saida': saida,
      };

  factory UsoTokens.doMapa(Map<String, dynamic> m) => UsoTokens(
        entradaSemCache: (m['entrada_sem_cache'] as num?)?.toInt() ?? 0,
        entradaComCache: (m['entrada_com_cache'] as num?)?.toInt() ?? 0,
        saida: (m['saida'] as num?)?.toInt() ?? 0,
      );
}

/// Horario de pico da DeepSeek: 01:00-04:00 e 06:00-10:00 UTC, de segunda
/// a sexta. Fora disso o preco e o normal (mais barato).
bool estaNoHorarioDePico(DateTime momento) {
  final utc = momento.toUtc();
  if (utc.weekday == DateTime.saturday || utc.weekday == DateTime.sunday) {
    return false;
  }
  final hora = utc.hour;
  final entre1e4 = hora >= 1 && hora < 4;
  final entre6e10 = hora >= 6 && hora < 10;
  return entre1e4 || entre6e10;
}

/// Custo estimado em dolares de uma chamada.
///
/// [momento] e a hora em que a requisicao foi feita, para saber se cai no
/// horario de pico.
double estimarCustoUsd({
  required UsoTokens uso,
  required TabelaPrecos precos,
  required DateTime momento,
}) {
  final multiplicador =
      precos.picoDobra && estaNoHorarioDePico(momento) ? 2.0 : 1.0;
  const porMilhao = 1000000;
  final total = (uso.entradaSemCache / porMilhao) * precos.entradaSemCache +
      (uso.entradaComCache / porMilhao) * precos.entradaComCache +
      (uso.saida / porMilhao) * precos.saida;
  return total * multiplicador;
}

/// Mostra valores bem pequenos sem virar "US$ 0,00".
String formatarUsd(double valor) {
  if (valor <= 0) return 'US\$ 0,00';
  if (valor < 0.01) return 'US\$ ${valor.toStringAsFixed(4).replaceAll('.', ',')}';
  return 'US\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
}
