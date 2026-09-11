import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/custo.dart';
import '../dados/estado_app.dart';
import '../dados/extracao_controlador.dart';
import '../dados/imagem.dart';
import '../dados/rascunho.dart';
import 'revisao_pagina.dart';
import 'widgets/foto_tela_cheia.dart';

/// Tela de importacao por foto: escolher as fotos, dizer loja/tipo/data e
/// mandar ler.
class ImportarFotosPagina extends StatefulWidget {
  const ImportarFotosPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<ImportarFotosPagina> createState() => _ImportarFotosPaginaState();
}

class _ImportarFotosPaginaState extends State<ImportarFotosPagina> {
  late final ControladorExtracao _controlador =
      ControladorExtracao(estado: widget.estado);
  final ImagePicker _seletor = ImagePicker();

  bool _preparando = false;
  String? _aviso;
  LoteFotos? _pendente;
  bool _procurouPendente = false;

  @override
  void initState() {
    super.initState();
    _controlador.addListener(_aoMudar);
    _procurarPendente();
  }

  @override
  void dispose() {
    _controlador.removeListener(_aoMudar);
    _controlador.dispose();
    super.dispose();
  }

  void _aoMudar() {
    if (mounted) setState(() {});
  }

  Future<void> _procurarPendente() async {
    final pendente = await _controlador.procurarPendente();
    if (!mounted) return;
    setState(() {
      _pendente = pendente;
      _procurouPendente = true;
    });
  }

  /// Le os arquivos escolhidos e reduz cada um fora da thread da tela.
  Future<List<FotoPreparada>> _prepararTodas(List<XFile> arquivos) async {
    final preparadas = <FotoPreparada>[];
    for (final arquivo in arquivos) {
      final bytes = await arquivo.readAsBytes();
      preparadas.add(await compute(prepararFoto, Uint8List.fromList(bytes)));
    }
    return preparadas;
  }

  Future<void> _escolherDaGaleria() async {
    final arquivos = await _seletor.pickMultiImage();
    if (arquivos.isEmpty) return;
    await _receberFotos(arquivos);
  }

  Future<void> _tirarFoto() async {
    final arquivo = await _seletor.pickImage(source: ImageSource.camera);
    if (arquivo == null) return;
    await _receberFotos([arquivo]);
  }

