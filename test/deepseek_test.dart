import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:precos_supermercado/dados/deepseek.dart';

/// Nenhum teste aqui fala com a API de verdade: o cliente HTTP e falso.
http.Client _clienteFalso(
  Future<http.Response> Function(http.Request pedido) responder,
) =>
    MockClient((pedido) => responder(pedido));

String _respostaOk(String conteudo) => jsonEncode({
      'choices': [
        {
          'message': {'content': conteudo},
        }
      ],
      'usage': {
        'prompt_cache_hit_tokens': 1200,
        'prompt_cache_miss_tokens': 800,
        'completion_tokens': 500,
      },
    });

const String _jsonModelo =
    '{"data_oferta":"2026-09-11","loja":"Assai","itens":['
    '{"texto_original":"MELANCIA DOCINHA","produto":"Melancia",'
    '"preco":2.48,"embalagem_qtd":1,"embalagem_unidade":"kg",'
    '"unidade_venda":"kg","confianca":"alta"}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  group('corpo da requisicao', () {
    test('segue o formato da documentacao da DeepSeek', () async {
      Map<String, dynamic>? enviado;
      final cliente = Deepseek(
        chaveApi: 'chave-de-teste',
        clienteHttp: _clienteFalso((pedido) async {
          enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
          expect(
            pedido.headers['Authorization'],
            'Bearer chave-de-teste',
          );
          return http.Response(_respostaOk(_jsonModelo), 200);
        }),
      );

      await cliente.extrairDaFoto(bytes);

      expect(enviado!['model'], 'deepseek-flash');
      expect(enviado!['response_format'], {'type': 'json_object'});

      final mensagens = enviado!['messages'] as List<dynamic>;
      // As instrucoes fixas vem primeiro, para virar cache.
      expect((mensagens.first as Map)['role'], 'system');
      // O modo JSON da DeepSeek exige a palavra "json" no prompt e um
      // exemplo do formato. As instrucoes trazem os dois.
      final instrucoes = (mensagens.first as Map)['content'] as String;
      expect(instrucoes.toLowerCase(), contains('json'));
      expect(instrucoes, contains('"itens"'));

      final conteudo =
          (mensagens[1] as Map)['content'] as List<dynamic>;
      final texto = conteudo.firstWhere(
        (parte) => (parte as Map)['type'] == 'text',
      ) as Map<String, dynamic>;
      expect((texto['text'] as String).toLowerCase(), contains('json'));
      // O modelo precisa saber a data de hoje para completar o ano quando o
      // tabloide escreve so "dia 11/09".
      final hoje = DateTime.now();
      expect(
        texto['text'] as String,
        contains('${hoje.year}-'),
      );
      final imagem = conteudo.firstWhere(
        (parte) => (parte as Map)['type'] == 'image_url',
      ) as Map<String, dynamic>;
      final dados = imagem['image_url'] as Map<String, dynamic>;

      // Nunca "low": isso reduziria para 512x512 e apagaria os centavos.
      expect(dados['detail'], 'original');
      expect(dados['url'], startsWith('data:image/jpeg;base64,'));
    });

    test('raciocinio desligado por padrao vai explicito no pedido', () async {
      Map<String, dynamic>? enviado;
      final cliente = Deepseek(
        chaveApi: 'k',
        clienteHttp: _clienteFalso((pedido) async {
          enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
          return http.Response(_respostaOk(_jsonModelo), 200);
        }),
      );
      await cliente.extrairDaFoto(bytes);
      // O padrao da API e "enabled", entao desligar precisa ser explicito.
      expect(enviado!['thinking'], {'type': 'disabled'});
    });

    test('com o interruptor ligado, pede raciocinio', () async {
      Map<String, dynamic>? enviado;
      final cliente = Deepseek(
        chaveApi: 'k',
        raciocinio: true,
        clienteHttp: _clienteFalso((pedido) async {
          enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
          return http.Response(_respostaOk(_jsonModelo), 200);
        }),
      );
      await cliente.extrairDaFoto(bytes);
      expect(enviado!['thinking'], {'type': 'enabled'});
    });
  });

  group('resposta', () {
    test('le os itens e os tokens gastos', () async {
      final cliente = Deepseek(
        chaveApi: 'k',
        clienteHttp: _clienteFalso(
          (_) async => http.Response(_respostaOk(_jsonModelo), 200),
        ),
      );

      final resposta = await cliente.extrairDaFoto(bytes);

      expect(resposta.extracao.itens, hasLength(1));
      expect(resposta.extracao.loja, 'Assai');
      expect(resposta.uso.entradaComCache, 1200);
      expect(resposta.uso.entradaSemCache, 800);
      expect(resposta.uso.saida, 500);
    });

    test('aceita o JSON embrulhado em cerca de codigo', () async {
      final cliente = Deepseek(
        chaveApi: 'k',
        clienteHttp: _clienteFalso(
          (_) async =>
              http.Response(_respostaOk('```json\n$_jsonModelo\n```'), 200),
        ),
      );
      final resposta = await cliente.extrairDaFoto(bytes);
      expect(resposta.extracao.itens, hasLength(1));
    });
  });

  group('erros', () {
    test('sem chave nem tenta chamar a API', () async {
      var chamou = false;
      final cliente = Deepseek(
        chaveApi: '   ',
        clienteHttp: _clienteFalso((_) async {
          chamou = true;
          return http.Response(_respostaOk(_jsonModelo), 200);
        }),
      );

      await expectLater(
        cliente.extrairDaFoto(bytes),
        throwsA(
          isA<ExtracaoException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('chave da API'),
          ),
        ),
      );
      expect(chamou, isFalse);
    });

    test('401 fala em chave invalida e nao tenta de novo', () async {
      var chamadas = 0;
      final cliente = Deepseek(
        chaveApi: 'errada',
        clienteHttp: _clienteFalso((_) async {
          chamadas++;
          return http.Response('{"error":{"message":"bad key"}}', 401);
        }),
      );

      await expectLater(
        cliente.extrairDaFoto(bytes),
        throwsA(
          isA<ExtracaoException>()
              .having((e) => e.mensagem, 'mensagem', contains('invalida'))
              .having((e) => e.permiteNovaTentativa, 'sem retentar', isFalse),
        ),
      );
      expect(chamadas, 1);
    });

    test('402 sugere recarregar ou usar o CSV', () async {
      final cliente = Deepseek(
        chaveApi: 'k',
        clienteHttp: _clienteFalso((_) async => http.Response('{}', 402)),
      );

      await expectLater(
        cliente.extrairDaFoto(bytes),
        throwsA(
          isA<ExtracaoException>()
              .having((e) => e.mensagem, 'mensagem', contains('saldo'))
              .having((e) => e.mensagem, 'mensagem', contains('CSV'))
              .having((e) => e.permiteNovaTentativa, 'sem retentar', isFalse),
        ),
      );
    });

    test('429 tenta de novo e aproveita quando a proxima da certo', () async {
      var chamadas = 0;
      final cliente = Deepseek(
        chaveApi: 'k',
        clienteHttp: _clienteFalso((_) async {
          chamadas++;
          if (chamadas == 1) return http.Response('{}', 429);
          return http.Response(_respostaOk(_jsonModelo), 200);
        }),
      );

      final resposta = await cliente.extrairDaFoto(bytes);
      expect(chamadas, 2);
      expect(resposta.extracao.itens, hasLength(1));
    });

    test('erro que insiste para depois de 3 tentativas', () async {
      var chamadas = 0;
      final cliente = Deepseek(
        chaveApi: 'k',
        clienteHttp: _clienteFalso((_) async {
          chamadas++;
          return http.Response('{}', 503);
        }),
      );

      await expectLater(
        cliente.extrairDaFoto(bytes),
        throwsA(isA<ExtracaoException>()),
      );
      expect(chamadas, Deepseek.tentativasMaximas);
    });

    test('resposta vazia da API vira erro que da para tentar de novo', () async {
      var chamadas = 0;
      final cliente = Deepseek(
        chaveApi: 'k',
        clienteHttp: _clienteFalso((_) async {
          chamadas++;
          return http.Response(_respostaOk(''), 200);
        }),
      );

      await expectLater(
        cliente.extrairDaFoto(bytes),
        throwsA(
          isA<ExtracaoException>()
              .having((e) => e.mensagem, 'mensagem', contains('vazia')),
        ),
      );
      expect(chamadas, Deepseek.tentativasMaximas);
    });
  });
}
