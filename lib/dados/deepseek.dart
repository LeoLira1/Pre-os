import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../core/custo.dart';
import '../core/extracao_json.dart';

/// Endereco da API no formato compativel com a OpenAI.
const String _urlChat = 'https://api.deepseek.com/chat/completions';

/// Unico modelo da DeepSeek que aceita imagem.
const String modeloDeepseek = 'deepseek-flash';

/// Erro da extracao com mensagem pronta para mostrar na tela, em portugues.
class ExtracaoException implements Exception {
  const ExtracaoException(this.mensagem, {this.permiteNovaTentativa = true});

  final String mensagem;

  /// Falso quando tentar de novo nao vai adiantar (chave errada, sem saldo).
  final bool permiteNovaTentativa;

  @override
  String toString() => mensagem;
}

/// O que voltou da API para uma foto.
class RespostaExtracao {
  const RespostaExtracao({
    required this.extracao,
    required this.uso,
    required this.momento,
  });

  final ExtracaoFoto extracao;
  final UsoTokens uso;

  /// Hora da requisicao, usada para saber se caiu no horario de pico.
  final DateTime momento;
}

/// Cliente da API da DeepSeek para ler tabloides.
class Deepseek {
  Deepseek({
    required this.chaveApi,
    this.raciocinio = false,
    http.Client? clienteHttp,
  }) : _http = clienteHttp ?? http.Client();

  final String chaveApi;

  /// Liga o modo de raciocinio do modelo. Desligado por padrao: sai mais
  /// barato e mais rapido.
  final bool raciocinio;

  final http.Client _http;

  static String? _promptEmCache;

  /// Tempo maximo de espera por foto.
  static const Duration tempoLimite = Duration(seconds: 120);

  /// Quantas vezes tentar de novo quando o erro for temporario.
  static const int tentativasMaximas = 3;

  void fechar() => _http.close();

  /// Le as instrucoes do arquivo de asset (fica em cache depois da primeira).
  static Future<String> carregarPrompt() async {
    return _promptEmCache ??=
        await rootBundle.loadString('assets/prompts/extracao.txt');
  }

  /// Envia uma foto e devolve os itens lidos.
  ///
  /// Tenta de novo com espera crescente quando o erro e temporario
  /// (429, falha de rede, servidor ocupado).
  Future<RespostaExtracao> extrairDaFoto(Uint8List bytesJpeg) async {
    if (chaveApi.trim().isEmpty) {
      throw const ExtracaoException(
        'Falta a chave da API da DeepSeek. Preencha na tela Configuracao.',
        permiteNovaTentativa: false,
      );
    }

    final prompt = await carregarPrompt();
    Object? ultimoErro;

    for (var tentativa = 1; tentativa <= tentativasMaximas; tentativa++) {
      try {
        return await _umaTentativa(prompt, bytesJpeg);
      } on ExtracaoException catch (erro) {
        ultimoErro = erro;
        if (!erro.permiteNovaTentativa || tentativa == tentativasMaximas) {
          rethrow;
        }
      }
      // Espera crescente: 2s, depois 4s.
      await Future<void>.delayed(Duration(seconds: 2 * tentativa));
    }

    throw ultimoErro is ExtracaoException
        ? ultimoErro
        : const ExtracaoException('Nao consegui ler esta foto.');
  }

