import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/extracao_json.dart';
import 'package:precos_supermercado/core/similaridade.dart';
import 'package:precos_supermercado/core/texto.dart';
import 'package:precos_supermercado/core/vinculo.dart';
import 'package:precos_supermercado/modelos/modelos.dart';

Produto _produto(
  int id,
  String nome, {
  String? marca,
  double? qtd,
  String? unidade,
}) =>
    Produto(
      id: id,
      chave: montarChaveProduto(
        nome: nome,
        marca: marca,
        embalagemQtd: qtd,
        embalagemUnidade: unidade,
      ),
      nome: nome,
      marca: marca,
      embalagemQtd: qtd,
      embalagemUnidade: unidade,
    );

ItemExtraido _item(
  String produto, {
  String textoOriginal = '',
  String? marca,
  double? qtd,
  String? unidade,
}) =>
    ItemExtraido(
      textoOriginal: textoOriginal,
      produto: produto,
      marca: marca,
      embalagemQtd: qtd,
      embalagemUnidade: unidade,
      preco: 10,
    );

void main() {
  group('normalizacao', () {
    test('tira acento, caixa e espaco sobrando', () {
      expect(normalizar('  Açúcar   UNIÃO '), 'acucar uniao');
      expect(normalizar('Café'), 'cafe');
      expect(normalizar(null), '');
    });
  });

  group('similaridadeNomes', () {
    test('nomes iguais dao 1', () {
      expect(similaridadeNomes('Arroz Cristal 5kg', 'Arroz Cristal 5kg'), 1.0);
    });

    test('ignora acento e caixa', () {
      expect(similaridadeNomes('Café Pilão', 'cafe pilao'), 1.0);
    });

    test('so o espaco muda: continua sendo o mesmo nome', () {
      expect(similaridadeNomes('Arroz Cristal 5 kg', 'Arroz Cristal 5kg'), 1.0);
    });

    test('nomes parecidos dao nota alta', () {
      final nota = similaridadeNomes(
        'Arroz Branco Tio Joao Tipo 1 5kg',
        'Arroz Tio Joao 5kg',
      );
      expect(nota, greaterThan(0.5));
    });

    test('nomes diferentes dao nota baixa', () {
      final nota = similaridadeNomes('Arroz Cristal 5kg', 'Sabao em Po Omo 1kg');
      expect(nota, lessThan(0.2));
    });

    test('texto vazio da zero', () {
      expect(similaridadeNomes('', 'Arroz'), 0);
      expect(similaridadeNomes(null, 'Arroz'), 0);
    });

    test('o mais parecido fica sempre acima do menos parecido', () {
      final perto = similaridadeNomes('Leite Integral Italac 1L', 'Leite Integral Italac 1 L');
      final longe = similaridadeNomes('Leite Integral Italac 1L', 'Leite Condensado Moca 395g');
      expect(perto, greaterThan(longe));
    });
  });

  group('ranquearCandidatos', () {
    final produtos = [
      _produto(1, 'Arroz Branco Tio Joao Tipo 1 5kg'),
      _produto(2, 'Feijao Carioca Camil 1kg'),
      _produto(3, 'Arroz Integral Tio Joao 1kg'),
    ];

    test('devolve o mais parecido primeiro', () {
      final r = ranquearCandidatos<Produto>(
        nomeBuscado: 'Arroz Tio Joao 5kg',
        candidatos: produtos,
        nomeDe: (p) => p.nome,
      );
      expect(r.first.item.id, 1);
    });

    test('respeita o limite pedido', () {
      final r = ranquearCandidatos<Produto>(
        nomeBuscado: 'Arroz',
        candidatos: produtos,
        nomeDe: (p) => p.nome,
        limite: 2,
      );
      expect(r, hasLength(2));
    });

    test('vem em ordem decrescente de nota', () {
      final r = ranquearCandidatos<Produto>(
        nomeBuscado: 'Arroz Tio Joao 5kg',
        candidatos: produtos,
        nomeDe: (p) => p.nome,
      );
      for (var i = 1; i < r.length; i++) {
        expect(r[i - 1].nota, greaterThanOrEqualTo(r[i].nota));
      }
    });
  });

  group('procurarProduto', () {
    final produtos = [
      _produto(1, 'Arroz Branco Cristal Tipo 1 5kg',
          marca: 'Cristal', qtd: 5, unidade: 'kg'),
      _produto(2, 'Feijao Carioca Camil 1kg',
          marca: 'Camil', qtd: 1, unidade: 'kg'),
    ];

    test('1. o texto do tabloide da mesma loja manda mais que o nome', () {
      final vinculo = procurarProduto(
        item: _item(
          'Nome Totalmente Diferente',
          textoOriginal: 'ARROZ CRISTAL 5KG',
          qtd: 5,
          unidade: 'kg',
        ),
        produtos: produtos,
        apelidos: const [
          Apelido(produtoId: 1, textoOriginal: 'ARROZ CRISTAL 5KG', lojaId: 7),
        ],
        lojaId: 7,
      );
      expect(vinculo.tipo, TipoVinculo.apelido);
      expect(vinculo.produtoId, 1);
    });

    test('apelido de outra loja tambem serve quando nao ha da mesma', () {
      final vinculo = procurarProduto(
        item: _item('Qualquer', textoOriginal: 'ARROZ CRISTAL 5KG'),
        produtos: produtos,
        apelidos: const [
          Apelido(produtoId: 1, textoOriginal: 'ARROZ CRISTAL 5KG', lojaId: 99),
        ],
        lojaId: 7,
      );
      expect(vinculo.produtoId, 1);
    });

    test('apelido apontando para produto que nao existe mais e ignorado', () {
      final vinculo = procurarProduto(
        item: _item('Coisa Nova', textoOriginal: 'SUMIU'),
        produtos: produtos,
        apelidos: const [
          Apelido(produtoId: 999, textoOriginal: 'SUMIU', lojaId: 7),
        ],
        lojaId: 7,
      );
      expect(vinculo.tipo, TipoVinculo.novo);
    });

    test('2. sem apelido, acha pela chave exata', () {
      final vinculo = procurarProduto(
        item: _item(
          'Arroz Branco Cristal Tipo 1 5kg',
          marca: 'Cristal',
          qtd: 5,
          unidade: 'kg',
        ),
        produtos: produtos,
        apelidos: const [],
      );
      expect(vinculo.tipo, TipoVinculo.chave);
      expect(vinculo.produtoId, 1);
    });

    test('3. nome quase igual e mesma embalagem: vincula sozinho', () {
      final vinculo = procurarProduto(
        item: _item(
          'Arroz Branco Cristal Tipo 1 5 kg',
          marca: 'Cristal',
          qtd: 5,
          unidade: 'kg',
        ),
        produtos: produtos,
        apelidos: const [],
      );
      expect(vinculo.tipo, TipoVinculo.automatico);
      expect(vinculo.produtoId, 1);
    });

    test('3. nome so parecido vira sugestao para o usuario escolher', () {
      final vinculo = procurarProduto(
        item: _item('Arroz Parboilizado', marca: 'Cristal', qtd: 5, unidade: 'kg'),
        produtos: produtos,
        apelidos: const [],
      );
      expect(vinculo.tipo, TipoVinculo.sugestao);
      expect(vinculo.produtoId, isNull);
      expect(vinculo.sugestoes, isNotEmpty);
    });

    test('embalagem diferente nao vira candidato', () {
      final vinculo = procurarProduto(
        item: _item(
          'Arroz Branco Cristal Tipo 1 1kg',
          marca: 'Cristal',
          qtd: 1,
          unidade: 'kg',
        ),
        produtos: produtos,
        apelidos: const [],
      );
      expect(vinculo.tipo, TipoVinculo.novo);
    });

    test('marca diferente nao vira candidato', () {
      final vinculo = procurarProduto(
        item: _item(
          'Arroz Branco Tipo 1 5kg',
          marca: 'Prato Fino',
          qtd: 5,
          unidade: 'kg',
        ),
        produtos: produtos,
        apelidos: const [],
      );
      expect(vinculo.tipo, TipoVinculo.novo);
    });

    test('sem nada parecido, e produto novo', () {
      final vinculo = procurarProduto(
        item: _item('Detergente Neutro', qtd: 500, unidade: 'ml'),
        produtos: produtos,
        apelidos: const [],
      );
      expect(vinculo.tipo, TipoVinculo.novo);
      expect(vinculo.produtoId, isNull);
    });
  });
}
