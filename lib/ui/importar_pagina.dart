import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/csv_importacao.dart';
import '../dados/estado_app.dart';
import '../dados/turso.dart';

/// Contas da previa mostrada antes de confirmar a importacao.
class Previa {
  const Previa({
    required this.leitura,
    required this.produtosNovos,
    required this.produtosExistentes,
    required this.duplicados,
    required this.paraGravar,
  });

  final ResultadoLeituraCsv leitura;
  final int produtosNovos;
  final int produtosExistentes;
  final int duplicados;

  /// Linhas que realmente serao gravadas (sem as duplicadas).
  final List<LinhaCsv> paraGravar;
}

/// Tela de importacao de CSV: escolher arquivo, conferir a previa, confirmar.
class ImportarPagina extends StatefulWidget {
  const ImportarPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<ImportarPagina> createState() => _ImportarPaginaState();
}

class _ImportarPaginaState extends State<ImportarPagina> {
  String? _nomeArquivo;
  Previa? _previa;
  bool _ocupado = false;
  String? _erro;
  ResultadoImportacao? _resultado;

  Future<void> _escolherArquivo() async {
    setState(() {
      _erro = null;
      _resultado = null;
      _previa = null;
    });

    final arquivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (arquivo == null) return;

    setState(() {
      _ocupado = true;
      _nomeArquivo = arquivo.name;
    });

    try {
      final bytes = await arquivo.readAsBytes();
      // O arquivo e UTF-8; um byte estranho vira "?" em vez de derrubar tudo.
      await _montarPrevia(utf8.decode(bytes, allowMalformed: true));
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = _descrever(erro));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _montarPrevia(String conteudo) async {
    final leitura = lerCsv(conteudo);

    if (leitura.linhas.isEmpty) {
      setState(() {
        _previa = Previa(
          leitura: leitura,
          produtosNovos: 0,
          produtosExistentes: 0,
          duplicados: 0,
          paraGravar: const [],
        );
      });
      return;
    }

    // Confere no banco o que ja existe. Sem conexao nao da para saber o que
    // seria duplicado, e gravar tambem exige conexao, entao avisamos aqui.
    PreviaBanco? banco;
    Turso? conexao;
    try {
      conexao = widget.estado.abrirConexao();
      banco = await conexao.conferirNoBanco(leitura.linhas);
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = 'Nao foi possivel conferir o que ja esta no banco. '
            '${_descrever(erro)}';
        _previa = null;
      });
      return;
    } finally {
      await conexao?.fechar();
    }

    // Contagens por produto distinto, nao por linha.
    final chavesNovas = <String>{};
    final chavesConhecidas = <String>{};
    var duplicados = 0;
    final paraGravar = <LinhaCsv>[];

    for (final linha in leitura.linhas) {
      if (banco.produtosExistentes.containsKey(linha.chaveProduto)) {
        chavesConhecidas.add(linha.chaveProduto);
      } else {
        chavesNovas.add(linha.chaveProduto);
      }
      if (banco.precosExistentes.contains(linha.identidadePreco)) {
        duplicados++;
      } else {
        paraGravar.add(linha);
      }
    }

    if (!mounted) return;
    setState(() {
      _previa = Previa(
        leitura: leitura,
        produtosNovos: chavesNovas.length,
        produtosExistentes: chavesConhecidas.length,
        duplicados: duplicados,
        paraGravar: paraGravar,
      );
    });
  }

  Future<void> _confirmar() async {
    final previa = _previa;
    if (previa == null || previa.paraGravar.isEmpty) return;

    setState(() {
      _ocupado = true;
      _erro = null;
    });

    Turso? conexao;
    try {
      conexao = widget.estado.abrirConexao();
      final resultado = await conexao.importarLinhas(previa.paraGravar);
      await conexao.fechar();
      conexao = null;
      // Atualiza o cache para as outras telas ja mostrarem o que entrou.
      await widget.estado.sincronizar();
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _previa = null;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = _descrever(erro));
    } finally {
      await conexao?.fechar();
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previa = _previa;
    final resultado = _resultado;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('Importar CSV', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Escolha o arquivo do encarte. Antes de gravar voce ve um resumo '
          'do que vai entrar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _ocupado ? null : _escolherArquivo,
          icon: const Icon(Icons.folder_open),
          label: const Text('Escolher arquivo .csv'),
        ),
        if (_nomeArquivo != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _nomeArquivo!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        if (_ocupado) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
        ],
        if (_erro != null) ...[
          const SizedBox(height: 16),
          _Aviso(texto: _erro!, erro: true),
        ],
        if (resultado != null) ...[
          const SizedBox(height: 16),
          _Aviso(
            texto: 'Importacao concluida.\n'
                '${resultado.precosInseridos} registros de preco gravados.\n'
                '${resultado.produtosCriados} produtos novos.\n'
                '${resultado.lojasCriadas} lojas novas.\n'
                '${resultado.duplicadosIgnorados} ignorados por ja existirem.\n'
                'O cache local foi atualizado.',
            erro: false,
          ),
        ],
        if (previa != null) ...[
          const SizedBox(height: 20),
          _PainelPrevia(previa: previa),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                _ocupado || previa.paraGravar.isEmpty ? null : _confirmar,
            icon: const Icon(Icons.check),
            label: Text(
              previa.paraGravar.isEmpty
                  ? 'Nada novo para gravar'
                  : 'Confirmar importacao (${previa.paraGravar.length})',
            ),
          ),
        ],
        const SizedBox(height: 28),
        const _AjudaFormato(),
      ],
    );
  }
}

class _PainelPrevia extends StatelessWidget {
  const _PainelPrevia({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context) {
    final leitura = previa.leitura;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Previa', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Linha('Total de linhas', '${leitura.totalLinhas}'),
                _Linha('Produtos novos', '${previa.produtosNovos}'),
                _Linha('Produtos ja existentes', '${previa.produtosExistentes}'),
                _Linha(
                  'Registros duplicados (serao ignorados)',
                  '${previa.duplicados}',
                ),
                _Linha('Linhas com erro', '${leitura.erros.length}'),
                const Divider(height: 24),
                _Linha(
                  'Serao gravados',
                  '${previa.paraGravar.length}',
                  destaque: true,
                ),
              ],
            ),
          ),
        ),
        if (leitura.erros.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text('Ver as ${leitura.erros.length} linhas com erro'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final erro in leitura.erros.take(50))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linha ${erro.numeroLinha}: ${erro.motivo}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (erro.conteudo.isNotEmpty)
                          Text(
                            erro.conteudo,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                if (leitura.erros.length > 50)
                  Text(
                    'E mais ${leitura.erros.length - 50} linhas com erro.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.titulo, this.valor, {this.destaque = false});

  final String titulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final estilo = destaque
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: estilo)),
          Text(valor, style: estilo),
        ],
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
                  color:
                      erro ? cores.onErrorContainer : cores.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AjudaFormato extends StatelessWidget {
  const _AjudaFormato();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Como o arquivo precisa ser'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Arquivo .csv em UTF-8, separado por virgula, com ponto no '
              'decimal (3.99). A primeira linha precisa ser exatamente:',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              cabecalhoEsperado.join(','),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Campos vazios ficam em branco. Se a observacao tiver '
              '"Limite 3 un", o limite por cliente e preenchido sozinho.',
            ),
          ),
        ],
      ),
    );
  }
}

String _descrever(Object erro) {
  if (erro is CabecalhoInvalidoException) return erro.toString();
  final texto = erro.toString().replaceFirst('Exception: ', '');
  return texto.length > 400 ? '${texto.substring(0, 400)}...' : texto;
}
