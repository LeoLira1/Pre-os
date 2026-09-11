import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../modelos/modelos.dart';

/// Cores das linhas, uma por loja.
const List<Color> _coresLojas = <Color>[
  Color(0xFF00897B),
  Color(0xFFE65100),
  Color(0xFF3949AB),
  Color(0xFFC2185B),
  Color(0xFF558B2F),
  Color(0xFF6D4C41),
  Color(0xFF00838F),
  Color(0xFF8E24AA),
];

/// Decide entre barras e linhas.
///
/// Linha so faz sentido quando ha evolucao no tempo. Se todos os registros
/// sao do mesmo dia, ou se cada loja so tem um registro, nao ha o que ligar:
/// o que interessa e comparar as lojas lado a lado.
bool deveUsarBarras(List<Preco> precos) {
  if (precos.isEmpty) return false;

  final datas = precos.map((p) => p.data).toSet();
  if (datas.length == 1) return true;

  final porLoja = <int, int>{};
  for (final preco in precos) {
    porLoja[preco.lojaId] = (porLoja[preco.lojaId] ?? 0) + 1;
  }
  return porLoja.values.every((quantos) => quantos <= 1);
}

/// Uma loja com os pontos dela no grafico.
class _SerieLoja {
  _SerieLoja({required this.nome, required this.cor, required this.pontos});

  final String nome;
  final Color cor;
  final List<FlSpot> pontos;
}

/// Grafico de linha do preco ao longo do tempo, uma linha por loja.
///
/// O eixo horizontal e a data de verdade (dias desde o primeiro registro),
/// para que as linhas de lojas diferentes fiquem alinhadas no tempo.
class GraficoPrecos extends StatelessWidget {
  const GraficoPrecos({
    super.key,
    required this.precos,
    this.unidadeRef,
    required this.nomeDaLoja,
  });

  /// Precos ordenados da data mais antiga para a mais nova.
  final List<Preco> precos;
  final String? unidadeRef;

  /// Como descobrir o nome da loja a partir do id.
  final String Function(int lojaId) nomeDaLoja;