  Future<void> _receberFotos(List<XFile> arquivos) async {
    setState(() {
      _preparando = true;
      _aviso = null;
    });
    try {
      final preparadas = await _prepararTodas(arquivos);
      if (_controlador.temLote) {
        await _controlador.acrescentarFotos(preparadas);
      } else {
        await _controlador.novoLote(
          fotos: preparadas,
          loja: widget.estado.ultimaLoja,
          tipo: 'oferta',
        );
      }
      if (!mounted) return;
      setState(() => _pendente = null);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = erro.toString());
    } finally {
      if (mounted) setState(() => _preparando = false);
    }
  }

  Future<void> _extrair() async {
    final lote = _controlador.lote;
    if (lote == null) return;
    if (lote.loja.trim().isEmpty) {
      setState(() => _aviso = 'Escolha a loja antes de extrair.');
      return;
    }
    if (!widget.estado.temChaveDeepseek) {
      setState(
        () => _aviso = 'Falta a chave da API da DeepSeek. '
            'Preencha na tela Configuracao.',
      );
      return;
    }
    setState(() => _aviso = null);
    await widget.estado.salvarUltimaLoja(lote.loja);
    await _controlador.extrairPendentes();
  }

  Future<void> _abrirRevisao() async {
    final lote = _controlador.lote;
    if (lote == null) return;
    final gravou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RevisaoPagina(estado: widget.estado, lote: lote),
      ),
    );
    if (gravou == true) {
      await _controlador.concluir();
      if (!mounted) return;
      setState(() => _aviso = null);
    }
  }

  Future<void> _descartar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Descartar este lote?'),
        content: const Text(
          'As fotos e os precos ja lidos serao apagados do aparelho. '
          'O que ja foi gravado no banco nao muda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    await _controlador.descartar();
    if (!mounted) return;
    setState(() => _pendente = null);
  }

  @override
  Widget build(BuildContext context) {
    final lote = _controlador.lote;
    final pendente = _pendente;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Fotos do tabloide',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Escolha as fotos do encarte. O modelo le os produtos e precos, e '
          'voce confere tudo antes de gravar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (pendente != null && lote == null) ...[
          _CartaoPendente(
            lote: pendente,
            onContinuar: () {
              _controlador.continuarPendente(pendente);
              setState(() => _pendente = null);
            },
            onDescartar: _descartar,
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _preparando || _controlador.rodando
                  ? null
                  : _escolherDaGaleria,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Escolher da galeria'),
            ),
            OutlinedButton.icon(
              onPressed:
                  _preparando || _controlador.rodando ? null : _tirarFoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tirar foto'),
            ),
          ],
        ),
        if (_preparando) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            'Preparando as fotos...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_aviso != null) ...[
          const SizedBox(height: 16),
          _Aviso(texto: _aviso!, erro: true),
        ],
        if (_controlador.erroGeral != null) ...[
          const SizedBox(height: 16),
          _Aviso(texto: _controlador.erroGeral!, erro: true),
        ],
        if (lote != null) ...[
          const SizedBox(height: 20),
          _DadosDoLote(
            estado: widget.estado,
            lote: lote,
            habilitado: !_controlador.rodando,
            onMudou: _controlador.atualizarDadosDoLote,
          ),
          const SizedBox(height: 20),
          _Progresso(controlador: _controlador),
          const SizedBox(height: 12),
          for (final foto in lote.fotos)
            _LinhaFoto(
              foto: foto,
              ocupado: _controlador.rodando,
              onTentarDeNovo: () => _controlador.tentarDeNovo(foto),
            ),
          const SizedBox(height: 16),
          if (_controlador.rodando)
            OutlinedButton.icon(
              onPressed: _controlador.cancelar,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Parar'),
            )
          else ...[
            if (_controlador.pendentes > 0)
              FilledButton.icon(
                onPressed: _extrair,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  _controlador.prontas == 0
                      ? 'Extrair precos (${lote.fotos.length} fotos)'
                      : 'Extrair as ${_controlador.pendentes} que faltam',
                ),
              ),
            if (_controlador.prontas > 0) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _abrirRevisao,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text('Revisar ${lote.totalItens} itens'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _descartar,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Descartar lote'),
            ),
          ],
          if (lote.custoTotalUsd > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Custo estimado ate agora: ${formatarUsd(lote.custoTotalUsd)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ] else if (_procurouPendente && pendente == null) ...[
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.photo_camera_back_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhuma foto escolhida ainda',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CartaoPendente extends StatelessWidget {
  const _CartaoPendente({
    required this.lote,
    required this.onContinuar,
    required this.onDescartar,
  });

  final LoteFotos lote;
  final VoidCallback onContinuar;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      color: cores.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restore, color: cores.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Importacao pendente',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cores.onTertiaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sobrou um lote de ${lote.fotos.length} fotos de '
              '${DateFormat('dd/MM/yyyy').format(lote.criadoEm)}, com '
              '${lote.prontas} ja lidas e ${lote.totalItens} itens. '
              'Continuar daqui nao gasta a API de novo.',
              style: TextStyle(color: cores.onTertiaryContainer),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onContinuar,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continuar importacao'),
                ),
                TextButton(
                  onPressed: onDescartar,
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DadosDoLote extends StatelessWidget {
  const _DadosDoLote({
    required this.estado,
    required this.lote,
    required this.habilitado,
    required this.onMudou,
  });

  final EstadoApp estado;
  final LoteFotos lote;
  final bool habilitado;
  final Future<void> Function({String? loja, String? tipo, String? data}) onMudou;

  @override
  Widget build(BuildContext context) {
    final lojas = estado.nomesDasLojas;
    final data = lote.data == null || lote.data!.isEmpty
        ? DateTime.now()
        : (DateTime.tryParse(lote.data!) ?? DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dados do lote', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Loja',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: lojas.contains(lote.loja) ? lote.loja : null,
                  hint: const Text('Escolha a loja'),
                  items: [
                    for (final nome in lojas)
                      DropdownMenuItem(value: nome, child: Text(nome)),
                    const DropdownMenuItem(
                      value: _novaLoja,
                      child: Text('+ Nova loja...'),
                    ),
                  ],
                  onChanged: habilitado
                      ? (valor) async {
                          if (valor == null) return;
                          if (valor == _novaLoja) {
                            final nome = await _perguntarNovaLoja(context);
                            if (nome != null && nome.trim().isNotEmpty) {
                              await onMudou(loja: nome.trim());
                            }
                            return;
                          }
                          await onMudou(loja: valor);
                        }
                      : null,
                ),
              ),
            ),
            if (lote.loja.isNotEmpty && !lojas.contains(lote.loja)) ...[
              const SizedBox(height: 8),
              Text(
                'Loja nova: ${lote.loja}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'oferta',
                  label: Text('Tabloide'),
                  icon: Icon(Icons.local_offer_outlined),
                ),
                ButtonSegment(
                  value: 'prateleira',
                  label: Text('Prateleira'),
                  icon: Icon(Icons.sell_outlined),
                ),
              ],
              selected: {lote.tipo},
              onSelectionChanged: habilitado
                  ? (escolha) => onMudou(tipo: escolha.first)
                  : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Data da oferta'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(data)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: habilitado
                  ? () async {
                      final escolhida = await showDatePicker(
                        context: context,
                        initialDate: data,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (escolhida != null) {
                        await onMudou(
                          data: DateFormat('yyyy-MM-dd').format(escolhida),
                        );
                      }
                    }
                  : null,
            ),
            if (lote.data == null || lote.data!.isEmpty)
              Text(
                'Sem data ainda: vou usar hoje, ou a data que o modelo ler '
                'no tabloide.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  static const String _novaLoja = '__nova__';

  Future<String?> _perguntarNovaLoja(BuildContext context) {
    final controle = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Nova loja'),
        content: TextField(
          controller: controle,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da loja'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, controle.text),
            child: const Text('Usar'),
          ),
        ],
      ),
    );
  }
}

