import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/comparacao_lojas.dart';
import 'package:precos_supermercado/core/formato.dart';
import 'package:precos_supermercado/modelos/modelos.dart';

Preco _preco(
  int lojaId,
  String data,
  double valor, {
  double? ref,
  String? unidadeRef = 'kg',
}) =>
    Preco(
      id: data.hashCode ^ lojaId,
      produtoId: 1,
      lojaId: lojaId,
      data: data,
      preco: valor,
      precoRef: ref,
      unidadeRef: ref == null ? null : unidadeRef,
      tipo: 'oferta',
    );

const Map<int, String> _lojas = {
  1: 'Supermercado Varejao',
  2: 'Supermercados Agrovale',
  3: 'Assai',
};

String _nomeDaLoja(int id) => _lojas[id] ?? 'Loja $id';

void main() {
  group('nomeCurtoLoja', () {
    test('tira "Supermercado" do comeco', () {
      expect(nomeCurtoLoja('Supermercado Varejao'), 'Varejao');
    });

    test('tira "Supermercados" do comeco', () {
      expect(nomeCurtoLoja('Supermercados Agrovale'), 'Agrovale');
    });

    test('nao liga para maiuscula ou minuscula', () {
      expect(nomeCurtoLoja('SUPERMERCADO Varejao'), 'Varejao');
      expect(nomeCurtoLoja('supermercado varejao'), 'varejao');
    });

    test('nome sem o prefixo fica igual', () {
      expect(nomeCurtoLoja('Assai'), 'Assai');
      expect(nomeCurtoLoja('Atacadao'), 'Atacadao');
    });

    test('so tira do comeco, nao do meio', () {
      expect(nomeCurtoLoja('Rede Supermercado Bom'), 'Rede Supermercado Bom');
    });

    test('loja chamada so "Supermercado" mantem o nome', () {
      expect(nomeCurtoLoja('Supermercado'), 'Supermercado');
    });

    test('vazio e nulo nao quebram', () {
      expect(nomeCurtoLoja(''), '');
      expect(nomeCurtoLoja(null), '');
    });
  });

  group('compararLojas', () {
    test('ordena da mais barata para a mais cara pelo preco de referencia', () {
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-09-10', 24.90, ref: 4.98),
          _preco(2, '2026-09-10', 19.90, ref: 3.98),
          _preco(3, '2026-09-10', 29.90, ref: 5.98),
        ],
        nomeDaLoja: _nomeDaLoja,
      );

      expect(lojas.map((l) => l.nomeLoja), ['Agrovale', 'Varejao', 'Assai']);
      expect(lojas.first.valorComparavel, 3.98);
    });

    test('usa o nome curto da loja', () {
      final lojas = compararLojas(
        precos: [_preco(1, '2026-09-10', 10, ref: 10)],
        nomeDaLoja: _nomeDaLoja,
      );
      expect(lojas.single.nomeLoja, 'Varejao');
    });

    test('de cada loja pega so o registro mais recente', () {
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-08-01', 30.00, ref: 6.00),
          _preco(1, '2026-09-10', 24.90, ref: 4.98),
        ],
        nomeDaLoja: _nomeDaLoja,
      );

      expect(lojas, hasLength(1));
      expect(lojas.single.preco, 24.90);
      expect(lojas.single.data, '2026-09-10');
    });

    test('a ordem de entrada nao muda o resultado', () {
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-09-10', 24.90, ref: 4.98),
          _preco(1, '2026-08-01', 30.00, ref: 6.00),
        ],
        nomeDaLoja: _nomeDaLoja,
      );
      expect(lojas.single.preco, 24.90);
    });

    test('sem preco de referencia, compara pelo preco cheio', () {
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-09-10', 12.00),
          _preco(2, '2026-09-10', 8.00),
        ],
        nomeDaLoja: _nomeDaLoja,
      );

      expect(lojas.first.nomeLoja, 'Agrovale');
      expect(lojas.first.valorComparavel, 8.00);
    });

    test('preco de referencia manda mesmo quando o preco cheio engana', () {
      // Pacote de 5 kg a R$ 24,90 (4,98/kg) e mais barato por quilo que
      // o de 1 kg a R$ 5,90, mesmo custando mais na etiqueta.
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-09-10', 24.90, ref: 4.98),
          _preco(2, '2026-09-10', 5.90, ref: 5.90),
        ],
        nomeDaLoja: _nomeDaLoja,
      );
      expect(lojas.first.nomeLoja, 'Varejao');
    });

    test('empate no preco: a loja com registro mais novo vem primeiro', () {
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-08-01', 10.00, ref: 5.00),
          _preco(2, '2026-09-10', 10.00, ref: 5.00),
        ],
        nomeDaLoja: _nomeDaLoja,
      );
      expect(lojas.first.nomeLoja, 'Agrovale');
    });

    test('sem precos, lista vazia', () {
      expect(
        compararLojas(precos: const [], nomeDaLoja: _nomeDaLoja),
        isEmpty,
      );
    });
  });

  group('datas desatualizadas', () {
    test('a loja com registro mais antigo e marcada', () {
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-08-01', 19.90, ref: 3.98),
          _preco(2, '2026-09-10', 24.90, ref: 4.98),
        ],
        nomeDaLoja: _nomeDaLoja,
      );

      final varejao = lojas.firstWhere((l) => l.nomeLoja == 'Varejao');
      final agrovale = lojas.firstWhere((l) => l.nomeLoja == 'Agrovale');

      // Varejao esta mais barato, mas com oferta de agosto.
      expect(estaDesatualizada(varejao, lojas), isTrue);
      expect(estaDesatualizada(agrovale, lojas), isFalse);
    });

    test('mesma data em todas: nenhuma e marcada', () {
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-09-10', 19.90, ref: 3.98),
          _preco(2, '2026-09-10', 24.90, ref: 4.98),
        ],
        nomeDaLoja: _nomeDaLoja,
      );
      for (final loja in lojas) {
        expect(estaDesatualizada(loja, lojas), isFalse);
      }
    });

    test('dataMaisRecente devolve a maior data', () {
      final lojas = compararLojas(
        precos: [
          _preco(1, '2026-08-01', 10, ref: 5),
          _preco(2, '2026-09-10', 10, ref: 6),
        ],
        nomeDaLoja: _nomeDaLoja,
      );
      expect(dataMaisRecente(lojas), '2026-09-10');
      expect(dataMaisRecente(const []), isNull);
    });
  });
}
