import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/modelos/modelos.dart';
import 'package:precos_supermercado/ui/widgets/grafico_precos.dart';

Preco _preco(int lojaId, String data, double valor, {double? ref}) => Preco(
      id: data.hashCode ^ lojaId,
      produtoId: 1,
      lojaId: lojaId,
      data: data,
      preco: valor,
      precoRef: ref,
      unidadeRef: ref == null ? null : 'kg',
      tipo: 'oferta',
    );

void main() {
  group('deveUsarBarras', () {
    test('tudo na mesma data: usa barras', () {
      expect(
        deveUsarBarras([
          _preco(1, '2026-09-10', 24.90, ref: 4.98),
          _preco(2, '2026-09-10', 19.90, ref: 3.98),
          _preco(3, '2026-09-10', 29.90, ref: 5.98),
        ]),
        isTrue,
      );
    });

    test('um registro por loja em datas diferentes: usa barras', () {
      // Nao ha o que ligar numa linha: cada loja tem so um ponto.
      expect(
        deveUsarBarras([
          _preco(1, '2026-09-01', 24.90, ref: 4.98),
          _preco(2, '2026-09-10', 19.90, ref: 3.98),
        ]),
        isTrue,
      );
    });

    test('uma loja com varias datas: usa linha', () {
      expect(
        deveUsarBarras([
          _preco(1, '2026-08-01', 24.90, ref: 4.98),
          _preco(1, '2026-09-10', 19.90, ref: 3.98),
        ]),
        isFalse,
      );
    });

    test('duas lojas, uma com historico: usa linha', () {
      expect(
        deveUsarBarras([
          _preco(1, '2026-08-01', 24.90, ref: 4.98),
          _preco(1, '2026-09-10', 22.90, ref: 4.58),
          _preco(2, '2026-09-10', 19.90, ref: 3.98),
        ]),
        isFalse,
      );
    });

    test('lista vazia nao usa barras', () {
      expect(deveUsarBarras(const []), isFalse);
    });
  });

  group('estatisticas sabem de qual loja veio o menor e o maior', () {
    test('menor e maior apontam para as lojas certas', () {
      final e = EstatisticasProduto.calcular([
        _preco(1, '2026-08-01', 24.90, ref: 4.98),
        _preco(2, '2026-08-15', 19.90, ref: 3.98),
        _preco(3, '2026-09-01', 29.90, ref: 5.98),
      ]);

      expect(e.menor, closeTo(3.98, 1e-9));
      expect(e.lojaIdMenor, 2);
      expect(e.maior, closeTo(5.98, 1e-9));
      expect(e.lojaIdMaior, 3);
    });

    test('com um registro so, menor e maior sao a mesma loja', () {
      final e = EstatisticasProduto.calcular([
        _preco(7, '2026-09-01', 10.00, ref: 10.00),
      ]);
      expect(e.lojaIdMenor, 7);
      expect(e.lojaIdMaior, 7);
    });

    test('sem registros nao ha loja', () {
      final e = EstatisticasProduto.calcular(const []);
      expect(e.lojaIdMenor, isNull);
      expect(e.lojaIdMaior, isNull);
    });

    test('sem preco de referencia usa o preco cheio para achar as lojas', () {
      final e = EstatisticasProduto.calcular([
        _preco(1, '2026-08-01', 12.00),
        _preco(2, '2026-08-15', 8.00),
      ]);
      expect(e.lojaIdMenor, 2);
      expect(e.lojaIdMaior, 1);
    });
  });
}
