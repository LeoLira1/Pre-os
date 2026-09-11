import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/formato.dart';
import 'package:precos_supermercado/core/texto.dart';
import 'package:precos_supermercado/modelos/modelos.dart';

void main() {
  group('normalizacao de texto', () {
    test('tira acentos, maiusculas e espacos duplicados', () {
      expect(normalizar('  Café   COM   Leite '), 'cafe com leite');
      expect(normalizar(null), '');
    });

    test('a chave do produto junta nome, marca e embalagem', () {
      expect(
        montarChaveProduto(
          nome: 'Açúcar Refinado',
          marca: 'União',
          embalagemQtd: 1,
          embalagemUnidade: 'kg',
        ),
        'acucar refinado uniao 1 kg',
      );
    });

    test('1 e 1.0 geram a mesma chave', () {
      expect(
        montarChaveProduto(nome: 'Leite', embalagemQtd: 1.0),
        montarChaveProduto(nome: 'Leite', embalagemQtd: 1),
      );
    });
  });

  group('formatacao brasileira', () {
    test(r'moeda no padrao R$ 1.234,56', () {
      expect(formatarMoeda(1234.56), 'R\$ 1.234,56');
      expect(formatarMoeda(3.99), 'R\$ 3,99');
      expect(formatarMoeda(null), '--');
    });

    test('preco de referencia mostra a unidade', () {
      expect(formatarPrecoRef(3.99, 'kg'), 'R\$ 3,99/kg');
      expect(formatarPrecoRef(3.99, null), 'R\$ 3,99');
    });

    test('data aparece como dd/MM/yyyy', () {
      expect(formatarData('2026-09-01'), '01/09/2026');
      expect(formatarData(null), '--');
    });

    test('busca ignora acentos e maiusculas', () {
      expect(contemBusca('Café Pilão', normalizar('pilao')), isTrue);
      expect(contemBusca('Café Pilão', normalizar('arroz')), isFalse);
    });
  });

  group('estatisticas do produto', () {
    Preco preco(String data, double valor, {double? ref}) => Preco(
          id: data.hashCode,
          produtoId: 1,
          lojaId: 1,
          data: data,
          preco: valor,
          precoRef: ref,
          unidadeRef: ref == null ? null : 'kg',
          tipo: 'oferta',
        );

    test('sem registros devolve tudo vazio', () {
      final e = EstatisticasProduto.calcular(const []);
      expect(e.registros, 0);
      expect(e.ultimo, isNull);
    });

    test('usa preco_ref quando existe', () {
      final e = EstatisticasProduto.calcular([
        preco('2026-01-10', 24.90, ref: 4.98),
        preco('2026-02-10', 19.90, ref: 3.98),
        preco('2026-03-10', 22.90, ref: 4.58),
      ]);
      expect(e.registros, 3);
      expect(e.ultimo, closeTo(4.58, 1e-9));
      expect(e.menor, closeTo(3.98, 1e-9));
      expect(e.maior, closeTo(4.98, 1e-9));
      expect(e.media, closeTo((4.98 + 3.98 + 4.58) / 3, 1e-9));
      expect(e.unidadeRef, 'kg');
      expect(e.usandoPrecoRef, isTrue);
    });

    test('cai para preco quando preco_ref e nulo', () {
      final e = EstatisticasProduto.calcular([
        preco('2026-01-10', 10.00),
        preco('2026-02-10', 8.00),
      ]);
      expect(e.ultimo, closeTo(8.00, 1e-9));
      expect(e.menor, closeTo(8.00, 1e-9));
      expect(e.usandoPrecoRef, isFalse);
      expect(e.unidadeRef, isNull);
    });

    test('a ordem das datas nao muda o resultado', () {
      final e = EstatisticasProduto.calcular([
        preco('2026-03-10', 22.90, ref: 4.58),
        preco('2026-01-10', 24.90, ref: 4.98),
      ]);
      expect(e.dataUltimo, '2026-03-10');
      expect(e.ultimo, closeTo(4.58, 1e-9));
    });
  });
}
