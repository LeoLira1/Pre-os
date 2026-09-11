import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/custo.dart';
import 'deepseek.dart';
import 'estado_app.dart';
import 'imagem.dart';
import 'rascunho.dart';

/// Comanda a extracao das fotos: no maximo 3 ao mesmo tempo, salvando o
/// rascunho a cada foto que volta.
///
/// O rascunho e o que garante que uma foto nunca seja paga duas vezes: se o
/// app fechar no meio, o que ja foi lido continua guardado.
class ControladorExtracao extends ChangeNotifier {
  ControladorExtracao({
    required this.estado,
    RascunhoImportacao? rascunho,
    this.criarCliente,
  }) : _rascunho = rascunho ?? RascunhoImportacao();

  final EstadoApp estado;
  final RascunhoImportacao _rascunho;

  /// Permite trocar o cliente nos testes.
  final Deepseek Function()? criarCliente;

  /// Quantas fotos vao para a API ao mesmo tempo.
  static const int simultaneas = 3;

  LoteFotos? lote;
  bool rodando = false;
  bool _cancelar = false;

  /// Erro que impede continuar (chave errada, sem saldo).
  String? erroGeral;

  bool get temLote => lote != null && !lote!.vazio;

  int get prontas => lote?.prontas ?? 0;
  int get total => lote?.fotos.length ?? 0;

  /// Fotos que ainda nao foram lidas com sucesso.
  int get pendentes => total - prontas;

  /// Procura um lote deixado pela metade numa sessao anterior.
  Future<LoteFotos?> procurarPendente() => _rascunho.ler();

  /// Assume um lote que estava pendente.
  void continuarPendente(LoteFotos pendente) {
    lote = pendente;
    erroGeral = null;
    notifyListeners();
  }

  /// Cria um lote novo a partir das fotos escolhidas.
  ///
  /// As fotos ja chegam aqui reduzidas; o que for repetido (mesmo conteudo)
  /// entra uma vez so.
  Future<void> novoLote({
    required List<FotoPreparada> fotos,
    required String loja,
    required String tipo,
    String? data,
  }) async {
    await _rascunho.limpar();
    final itens = <FotoDoLote>[];
    final vistos = <String>{};
    var numero = 0;
    for (final foto in fotos) {
      numero++;
      if (!vistos.add(foto.hash)) continue;
      final caminho = await _rascunho.guardarFoto(foto.hash, foto.bytes);
      itens.add(
        FotoDoLote(
          id: foto.hash,
          nomeArquivo: 'Foto $numero',
          caminho: caminho,
        ),
      );
    }
    lote = LoteFotos(
      criadoEm: DateTime.now(),
      fotos: itens,
      loja: loja,
      tipo: tipo,
      data: data,
    );
    erroGeral = null;
    await _rascunho.salvar(lote!);
    notifyListeners();
  }

  /// Acrescenta fotos a um lote que ja existe.
  Future<void> acrescentarFotos(List<FotoPreparada> fotos) async {
    final atual = lote;
    if (atual == null) return;
    final vistos = atual.fotos.map((f) => f.id).toSet();
    var numero = atual.fotos.length;
    for (final foto in fotos) {
      if (!vistos.add(foto.hash)) continue;
      numero++;
      final caminho = await _rascunho.guardarFoto(foto.hash, foto.bytes);
      atual.fotos.add(
        FotoDoLote(
          id: foto.hash,
          nomeArquivo: 'Foto $numero',
          caminho: caminho,
        ),
      );
    }
    await _rascunho.salvar(atual);
    notifyListeners();
  }

  Future<void> atualizarDadosDoLote({
    String? loja,
    String? tipo,
    String? data,
  }) async {
    final atual = lote;
    if (atual == null) return;
    if (loja != null) atual.loja = loja;
    if (tipo != null) atual.tipo = tipo;
    if (data != null) atual.data = data;
    await _rascunho.salvar(atual);
    notifyListeners();
  }

  /// Le todas as fotos que ainda faltam.
  Future<void> extrairPendentes() async {
    final atual = lote;
    if (atual == null || rodando) return;

    rodando = true;
    _cancelar = false;
    erroGeral = null;
    notifyListeners();

    final cliente = criarCliente?.call() ??
        Deepseek(chaveApi: estado.chaveDeepseek, raciocinio: estado.raciocinio);

    try {
      final fila = Queue<FotoDoLote>.of(
        atual.fotos.where((f) => f.situacao != SituacaoFoto.pronta),
      );
      await Future.wait(<Future<void>>[
        for (var i = 0; i < simultaneas; i++) _trabalhador(fila, cliente),
      ]);
    } finally {
      if (criarCliente == null) cliente.fechar();
      rodando = false;
      await _rascunho.salvar(atual);
      notifyListeners();
    }
  }

  /// Tenta de novo uma foto que deu erro.
  Future<void> tentarDeNovo(FotoDoLote foto) async {
    if (rodando) return;
    rodando = true;
    _cancelar = false;
    erroGeral = null;
    notifyListeners();

    final cliente = criarCliente?.call() ??
        Deepseek(chaveApi: estado.chaveDeepseek, raciocinio: estado.raciocinio);
    try {
      await _extrairUma(foto, cliente);
    } finally {
      if (criarCliente == null) cliente.fechar();
      rodando = false;
      final atual = lote;
      if (atual != null) await _rascunho.salvar(atual);
      notifyListeners();
    }
  }

  void cancelar() {
    _cancelar = true;
    notifyListeners();
  }

  Future<void> _trabalhador(Queue<FotoDoLote> fila, Deepseek cliente) async {
    while (fila.isNotEmpty && !_cancelar) {
      await _extrairUma(fila.removeFirst(), cliente);
    }
  }

  Future<void> _extrairUma(FotoDoLote foto, Deepseek cliente) async {
    foto.situacao = SituacaoFoto.enviando;
    foto.erro = null;
    notifyListeners();

    try {
      final bytes = await foto.arquivo.readAsBytes();
      final resposta = await cliente.extrairDaFoto(Uint8List.fromList(bytes));

      foto.itens = resposta.extracao.itens;
      foto.dataLida = resposta.extracao.dataOferta;
      foto.lojaLida = resposta.extracao.loja;
      foto.uso = resposta.uso;
      foto.custoUsd = estimarCustoUsd(
        uso: resposta.uso,
        precos: estado.precosApi,
        momento: resposta.momento,
      );
      foto.situacao = SituacaoFoto.pronta;

      // A data lida na primeira foto preenche o lote, se ainda estiver vazio.
      final atual = lote;
      if (atual != null && (atual.data == null || atual.data!.isEmpty)) {
        if (foto.dataLida != null) atual.data = foto.dataLida;
      }
    } on ExtracaoException catch (erro) {
      foto.situacao = SituacaoFoto.erro;
      foto.erro = erro.mensagem;
      if (!erro.permiteNovaTentativa) {
        // Chave errada ou sem saldo: nao adianta seguir com as outras.
        erroGeral = erro.mensagem;
        _cancelar = true;
      }
    } catch (erro) {
      foto.situacao = SituacaoFoto.erro;
      foto.erro = erro.toString();
    }

    // Salva assim que a foto volta, para nao perder o que ja foi pago.
    final atual = lote;
    if (atual != null) await _rascunho.salvar(atual);
    notifyListeners();
  }

  /// Apaga o rascunho depois de gravar tudo no banco.
  Future<void> concluir() async {
    await _rascunho.limpar();
    lote = null;
    notifyListeners();
  }

  /// Descarta o lote sem gravar.
  Future<void> descartar() => concluir();
}