  Future<RespostaExtracao> _umaTentativa(
    String prompt,
    Uint8List bytesJpeg,
  ) async {
    final momento = DateTime.now();

    // As instrucoes fixas vao sempre primeiro e sempre iguais: essa parte
    // repetida entra no cache da DeepSeek e fica bem mais barata.
    final corpo = <String, dynamic>{
      'model': modeloDeepseek,
      'messages': [
        {'role': 'system', 'content': prompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              // A data de hoje vai junto porque o modelo nao sabe que dia e:
              // sem isso ele nao consegue completar o ano de "somente dia 11/09".
              'text': 'Hoje e ${_hoje(momento)}. '
                  'Extraia os produtos e precos desta foto de tabloide. '
                  'Responda somente com o json no formato combinado.',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,${base64Encode(bytesJpeg)}',
                // "original" mantem a foto inteira. Com "low" a DeepSeek
                // reduz para 512x512 e os centavos somem.
                'detail': 'original',
              },
            },
          ],
        },
      ],
      'response_format': {'type': 'json_object'},
      'thinking': {'type': raciocinio ? 'enabled' : 'disabled'},
      'max_tokens': raciocinio ? 32768 : 16384,
    };

    http.Response resposta;
    try {
      resposta = await _http
          .post(
            Uri.parse(_urlChat),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${chaveApi.trim()}',
            },
            body: jsonEncode(corpo),
          )
          .timeout(tempoLimite);
    } on TimeoutException {
      throw const ExtracaoException(
        'A DeepSeek demorou mais de 2 minutos para responder. '
        'Toque em "tentar de novo".',
      );
    } on SocketException {
      throw const ExtracaoException(
        'Sem internet. Conecte-se e toque em "tentar de novo".',
      );
    } on http.ClientException {
      throw const ExtracaoException(
        'A conexao caiu no meio do envio. Toque em "tentar de novo".',
      );
    }

    if (resposta.statusCode != 200) {
      throw _erroDaApi(resposta);
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const ExtracaoException(
        'A resposta da DeepSeek veio incompleta. Toque em "tentar de novo".',
      );
    }

    final escolhas = json['choices'] as List<dynamic>?;
    final conteudo = escolhas == null || escolhas.isEmpty
        ? null
        : ((escolhas.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?)?['content'] as String?;

    // A propria documentacao avisa que a API as vezes devolve conteudo
    // vazio. Nesse caso vale tentar de novo.
    if (conteudo == null || conteudo.trim().isEmpty) {
      throw const ExtracaoException(
        'A DeepSeek devolveu uma resposta vazia. Toque em "tentar de novo".',
      );
    }

    final extracao = lerRespostaModelo(conteudo);
    return RespostaExtracao(
      extracao: extracao,
      uso: _lerUso(json['usage']),
      momento: momento,
    );
  }

  /// Traduz o codigo de erro da API para uma frase que da para entender.
  ExtracaoException _erroDaApi(http.Response resposta) {
    final detalhe = _mensagemDaApi(resposta);
    switch (resposta.statusCode) {
      case 400:
      case 422:
        return ExtracaoException(
          'A DeepSeek recusou o pedido.${detalhe.isEmpty ? '' : ' $detalhe'}',
          permiteNovaTentativa: false,
        );
      case 401:
        return const ExtracaoException(
          'Chave da API invalida. Confira a chave da DeepSeek na tela '
          'Configuracao.',
          permiteNovaTentativa: false,
        );
      case 402:
        return const ExtracaoException(
          'Sem saldo na conta da DeepSeek. Recarregue em platform.deepseek.com '
          'ou use a importacao por CSV enquanto isso.',
          permiteNovaTentativa: false,
        );
      case 429:
        return const ExtracaoException(
          'Muitos pedidos de uma vez. Vou esperar um pouco e tentar de novo.',
        );
      case 500:
      case 503:
        return const ExtracaoException(
          'O servidor da DeepSeek esta com problema. Vou tentar de novo.',
        );
      default:
        return ExtracaoException(
          'A DeepSeek respondeu com erro ${resposta.statusCode}.'
          '${detalhe.isEmpty ? '' : ' $detalhe'}',
        );
    }
  }

  String _mensagemDaApi(http.Response resposta) {
    try {
      final json =
          jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
      final erro = json['error'];
      if (erro is Map<String, dynamic>) {
        final mensagem = erro['message']?.toString() ?? '';
        return mensagem.length > 200
            ? '${mensagem.substring(0, 200)}...'
            : mensagem;
      }
    } catch (_) {
      // Corpo nao era JSON; segue sem detalhe.
    }
    return '';
  }
}

/// Data de hoje no formato AAAA-MM-DD.
String _hoje(DateTime momento) {
  final mes = momento.month.toString().padLeft(2, '0');
  final dia = momento.day.toString().padLeft(2, '0');
  return '${momento.year}-$mes-$dia';
}

/// Le os contadores de token da resposta.
UsoTokens _lerUso(dynamic usage) {
  if (usage is! Map<String, dynamic>) return const UsoTokens();
  int inteiro(String chave) => (usage[chave] as num?)?.toInt() ?? 0;

  final comCache = inteiro('prompt_cache_hit_tokens');
  var semCache = inteiro('prompt_cache_miss_tokens');
  // Se a API nao separar, calcula pelo total.
  if (semCache == 0 && comCache == 0) {
    semCache = inteiro('prompt_tokens');
  }
  return UsoTokens(
    entradaSemCache: semCache,
    entradaComCache: comCache,
    saida: inteiro('completion_tokens'),
  );
}
