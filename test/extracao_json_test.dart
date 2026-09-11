import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/extracao_json.dart';

const String _jsonBom = '''
{
  "data_oferta": "2026-09-11",
  "loja": "Assai",
  "itens": [
    {
      "texto_original": "ARROZ CRISTAL 5KG",
      "produto": "Arroz Branco Cristal Tipo 1 5kg",
      "marca": "Cristal",
      "categoria": "Mercearia",
      "embalagem_qtd": 5,
      "embalagem_unidade": "kg",
      "unidade_venda": "un",
      "preco": 24.98,
      "ean": "7896006711001",
      "limite_por_cliente": 3,
      "observacao": "Limite 3 unid. por cliente",
      "confianca": "alta"
    }
  ]
}
''';

void main() {
  group('lerRespostaModelo - JSON puro', () {
    test('le o cabecalho e o item completo', () {
      final r = lerRespostaModelo(_jsonBom);

      expect(r.dataOferta, '2026-09-11');
      expect(r.loja, 'Assai');
      expect(r.itens, hasLength(1));

      final item = r.itens.single;
      expect(item.textoOriginal, 'ARROZ CRISTAL 5KG');
      expect(item.produto, 'Arroz Branco Cristal Tipo 1 5kg');
      expect(item.marca, 'Cristal');
      expect(item.categoria, 'Mercearia');
      expect(item.embalagemQtd, 5);
      expect(item.embalagemUnidade, 'kg');
      expect(item.unidadeVenda, 'un');
      expect(item.preco, 24.98);
      expect(item.ean, '7896006711001');
      expect(item.limitePorCliente, 3);
      expect(item.confianca, 'alta');
    });
  });

  group('lerRespostaModelo - JSON embrulhado', () {
    test('aceita dentro de cerca ```json', () {
      final r = lerRespostaModelo('```json\n$_jsonBom\n```');
      expect(r.itens, hasLength(1));
      expect(r.itens.single.preco, 24.98);
    });

    test('aceita cerca sem a palavra json', () {
      final r = lerRespostaModelo('```\n$_jsonBom\n```');
      expect(r.itens, hasLength(1));
    });

    test('aceita frase antes e depois do JSON', () {
      final r = lerRespostaModelo(
        'Claro! Aqui esta o resultado:\n$_jsonBom\nEspero ter ajudado.',
      );
      expect(r.loja, 'Assai');
      expect(r.itens, hasLength(1));
    });

    test('aceita cerca aberta que nao foi fechada', () {
      final r = lerRespostaModelo('```json\n$_jsonBom');
      expect(r.itens, hasLength(1));
    });

    test('aceita quando vem so a lista de itens', () {
      final r = lerRespostaModelo(
        '[{"texto_original":"UVA ROXA","produto":"Uva Roxa","preco":7.99}]',
      );
      expect(r.itens, hasLength(1));
      expect(r.itens.single.produto, 'Uva Roxa');
    });
  });

  group('lerRespostaModelo - valores tortos', () {
    test('preco em texto com virgula e cifrao vira numero', () {
      final r = lerRespostaModelo(
        '{"itens":[{"produto":"Cafe","preco":"R\$ 15,90"}]}',
      );
      expect(r.itens.single.preco, closeTo(15.90, 1e-9));
    });

    test('a palavra "null" em texto vira nulo de verdade', () {
      final r = lerRespostaModelo(
        '{"itens":[{"produto":"Banana","preco":5.99,"marca":"null",'
        '"ean":"null"}]}',
      );
      expect(r.itens.single.marca, isNull);
      expect(r.itens.single.ean, isNull);
    });

    test('categoria fora da lista permitida e descartada', () {
      final r = lerRespostaModelo(
        '{"itens":[{"produto":"X","preco":1.0,"categoria":"Eletronicos"}]}',
      );
      expect(r.itens.single.categoria, isNull);
    });

    test('categoria com acento diferente e reconhecida', () {
      final r = lerRespostaModelo(
        '{"itens":[{"produto":"X","preco":1.0,"categoria":"cafe"}]}',
      );
      expect(r.itens.single.categoria, 'Café');
    });

    test('unidade fora da lista e descartada', () {
      final r = lerRespostaModelo(
        '{"itens":[{"produto":"X","preco":1.0,"embalagem_unidade":"litros"}]}',
      );
      expect(r.itens.single.embalagemUnidade, isNull);
    });

    test('confianca invalida vira media', () {
      final r = lerRespostaModelo(
        '{"itens":[{"produto":"X","preco":1.0,"confianca":"talvez"}]}',
      );
      expect(r.itens.single.confianca, 'media');
    });

    test('data no formato brasileiro vira ISO', () {
      final r = lerRespostaModelo(
        '{"data_oferta":"11/09/2026","itens":[]}',
      );
      expect(r.dataOferta, '2026-09-11');
    });

    test('data invalida vira nulo', () {
      final r = lerRespostaModelo('{"data_oferta":"sexta-feira","itens":[]}');
      expect(r.dataOferta, isNull);
    });

    test('itens sem nome e sem preco sao descartados', () {
      final r = lerRespostaModelo(
        '{"itens":[{"produto":"","preco":null},{"produto":"Ovo","preco":9.9}]}',
      );
      expect(r.itens, hasLength(1));
      expect(r.itens.single.produto, 'Ovo');
    });
  });

  group('lerRespostaModelo - respostas que nao dao', () {
    test('resposta vazia reclama', () {
      expect(
        () => lerRespostaModelo(''),
        throwsA(isA<RespostaInvalidaException>()),
      );
      expect(
        () => lerRespostaModelo(null),
        throwsA(isA<RespostaInvalidaException>()),
      );
    });

    test('texto sem JSON nenhum reclama', () {
      expect(
        () => lerRespostaModelo('Desculpe, nao consegui ler a imagem.'),
        throwsA(isA<RespostaInvalidaException>()),
      );
    });
  });
}
