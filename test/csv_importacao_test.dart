import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/csv_importacao.dart';

const String _cabecalho =
    'data_oferta,loja,categoria,produto,marca,embalagem_qtd,embalagem_unidade,'
    'unidade_venda,preco,preco_ref,unidade_ref,ean,observacao';

String _arquivo(List<String> linhas) => '$_cabecalho\n${linhas.join('\n')}\n';

void main() {
  group('lerCsv - linha normal', () {
    test('le todos os campos de uma linha completa', () {
      final resultado = lerCsv(
        _arquivo([
          '2026-09-01,Assai,Mercearia,Arroz branco tipo 1,Tio Joao,5,kg,pacote,'
              '24.90,4.98,kg,7896006711001,Oferta do encarte',
        ]),
      );

      expect(resultado.erros, isEmpty);
      expect(resultado.totalLinhas, 1);
      expect(resultado.linhas, hasLength(1));

      final linha = resultado.linhas.single;
      expect(linha.numeroLinha, 2);
      expect(linha.dataOferta, '2026-09-01');
      expect(linha.loja, 'Assai');
      expect(linha.categoria, 'Mercearia');
      expect(linha.produto, 'Arroz branco tipo 1');
      expect(linha.marca, 'Tio Joao');
      expect(linha.embalagemQtd, 5);
      expect(linha.embalagemUnidade, 'kg');
      expect(linha.unidadeVenda, 'pacote');
      expect(linha.preco, 24.90);
      expect(linha.precoRef, 4.98);
      expect(linha.unidadeRef, 'kg');
      expect(linha.ean, '7896006711001');
      expect(linha.observacao, 'Oferta do encarte');
      expect(linha.limitePorCliente, isNull);
    });

    test('a chave do produto ignora acentos, maiusculas e espacos duplicados',
        () {
      final resultado = lerCsv(
        _arquivo([
          '2026-09-01,Assai,Bebidas,  Agua   MINERAL  ,Crystal,1.5,L,garrafa,'
              '2.49,1.66,L,,',
        ]),
      );

      expect(resultado.erros, isEmpty);
      expect(resultado.linhas.single.chaveProduto, 'agua mineral crystal 1.5 l');
    });
  });

  group('lerCsv - campo entre aspas com virgulas dentro', () {
    test('mantem a virgula dentro do campo e nao desloca as colunas', () {
      final resultado = lerCsv(
        _arquivo([
          '2026-09-02,"Supermercado Silva, Filhos e Cia",Limpeza,'
              'Detergente neutro,Ype,500,ml,frasco,2.19,4.38,L,,'
              '"Leve 3, pague 2"',
        ]),
      );

      expect(resultado.erros, isEmpty);
      final linha = resultado.linhas.single;
      expect(linha.loja, 'Supermercado Silva, Filhos e Cia');
      expect(linha.observacao, 'Leve 3, pague 2');
      expect(linha.preco, 2.19);
      expect(linha.unidadeRef, 'L');
    });

    test('aspas duplicadas dentro do campo viram uma aspa so', () {
      final resultado = lerCsv(
        _arquivo([
          '2026-09-02,Assai,Bebidas,"Refrigerante ""Cola"" zero",Pepsi,2,L,'
              'garrafa,7.99,4.00,L,,',
        ]),
      );

      expect(resultado.erros, isEmpty);
      expect(resultado.linhas.single.produto, 'Refrigerante "Cola" zero');
    });
  });

  group('lerCsv - campos vazios', () {
    test('campos vazios viram null e a linha continua valida', () {
      final resultado = lerCsv(
        _arquivo(['2026-09-03,Atacadao,,Banana prata,,,,,5.99,,,,']),
      );

      expect(resultado.erros, isEmpty);
      final linha = resultado.linhas.single;
      expect(linha.categoria, isNull);
      expect(linha.marca, isNull);
      expect(linha.embalagemQtd, isNull);
      expect(linha.embalagemUnidade, isNull);
      expect(linha.unidadeVenda, isNull);
      expect(linha.precoRef, isNull);
      expect(linha.unidadeRef, isNull);
      expect(linha.ean, isNull);
      expect(linha.observacao, isNull);
      expect(linha.limitePorCliente, isNull);
      expect(linha.preco, 5.99);
    });

    test('preco vazio vira erro com o motivo explicado', () {
      final resultado = lerCsv(
        _arquivo(['2026-09-03,Atacadao,,Banana prata,,,,,,,,,']),
      );

      expect(resultado.linhas, isEmpty);
      expect(resultado.erros, hasLength(1));
      expect(resultado.erros.single.numeroLinha, 2);
      expect(resultado.erros.single.motivo, contains('preco'));
    });

    test('data fora do formato AAAA-MM-DD vira erro', () {
      final resultado = lerCsv(
        _arquivo(['01/09/2026,Assai,,Cafe,Pilao,500,g,pacote,15.90,31.80,kg,,']),
      );

      expect(resultado.linhas, isEmpty);
      expect(resultado.erros.single.motivo, contains('AAAA-MM-DD'));
    });

    test('linha em branco no meio do arquivo e ignorada sem virar erro', () {
      final resultado = lerCsv(
        '$_cabecalho\n'
        '2026-09-03,Atacadao,,Banana prata,,,,,5.99,,,,\n'
        '\n'
        '2026-09-04,Atacadao,,Mamao formosa,,,,,4.49,,,,\n',
      );

      expect(resultado.erros, isEmpty);
      expect(resultado.totalLinhas, 2);
      expect(resultado.linhas, hasLength(2));
    });
  });

  group('lerCsv - decimal com ponto', () {
    test('le o ponto como separador decimal', () {
      final resultado = lerCsv(
        _arquivo([
          '2026-09-04,Assai,Mercearia,Acucar refinado,Uniao,1,kg,pacote,'
              '4.29,4.29,kg,,',
        ]),
      );

      final linha = resultado.linhas.single;
      expect(linha.preco, closeTo(4.29, 1e-9));
      expect(linha.precoRef, closeTo(4.29, 1e-9));
      expect(linha.embalagemQtd, closeTo(1.0, 1e-9));
    });

    test('converterDecimal trata ponto, virgula e milhar', () {
      expect(converterDecimal('3.99'), closeTo(3.99, 1e-9));
      expect(converterDecimal('3,99'), closeTo(3.99, 1e-9));
      expect(converterDecimal('1.234,56'), closeTo(1234.56, 1e-9));
      expect(converterDecimal('  10 '), closeTo(10.0, 1e-9));
      expect(converterDecimal(''), isNull);
      expect(converterDecimal(null), isNull);
      expect(converterDecimal('abc'), isNull);
    });
  });

  group('lerCsv - "Limite 3 un" na observacao', () {
    test('preenche limite_por_cliente a partir da observacao', () {
      final resultado = lerCsv(
        _arquivo([
          '2026-09-05,Assai,Bebidas,Cerveja pilsen,Heineken,350,ml,lata,'
              '3.49,9.97,L,,Limite 3 un por cliente',
        ]),
      );

      expect(resultado.erros, isEmpty);
      expect(resultado.linhas.single.limitePorCliente, 3);
    });

    test('extrairLimite aceita variacoes de escrita', () {
      expect(extrairLimite('Limite 3 un'), 3);
      expect(extrairLimite('limite 12 un por cliente'), 12);
      expect(extrairLimite('LIMITE 6UN'), 6);
      expect(extrairLimite('Limite 2 unidades'), 2);
      expect(extrairLimite('Leve 3 pague 2'), isNull);
      expect(extrairLimite(''), isNull);
      expect(extrairLimite(null), isNull);
    });
  });

  group('lerCsv - validacoes gerais', () {
    test('cabecalho diferente do esperado lanca erro', () {
      expect(
        () => lerCsv('data,loja,produto,preco\n2026-09-01,Assai,Arroz,24.90\n'),
        throwsA(isA<CabecalhoInvalidoException>()),
      );
    });

    test('linha com numero errado de colunas vira erro', () {
      final resultado = lerCsv(_arquivo(['2026-09-01,Assai,Mercearia,Arroz']));

      expect(resultado.linhas, isEmpty);
      expect(resultado.erros.single.motivo, contains('colunas'));
    });

    test('a mesma oferta repetida no arquivo entra uma vez so', () {
      final linha =
          '2026-09-06,Assai,Mercearia,Feijao carioca,Camil,1,kg,pacote,'
          '7.99,7.99,kg,,';
      final resultado = lerCsv(_arquivo([linha, linha]));

      expect(resultado.totalLinhas, 2);
      expect(resultado.linhas, hasLength(1));
      expect(resultado.erros.single.motivo, contains('Repetida'));
    });

    test('o BOM do UTF-8 no inicio do arquivo nao atrapalha', () {
      final resultado = lerCsv(
        '﻿$_cabecalho\n2026-09-01,Assai,,Arroz,Camil,5,kg,pacote,24.90,,,,\n',
      );

      expect(resultado.erros, isEmpty);
      expect(resultado.linhas, hasLength(1));
    });

    test('arquivo com quebra de linha do Windows e lido igual', () {
      final resultado = lerCsv(
        '$_cabecalho\r\n2026-09-01,Assai,,Arroz,Camil,5,kg,pacote,24.90,,,,\r\n',
      );

      expect(resultado.erros, isEmpty);
      expect(resultado.linhas.single.produto, 'Arroz');
    });
  });
}
