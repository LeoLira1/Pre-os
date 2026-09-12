import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/comparacao_lojas.dart';
import 'package:precos_supermercado/core/preco_ref.dart';
import 'package:precos_supermercado/core/rota_compras.dart';
import 'package:precos_supermercado/modelos/modelos.dart';

/// As quatro marcas de agua sanitaria, uma por loja.
const _produtos = <int, Produto>{
  1: Produto(
    id: 1,
    chave: 'agua sanitaria qboa 2 l',
    nome: 'Água Sanitária Qboa 2L',
    marca: 'Qboa',
    embalagemQtd: 2,
    embalagemUnidade: 'L',
  ),
  2: Produto(
    id: 2,
    chave: 'agua sanitaria sol 2 l',
    nome: 'Água Sanitária Sol 2L',
    marca: 'Sol',
    embalagemQtd: 2,
    embalagemUnidade: 'L',
  ),
  3: Produto(
    id: 3,
    chave: 'agua sanitaria ype 2 l',
    nome: 'Água Sanitária Ypê 2L',
    marca: 'Ypê',
    embalagemQtd: 2,
    embalagemUnidade: 'L',
  ),
  4: Produto(
    id: 4,
    chave: 'agua sanitaria zupp 1 l',
    nome: 'Água Sanitária Zupp 1L',
    marca: 'Zupp',
    embalagemQtd: 1,
    embalagemUnidade: 'L',
  ),
};

const _lojas = <int, String>{
  1: 'Supermercado Varejao',
  2: 'Assai',
  3: 'Atacadao',
  4: 'Supermercados Agrovale',
};

/// Monta o registro com o preco de referencia calculado pelo proprio app.
Preco _preco(int produtoId, int lojaId, double valor) {
  final produto = _produtos[produtoId]!;
  final ref = calcularPrecoRef(
    preco: valor,
    embalagemQtd: produto.embalagemQtd,
    embalagemUnidade: produto.embalagemUnidade,
  );
  return Preco(
    id: produtoId * 100 + lojaId,
    produtoId: produtoId,
    lojaId: lojaId,
    data: '2026-09-10',
    preco: valor,
    precoRef: ref.valor,
    unidadeRef: ref.unidade,
    embalagemQtd: produto.embalagemQtd,
    embalagemUnidade: produto.embalagemUnidade,
    tipo: 'oferta',
  );
}

// Qboa 2L R$ 6,90 -> 3,45/L; Sol 2L R$ 4,99 -> 2,50/L;
// Ypê 2L R$ 6,00 -> 3,00/L; Zupp 1L R$ 2,49 -> 2,49/L.
final _precos = <Preco>[
  _preco(1, 1, 6.90),
  _preco(2, 2, 4.99),
  _preco(3, 3, 6.00),
  _preco(4, 4, 2.49),
];

List<PrecoNaLoja> _comparar() => compararLojas(
      precos: _precos,
      nomeDaLoja: (id) => _lojas[id] ?? 'Loja $id',
      produtoPorId: (id) => _produtos[id],
    );