  @override
  Widget build(BuildContext context) {
    if (precos.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(
                Icons.show_chart,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('O grafico aparece a partir de 2 registros.'),
              ),
            ],
          ),
        ),
      );
    }

    if (deveUsarBarras(precos)) {
      return _GraficoBarras(
        precos: precos,
        unidadeRef: unidadeRef,
        nomeDaLoja: nomeDaLoja,
      );
    }

    final cores = Theme.of(context).colorScheme;
    final base = DateTime.parse(precos.first.data);

    // Agrupa por loja, mantendo a ordem em que cada loja aparece.
    final porLoja = <int, List<Preco>>{};
    for (final preco in precos) {
      porLoja.putIfAbsent(preco.lojaId, () => <Preco>[]).add(preco);
    }

    final series = <_SerieLoja>[];
    var indiceCor = 0;
    for (final entrada in porLoja.entries) {
      final registros = [...entrada.value]
        ..sort((a, b) => a.data.compareTo(b.data));
      series.add(
        _SerieLoja(
          nome: nomeCurtoLoja(nomeDaLoja(entrada.key)),
          cor: _coresLojas[indiceCor % _coresLojas.length],
          pontos: [
            for (final p in registros)
              FlSpot(_diasDesde(base, p.data), p.valorComparavel),
          ],
        ),
      );
      indiceCor++;
    }

    final valores = precos.map((p) => p.valorComparavel).toList();
    final minimo = valores.reduce((a, b) => a < b ? a : b);
    final maximo = valores.reduce((a, b) => a > b ? a : b);
    final folga = (maximo - minimo) == 0
        ? (maximo == 0 ? 1 : maximo * 0.1)
        : (maximo - minimo) * 0.15;

    final ultimoDia = _diasDesde(base, precos.last.data);
    final intervalo = ultimoDia <= 0 ? 1.0 : (ultimoDia / 4).ceilToDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minY: minimo - folga,
                  maxY: maximo + folga,
                  minX: 0,
                  maxX: ultimoDia == 0 ? 1 : ultimoDia,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: cores.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (valor, meta) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            formatarMoeda(valor),
                            style: Theme.of(context).textTheme.labelSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: intervalo,
                        getTitlesWidget: (valor, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _dataCurta(base.add(Duration(days: valor.round()))),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => cores.inverseSurface,
                      getTooltipItems: (pontosTocados) =>
                          pontosTocados.map((ponto) {
                        final serie = series[ponto.barIndex];
                        final data = base.add(
                          Duration(days: ponto.x.round()),
                        );
                        return LineTooltipItem(
                          '${serie.nome}\n'
                          '${_dataCompleta(data)}\n'
                          '${formatarPrecoRef(ponto.y, unidadeRef)}',
                          TextStyle(
                            color: cores.onInverseSurface,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    for (final serie in series)
                      LineChartBarData(
                        spots: serie.pontos,
                        isCurved: false,
                        color: serie.cor,
                        barWidth: 3,
                        dotData: FlDotData(
                          // Com poucos pontos, a bolinha ajuda a ver onde
                          // cada registro caiu.
                          show: serie.pontos.length <= 30,
                          getDotPainter: (spot, percent, barra, indice) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: serie.cor,
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          // A area colorida so faz sentido com uma loja so;
                          // com varias ela vira sujeira.
                          show: series.length == 1,
                          color: serie.cor.withValues(alpha: 0.12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (series.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final serie in series)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 3,
                          decoration: BoxDecoration(
                            color: serie.cor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          serie.nome,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Quantos dias se passaram entre a primeira data e esta.
  static double _diasDesde(DateTime base, String iso) {
    final data = DateTime.tryParse(iso);
    if (data == null) return 0;
    return data.difference(base).inDays.toDouble();
  }

  static String _dataCurta(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}';

  static String _dataCompleta(DateTime data) =>
      '${_dataCurta(data)}/${data.year}';
}

/// Comparacao entre lojas em barras.
///
/// Usado quando nao ha evolucao no tempo para desenhar: todos os registros
/// no mesmo dia, ou uma leitura por loja.
class _GraficoBarras extends StatelessWidget {
  const _GraficoBarras({
    required this.precos,
    required this.unidadeRef,
    required this.nomeDaLoja,
  });

  final List<Preco> precos;
  final String? unidadeRef;
  final String Function(int lojaId) nomeDaLoja;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    // O registro mais recente de cada loja, do mais barato para o mais caro.
    final maisRecente = <int, Preco>{};
    for (final preco in precos) {
      final atual = maisRecente[preco.lojaId];
      if (atual == null || preco.data.compareTo(atual.data) > 0) {
        maisRecente[preco.lojaId] = preco;
      }
    }
    final barras = maisRecente.values.toList()
      ..sort((a, b) => a.valorComparavel.compareTo(b.valorComparavel));

    final maximo = barras
        .map((p) => p.valorComparavel)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maximo * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: cores.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (valor, meta) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            formatarMoeda(valor),
                            style: Theme.of(context).textTheme.labelSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (valor, meta) {
                          final indice = valor.round();
                          if (indice < 0 || indice >= barras.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              nomeCurtoLoja(nomeDaLoja(barras[indice].lojaId)),
                              style: Theme.of(context).textTheme.labelSmall,
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => cores.inverseSurface,
                      getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
                        final preco = barras[grupo.x];
                        return BarTooltipItem(
                          '${nomeCurtoLoja(nomeDaLoja(preco.lojaId))}\n'
                          '${formatarData(preco.data)}\n'
                          '${formatarPrecoRef(preco.valorComparavel, unidadeRef)}',
                          TextStyle(
                            color: cores.onInverseSurface,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < barras.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: barras[i].valorComparavel,
                            // A mais barata em destaque.
                            color: i == 0
                                ? _coresLojas.first
                                : cores.outline,
                            width: 28,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              barras.length == 1
                  ? 'Um registro por loja: comparação lado a lado.'
                  : 'Todos os preços são da mesma data: comparação entre lojas.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
