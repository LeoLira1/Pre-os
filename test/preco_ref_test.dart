import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/preco_ref.dart';

void main() {
  group('calcularPrecoRef', () {
    test('gramas viram preco por quilo', () {
      // 500 g por R$ 15,90 => R$ 31,80/kg
      final r = calcularPrecoRef(
        preco: 15.90,
        embalagemQtd: 500,
        embalagemUnidade: 'g',
      );
      expect(r.valor, closeTo(31.80, 1e-9));
      expect(r.unidade, 'kg');
    });

    test('mililitros viram preco por litro', () {
      // 350 ml por R$ 3,49 => R$ 9,97/L
      final r = calcularPrecoRef(
        preco: 3.49,
        embalagemQtd: 350,
        embalagemUnidade: 'ml',
      );
      expect(r.valor, closeTo(9.97, 1e-9));
      expect(r.unidade, 'L');
    });

    test('quilos dividem direto', () {
      // 5 kg por R$ 24,90 => R$ 4,98/kg
      final r = calcularPrecoRef(
        preco: 24.90,
        embalagemQtd: 5,
        embalagemUnidade: 'kg',
      );
      expect(r.valor, closeTo(4.98, 1e-9));
      expect(r.unidade, 'kg');
    });

    test('litros dividem direto e mantem o L maiusculo', () {
      final r = calcularPrecoRef(
        preco: 7.99,
        embalagemQtd: 2,
        embalagemUnidade: 'L',
      );
      expect(r.valor, closeTo(4.00, 1e-9));
      expect(r.unidade, 'L');
    });

    test('unidades dividem pela quantidade', () {
      // Caixa com 12 por R$ 30,00 => R$ 2,50/un
      final r = calcularPrecoRef(
        preco: 30,
        embalagemQtd: 12,
        embalagemUnidade: 'un',
      );
      expect(r.valor, closeTo(2.50, 1e-9));
      expect(r.unidade, 'un');
    });

    test('rolos dividem pela quantidade', () {
      // 12 rolos por R$ 12,49 => R$ 1,04/rolo
      final r = calcularPrecoRef(
        preco: 12.49,
        embalagemQtd: 12,
        embalagemUnidade: 'rolo',
      );
      expect(r.valor, closeTo(1.04, 1e-9));
      expect(r.unidade, 'rolo');
    });

    test('sem embalagem nao ha preco de referencia', () {
      // Bandeja sem peso informado.
      final r = calcularPrecoRef(
        preco: 7.99,
        embalagemQtd: null,
        embalagemUnidade: null,
      );
      expect(r.existe, isFalse);
      expect(r.valor, isNull);
      expect(r.unidade, isNull);
    });

    test('quantidade zero ou negativa nao gera divisao', () {
      expect(
        calcularPrecoRef(preco: 10, embalagemQtd: 0, embalagemUnidade: 'kg')
            .existe,
        isFalse,
      );
      expect(
        calcularPrecoRef(preco: 10, embalagemQtd: -2, embalagemUnidade: 'kg')
            .existe,
        isFalse,
      );
    });

    test('unidade desconhecida nao gera preco de referencia', () {
      expect(
        calcularPrecoRef(
          preco: 10,
          embalagemQtd: 1,
          embalagemUnidade: 'bandeja',
        ).existe,
        isFalse,
      );
    });

    test('sem preco nao gera preco de referencia', () {
      expect(
        calcularPrecoRef(preco: null, embalagemQtd: 1, embalagemUnidade: 'kg')
            .existe,
        isFalse,
      );
    });

    test('o resultado sai arredondado em 2 casas', () {
      // 3 un por R$ 10,00 daria 3,3333...
      final r = calcularPrecoRef(
        preco: 10,
        embalagemQtd: 3,
        embalagemUnidade: 'un',
      );
      expect(r.valor, 3.33);
    });

    test('a unidade pode vir em maiuscula', () {
      final r = calcularPrecoRef(
        preco: 15.90,
        embalagemQtd: 500,
        embalagemUnidade: 'G',
      );
      expect(r.valor, closeTo(31.80, 1e-9));
      expect(r.unidade, 'kg');
    });
  });
}
