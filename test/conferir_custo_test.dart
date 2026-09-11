import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/conferir.dart';
import 'package:precos_supermercado/core/custo.dart';

void main() {
  group('motivosParaConferir', () {
    test('item bom nao precisa de conferencia', () {
      final motivos = motivosParaConferir(
        preco: 24.90,
        confianca: 'alta',
        valorComparavel: 4.98,
        mediaHistorica: 5.00,
      );
      expect(motivos, isEmpty);
    });

    test('confianca baixa marca para conferir', () {
      final motivos = motivosParaConferir(preco: 10, confianca: 'baixa');
      expect(motivos, contains(MotivoConferir.confiancaBaixa));
    });

    test('confianca baixa em maiuscula tambem conta', () {
      final motivos = motivosParaConferir(preco: 10, confianca: 'BAIXA');
      expect(motivos, contains(MotivoConferir.confiancaBaixa));
    });

    test('preco zero ou negativo e implausivel', () {
      expect(
        motivosParaConferir(preco: 0, confianca: 'alta'),
        contains(MotivoConferir.precoImplausivel),
      );
      expect(
        motivosParaConferir(preco: -5, confianca: 'alta'),
        contains(MotivoConferir.precoImplausivel),
      );
    });

    test('preco acima de mil e implausivel', () {
      expect(
        motivosParaConferir(preco: 1000.01, confianca: 'alta'),
        contains(MotivoConferir.precoImplausivel),
      );
      // Exatamente mil ainda passa.
      expect(
        motivosParaConferir(preco: 1000, confianca: 'alta'),
        isNot(contains(MotivoConferir.precoImplausivel)),
      );
    });

    test('preco nulo e implausivel', () {
      expect(
        motivosParaConferir(preco: null, confianca: 'alta'),
        contains(MotivoConferir.precoImplausivel),
      );
    });

    test('abaixo de metade da media marca fora da faixa', () {
      // Media 10, item 4 (menos que 5).
      final motivos = motivosParaConferir(
        preco: 4,
        confianca: 'alta',
        valorComparavel: 4,
        mediaHistorica: 10,
      );
      expect(motivos, contains(MotivoConferir.foraDaFaixa));
    });

    test('acima do dobro da media marca fora da faixa', () {
      final motivos = motivosParaConferir(
        preco: 21,
        confianca: 'alta',
        valorComparavel: 21,
        mediaHistorica: 10,
      );
      expect(motivos, contains(MotivoConferir.foraDaFaixa));
    });

    test('nas bordas da faixa ainda passa', () {
      // Exatamente metade e exatamente o dobro continuam validos.
      expect(
        motivosParaConferir(
          preco: 5,
          confianca: 'alta',
          valorComparavel: 5,
          mediaHistorica: 10,
        ),
        isEmpty,
      );
      expect(
        motivosParaConferir(
          preco: 20,
          confianca: 'alta',
          valorComparavel: 20,
          mediaHistorica: 10,
        ),
        isEmpty,
      );
    });

    test('produto sem historico nao marca fora da faixa', () {
      final motivos = motivosParaConferir(
        preco: 999,
        confianca: 'alta',
        valorComparavel: 999,
        mediaHistorica: null,
      );
      expect(motivos, isEmpty);
    });

    test('um item pode juntar varios motivos', () {
      final motivos = motivosParaConferir(
        preco: 1500,
        confianca: 'baixa',
        valorComparavel: 1500,
        mediaHistorica: 10,
      );
      expect(motivos, hasLength(3));
    });

    test('usa o preco quando nao ha preco de referencia', () {
      final motivos = motivosParaConferir(
        preco: 100,
        confianca: 'alta',
        valorComparavel: null,
        mediaHistorica: 10,
      );
      expect(motivos, contains(MotivoConferir.foraDaFaixa));
    });
  });

  group('horario de pico', () {
    test('terca as 02:00 UTC e pico', () {
      expect(estaNoHorarioDePico(DateTime.utc(2026, 9, 8, 2)), isTrue);
    });

    test('terca as 07:00 UTC e pico', () {
      expect(estaNoHorarioDePico(DateTime.utc(2026, 9, 8, 7)), isTrue);
    });

    test('terca as 05:00 UTC nao e pico (fica entre as duas faixas)', () {
      expect(estaNoHorarioDePico(DateTime.utc(2026, 9, 8, 5)), isFalse);
    });

    test('terca as 10:00 UTC ja saiu do pico', () {
      expect(estaNoHorarioDePico(DateTime.utc(2026, 9, 8, 10)), isFalse);
    });

    test('terca as 00:30 UTC ainda nao entrou no pico', () {
      expect(estaNoHorarioDePico(DateTime.utc(2026, 9, 8, 0, 30)), isFalse);
    });

    test('sabado e domingo nunca sao pico', () {
      expect(estaNoHorarioDePico(DateTime.utc(2026, 9, 12, 2)), isFalse);
      expect(estaNoHorarioDePico(DateTime.utc(2026, 9, 13, 7)), isFalse);
    });
  });

  group('estimarCustoUsd', () {
    const uso = UsoTokens(
      entradaSemCache: 1000000,
      entradaComCache: 1000000,
      saida: 1000000,
    );
    const precos = TabelaPrecos();

    test('fora do pico usa a tabela cheia', () {
      // 0.15 + 0.003 + 0.60 = 0.753
      final custo = estimarCustoUsd(
        uso: uso,
        precos: precos,
        momento: DateTime.utc(2026, 9, 12, 2), // sabado
      );
      expect(custo, closeTo(0.753, 1e-9));
    });

    test('no pico dobra', () {
      final custo = estimarCustoUsd(
        uso: uso,
        precos: precos,
        momento: DateTime.utc(2026, 9, 8, 2), // terca, pico
      );
      expect(custo, closeTo(1.506, 1e-9));
    });

    test('com o interruptor desligado nao dobra nem no pico', () {
      final custo = estimarCustoUsd(
        uso: uso,
        precos: precos.copiarCom(picoDobra: false),
        momento: DateTime.utc(2026, 9, 8, 2),
      );
      expect(custo, closeTo(0.753, 1e-9));
    });

    test('o cache sai muito mais barato que a entrada normal', () {
      final semCache = estimarCustoUsd(
        uso: const UsoTokens(entradaSemCache: 1000000),
        precos: precos,
        momento: DateTime.utc(2026, 9, 12, 2),
      );
      final comCache = estimarCustoUsd(
        uso: const UsoTokens(entradaComCache: 1000000),
        precos: precos,
        momento: DateTime.utc(2026, 9, 12, 2),
      );
      expect(comCache, lessThan(semCache));
      expect(semCache / comCache, closeTo(50, 0.001));
    });

    test('sem tokens, custo zero', () {
      expect(
        estimarCustoUsd(
          uso: const UsoTokens(),
          precos: precos,
          momento: DateTime.utc(2026, 9, 8, 2),
        ),
        0,
      );
    });

    test('somar o uso de varias fotos junta os tokens', () {
      const a = UsoTokens(entradaSemCache: 10, entradaComCache: 5, saida: 2);
      const b = UsoTokens(entradaSemCache: 20, entradaComCache: 1, saida: 3);
      final total = a.mais(b);
      expect(total.entradaSemCache, 30);
      expect(total.entradaComCache, 6);
      expect(total.saida, 5);
      expect(total.entradaTotal, 36);
    });
  });

  group('formatarUsd', () {
    test('valores muito pequenos aparecem com 4 casas', () {
      expect(formatarUsd(0.0023), 'US\$ 0,0023');
    });

    test('valores normais aparecem com 2 casas', () {
      expect(formatarUsd(1.5), 'US\$ 1,50');
    });

    test('zero aparece limpo', () {
      expect(formatarUsd(0), 'US\$ 0,00');
    });
  });
}
