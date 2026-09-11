import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../modelos/modelos.dart';

/// Grafico de linha do preco de referencia ao longo do tempo.
///
/// Com menos de dois registros nao ha linha para desenhar, entao mostra
/// um aviso no lugar.
class GraficoPrecos extends StatelessWidget {
  const GraficoPrecos({super.key, required this.precos, this.unidadeRef});

  /// Precos ordenados da data mais antiga para a mais nova.
  final List<Preco> precos;
  final String? unidadeRef;

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

    final cores = Theme.of(context).colorScheme;
    final pontos = <FlSpot>[];
    for (var i = 0; i < precos.length; i++) {
      pontos.add(FlSpot(i.toDouble(), precos[i].valorComparavel));
    }

    final valores = pontos.map((p) => p.y).toList();
    final minimo = valores.reduce((a, b) => a < b ? a : b);
    final maximo = valores.reduce((a, b) => a > b ? a : b);
    // Uma folga em cima e embaixo para a linha nao encostar na borda.
    final folga = (maximo - minimo) == 0 ? (maximo == 0 ? 1 : maximo * 0.1)
        : (maximo - minimo) * 0.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
        child: SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minY: minimo - folga,
              maxY: maximo + folga,
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
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    interval: _intervaloDatas,
                    getTitlesWidget: (valor, meta) {
                      final indice = valor.round();
                      if (indice < 0 || indice >= precos.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _dataCurta(precos[indice].data),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => cores.inverseSurface,
                  getTooltipItems: (pontosTocados) => pontosTocados.map((ponto) {
                    final registro = precos[ponto.spotIndex];
                    return LineTooltipItem(
                      '${formatarData(registro.data)}\n'
                      '${formatarPrecoRef(registro.valorComparavel, unidadeRef)}',
                      TextStyle(color: cores.onInverseSurface, fontSize: 12),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: pontos,
                  isCurved: false,
                  color: cores.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: precos.length <= 30,
                    getDotPainter: (spot, percent, barra, indice) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: cores.primary,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: cores.primary.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Evita empilhar datas demais no eixo de baixo.
  double get _intervaloDatas {
    final passo = (precos.length / 4).ceil();
    return passo < 1 ? 1 : passo.toDouble();
  }

  static String _dataCurta(String iso) {
    final data = DateTime.tryParse(iso);
    if (data == null) return iso;
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }
}