void main() {
  group('preço de referência das quatro marcas', () {
    test('cada embalagem vira preço por litro', () {
      expect(_preco(4, 4, 2.49).precoRef, 2.49);
      expect(_preco(2, 2, 4.99).precoRef, 2.50);
      expect(_preco(3, 3, 6.00).precoRef, 3.00);
      expect(_preco(1, 1, 6.90).precoRef, 3.45);
      for (final preco in _precos) {
        expect(preco.unidadeRef, 'L');
      }
    });
  });

  group('comparação entre marcas', () {
    test('ordena pelo preço por litro, não pelo preço da embalagem', () {
      final lojas = _comparar();
      expect(
        lojas.map((l) => l.marca).toList(),
        ['Zupp', 'Sol', 'Ypê', 'Qboa'],
      );
      expect(
        lojas.map((l) => l.precoRef).toList(),
        [2.49, 2.50, 3.00, 3.45],
      );
      // O menor preco de embalagem (Zupp, R$ 2,49) por acaso coincide aqui,
      // mas quem manda na ordem e o preco por litro.
      expect(lojas.first.preco, 2.49);
      expect(lojas.first.nomeLoja, 'Agrovale');
      expect(lojas.first.marcaEEmbalagem, 'Zupp 1 L');
    });

    test('Zupp 1L e Sol 2L ficam empatados; Ypê e Qboa vêm depois', () {
      final lojas = _comparar();
      final empatados = indicesEmpatados(lojas);

      expect(empatados, {0, 1});
      expect(
        empatados.map((i) => lojas[i].marca).toSet(),
        {'Zupp', 'Sol'},
      );
      expect(empatados, isNot(contains(2)));
      expect(empatados, isNot(contains(3)));
    });

    test('uma diferença de 2% ou mais já não é empate', () {
      final lojas = _comparar();
      // Ype esta 20% acima do Zupp: fora do empate.
      final diferenca = (lojas[2].precoRef! - lojas[0].precoRef!) /
          lojas[0].precoRef!;
      expect(diferenca, greaterThan(toleranciaDeEmpate));
    });

    test('sem ninguém perto do primeiro, não há empate', () {
      final lojas = _comparar().where((l) => l.marca != 'Sol').toList();
      expect(indicesEmpatados(lojas), isEmpty);
    });

    test('uma loja só nunca empata', () {
      expect(indicesEmpatados(_comparar().take(1).toList()), isEmpty);
    });
  });

  group('rota de compras', () {
    const grupoGenerico = Grupo(
      id: 10,
      nome: 'Água Sanitária',
      unidadeRef: 'L',
      ignoraMarca: true,
      nomeGenerico: 'Água Sanitária',
    );

    ItemDaRota item() => montarItemDaRota(
          grupo: grupoGenerico,
          precos: _precos,
          nomeDaLoja: (id) => _lojas[id] ?? 'Loja $id',
          produtoPorId: (id) => _produtos[id],
        );

    test('indica a loja e a marca mais baratas por litro', () {
      final rota = item();
      expect(rota.generico, isTrue);
      expect(rota.melhor!.nomeLoja, 'Agrovale');
      expect(rota.melhor!.marca, 'Zupp');
      expect(rota.melhor!.precoRef, 2.49);
      expect(rota.melhor!.unidadeRef, 'L');
    });

    test('mostra quem ficou empatado com a mais barata', () {
      final empatadas = item().empatadasComOMelhor;
      expect(empatadas.map((e) => e.marca).toList(), ['Sol']);
    });

    test('agrupa os itens por loja', () {
      final paradas = montarRota([item()]);
      expect(paradas, hasLength(1));
      expect(paradas.single.nomeLoja, 'Agrovale');
      expect(paradas.single.total, 2.49);
    });

    test('grupo sem preço nenhum fica de fora da rota', () {
      final vazio = montarItemDaRota(
        grupo: const Grupo(id: 11, nome: 'Sabão em Pó', unidadeRef: 'kg'),
        precos: const <Preco>[],
        nomeDaLoja: (id) => _lojas[id] ?? 'Loja $id',
      );
      expect(vazio.melhor, isNull);
      expect(montarRota([vazio]), isEmpty);
    });

    test('total numa loja só é nulo quando ela não tem o item', () {
      expect(totalNumaLojaSo([item()], 4), 2.49);
      expect(totalNumaLojaSo([item(), item()], 4), closeTo(4.98, 0.001));
      final semTudo = montarItemDaRota(
        grupo: const Grupo(id: 11, nome: 'Sabão em Pó', unidadeRef: 'kg'),
        precos: const <Preco>[],
        nomeDaLoja: (id) => _lojas[id] ?? 'Loja $id',
      );
      expect(totalNumaLojaSo([item(), semTudo], 4), isNull);
    });
  });
}