class _Progresso extends StatelessWidget {
  const _Progresso({required this.controlador});

  final ControladorExtracao controlador;

  @override
  Widget build(BuildContext context) {
    final total = controlador.total;
    final prontas = controlador.prontas;
    final fracao = total == 0 ? 0.0 : prontas / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                controlador.rodando
                    ? 'Lendo as fotos: $prontas de $total'
                    : '$prontas de $total fotos lidas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (controlador.rodando)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: fracao, minHeight: 8),
        ),
      ],
    );
  }
}

class _LinhaFoto extends StatelessWidget {
  const _LinhaFoto({
    required this.foto,
    required this.ocupado,
    required this.onTentarDeNovo,
  });

  final FotoDoLote foto;
  final bool ocupado;
  final VoidCallback onTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final (icone, cor, texto) = switch (foto.situacao) {
      SituacaoFoto.pendente => (Icons.schedule, cores.outline, 'Na fila'),
      SituacaoFoto.enviando => (Icons.cloud_upload_outlined, cores.primary, 'Enviando...'),
      SituacaoFoto.pronta => (
          Icons.check_circle,
          cores.primary,
          '${foto.itens.length} itens',
        ),
      SituacaoFoto.erro => (Icons.error_outline, cores.error, 'Erro'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => abrirFotoTelaCheia(context, foto.arquivo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      foto.arquivo,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 52,
                        height: 52,
                        color: cores.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        foto.nomeArquivo,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(icone, size: 14, color: cor),
                          const SizedBox(width: 4),
                          Text(
                            texto,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (foto.situacao == SituacaoFoto.erro && !ocupado)
                  TextButton(
                    onPressed: onTentarDeNovo,
                    child: const Text('Tentar de novo'),
                  ),
              ],
            ),
            if (foto.erro != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  foto.erro!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cores.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.erro});

  final String texto;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      color: erro ? cores.errorContainer : cores.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              erro ? Icons.error_outline : Icons.check_circle_outline,
              color: erro ? cores.onErrorContainer : cores.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  color: erro
                      ? cores.onErrorContainer
                      : cores.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
