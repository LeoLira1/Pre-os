import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Limite de pixels antes de enviar para a API.
///
/// Foto de tabloide de WhatsApp (906x1600 = 1,45 milhao) passa sem mexer.
/// Foto de camera (12 MP) e reduzida ate caber aqui, mantendo a proporcao.
/// Reduzir demais apagaria os centavos em fonte pequena.
const int maxPixels = 1700000;

/// Uma foto pronta para enviar.
class FotoPreparada {
  const FotoPreparada({
    required this.bytes,
    required this.largura,
    required this.altura,
    required this.foiReduzida,
    required this.hash,
  });

  final Uint8List bytes;
  final int largura;
  final int altura;
  final bool foiReduzida;

  /// Identifica a foto pelo conteudo, para nao extrair a mesma duas vezes.
  final String hash;

  int get pixels => largura * altura;

  String get dataUri => 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

/// Erro quando o arquivo escolhido nao e uma imagem que da para ler.
class ImagemInvalidaException implements Exception {
  const ImagemInvalidaException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Reduz a foto se precisar e devolve os bytes em JPEG.
///
/// Roda em isolate (compute) na tela, porque decodificar uma foto grande
/// trava a interface.
FotoPreparada prepararFoto(Uint8List original) {
  final imagem = img.decodeImage(original);
  if (imagem == null) {
    throw const ImagemInvalidaException(
      'Nao consegui ler esta foto. Tente escolher outra.',
    );
  }

  final pixels = imagem.width * imagem.height;
  if (pixels <= maxPixels) {
    // Ja esta no tamanho bom: reaproveita o arquivo como veio.
    return FotoPreparada(
      bytes: original,
      largura: imagem.width,
      altura: imagem.height,
      foiReduzida: false,
      hash: sha256.convert(original).toString(),
    );
  }

  final escala = math.sqrt(maxPixels / pixels);
  final novaLargura = (imagem.width * escala).round();
  final reduzida = img.copyResize(
    imagem,
    width: novaLargura,
    interpolation: img.Interpolation.average,
  );
  final bytes = Uint8List.fromList(img.encodeJpg(reduzida, quality: 90));

  return FotoPreparada(
    bytes: bytes,
    largura: reduzida.width,
    altura: reduzida.height,
    foiReduzida: true,
    hash: sha256.convert(bytes).toString(),
  );
}
