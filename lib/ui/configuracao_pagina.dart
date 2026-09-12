import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/custo.dart';
import '../dados/estado_app.dart';
import '../dados/turso.dart';

/// Tela onde o usuario digita as credenciais do Turso e cuida do cache.
///
/// Nada digitado aqui vai para o codigo ou para o repositorio: fica guardado
/// somente neste aparelho.
class ConfiguracaoPagina extends StatefulWidget {
  const ConfiguracaoPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<ConfiguracaoPagina> createState() => _ConfiguracaoPaginaState();
}

class _ConfiguracaoPaginaState extends State<ConfiguracaoPagina> {
  late final TextEditingController _url =
      TextEditingController(text: widget.estado.url);
  late final TextEditingController _token =
      TextEditingController(text: widget.estado.token);
  late final TextEditingController _deepseek =
      TextEditingController(text: widget.estado.chaveDeepseek);

  late final TextEditingController _precoEntrada = TextEditingController(
    text: _semZerosAtoa(widget.estado.precosApi.entradaSemCache),
  );
  late final TextEditingController _precoCache = TextEditingController(
    text: _semZerosAtoa(widget.estado.precosApi.entradaComCache),
  );
  late final TextEditingController _precoSaida = TextEditingController(
    text: _semZerosAtoa(widget.estado.precosApi.saida),
  );

  bool _mostrarToken = false;
  bool _mostrarDeepseek = false;
  bool _testando = false;
  String? _mensagem;
  bool _mensagemDeErro = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _deepseek.dispose();
    _precoEntrada.dispose();
    _precoCache.dispose();
    _precoSaida.dispose();
    super.dispose();
  }

  /// Guarda a tabela de precos como ela esta nos campos.
  Future<void> _salvarPrecos({bool? picoDobra}) async {
    final atual = widget.estado.precosApi;
    await widget.estado.salvarPrecosApi(
      atual.copiarCom(
        entradaSemCache: _numero(_precoEntrada.text) ?? atual.entradaSemCache,
        entradaComCache: _numero(_precoCache.text) ?? atual.entradaComCache,
        saida: _numero(_precoSaida.text) ?? atual.saida,
        picoDobra: picoDobra,
      ),
    );
  }

  static double? _numero(String texto) {
    final limpo = texto.trim().replaceAll(',', '.');
    if (limpo.isEmpty) return null;
    return double.tryParse(limpo);
  }

  /// Mostra 0.15 em vez de 0.150000000000000002.
  static String _semZerosAtoa(double valor) {
    var texto = valor.toStringAsFixed(6);
    texto = texto.replaceFirst(RegExp(r'0+$'), '');
    texto = texto.replaceFirst(RegExp(r'\.$'), '');
    return texto.isEmpty ? '0' : texto;
  }

  Future<void> _salvar() async {
    await widget.estado.salvarConfiguracao(
      novaUrl: _url.text,
      novoToken: _token.text,
      novaChaveDeepseek: _deepseek.text,
    );
    if (!mounted) return;
    setState(() {
      _mensagem = 'Configuracao salva neste aparelho.';
      _mensagemDeErro = false;
    });
  }

  Future<void> _testarConexao() async {
    await _salvar();
    setState(() {
      _testando = true;
      _mensagem = null;
    });
    Turso? conexao;
    try {
      conexao = widget.estado.abrirConexao();
      final resposta = await conexao.testarConexao();
      if (!mounted) return;
      setState(() {
        _mensagem = resposta;
        _mensagemDeErro = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagem = 'Nao foi possivel conectar. ${_descreverErro(erro)}';
        _mensagemDeErro = true;
      });
    } finally {
      await conexao?.fechar();
      if (mounted) setState(() => _testando = false);
    }
  }

  Future<void> _sincronizar() async {
    await _salvar();
    try {
      await widget.estado.sincronizar();
      if (!mounted) return;
      setState(() {
        _mensagem = 'Cache atualizado: '
            '${widget.estado.conteudo.produtos.length} produtos e '
            '${widget.estado.conteudo.precos.length} registros de preco.';
        _mensagemDeErro = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _mensagem = 'Nao foi possivel sincronizar. ${_descreverErro(erro)}';
        _mensagemDeErro = true;
      });
    }
  }

  Future<void> _limparCache() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Limpar cache local?'),
        content: const Text(
          'A copia guardada neste aparelho sera apagada. Os dados continuam '
          'no Turso e voltam quando voce tocar em Sincronizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    await widget.estado.limparCache();
    if (!mounted) return;
    setState(() {
      _mensagem = 'Cache local apagado.';
      _mensagemDeErro = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final cores = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('Configuracao', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Os dados abaixo ficam salvos somente neste aparelho.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _url,
          decoration: const InputDecoration(
            labelText: 'Database URL do Turso',
            hintText: 'libsql://seu-banco.turso.io',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: !_mostrarToken,
          decoration: InputDecoration(
            labelText: 'Token do Turso',
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: Icon(
                _mostrarToken ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _mostrarToken = !_mostrarToken),
            ),
          ),
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _deepseek,
          obscureText: !_mostrarDeepseek,
          decoration: InputDecoration(
            labelText: 'Chave da API DeepSeek',
            helperText: 'Usada para ler os precos das fotos do tabloide.',
            prefixIcon: const Icon(Icons.smart_toy_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _mostrarDeepseek ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _mostrarDeepseek = !_mostrarDeepseek),
            ),
          ),
          autocorrect: false,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _testando ? null : _salvar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar'),
            ),
            OutlinedButton.icon(
              onPressed: _testando ? null : _testarConexao,
              icon: _testando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Testar conexao'),
            ),
          ],
        ),
        if (_mensagem != null) ...[
          const SizedBox(height: 16),
          Card(
            color: _mensagemDeErro
                ? cores.errorContainer
                : cores.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _mensagemDeErro
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: _mensagemDeErro
                        ? cores.onErrorContainer
                        : cores.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _mensagem!,
                      style: TextStyle(
                        color: _mensagemDeErro
                            ? cores.onErrorContainer
                            : cores.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          'Comparacao entre marcas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Grupo generico junta a mesma coisa de marcas e embalagens '
          'diferentes, desde que a unidade de comparacao seja a mesma.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            value: estado.compararMarcasPadrao,
            onChanged: (ligado) => estado.salvarCompararMarcasPadrao(ligado),
            secondary: const Icon(Icons.compare_arrows),
            title: const Text('Comparar entre marcas por padrao'),
            subtitle: const Text(
              'Vale para os grupos genericos que voce aceitar na tela Juntar. '
              'Cada grupo continua podendo ser ligado ou desligado na tela '
              'dele.',
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Leitura de fotos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Ajustes do modelo que le os tabloides.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: estado.raciocinio,
                onChanged: (ligado) => estado.salvarRaciocinio(ligado),
                title: const Text('Raciocinio na extracao'),
                subtitle: const Text(
                  'Desligado sai mais rapido e mais barato. Ligue para '
                  'comparar a qualidade em tabloides dificeis.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Custo da API',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Precos em dolares por milhao de tokens. Os valores ja vem '
          'preenchidos com a tabela da DeepSeek fora do horario de pico.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _precoEntrada,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Entrada',
                  helperText: 'sem cache',
                  isDense: true,
                ),
                onChanged: (_) => _salvarPrecos(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _precoCache,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Entrada',
                  helperText: 'com cache',
                  isDense: true,
                ),
                onChanged: (_) => _salvarPrecos(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _precoSaida,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Saida',
                  helperText: 'resposta',
                  isDense: true,
                ),
                onChanged: (_) => _salvarPrecos(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: estado.precosApi.picoDobra,
                onChanged: (ligado) => _salvarPrecos(picoDobra: ligado),
                title: const Text('Horario de pico dobra o preco'),
                subtitle: Text(
                  'Pico: 01:00-04:00 e 06:00-10:00 UTC, de segunda a sexta. '
                  'Agora ${estaNoHorarioDePico(DateTime.now()) ? 'E' : 'NAO e'} '
                  'horario de pico.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Total gasto ate agora'),
                subtitle: const Text('Somando todas as importacoes por foto'),
                trailing: Text(
                  formatarUsd(estado.custoAcumuladoUsd),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Cache local', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Uma copia dos dados fica guardada no aparelho para o app abrir e '
          'consultar mesmo sem internet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _linhaInfo(
                  'Ultima sincronizacao',
                  estado.atualizadoEm == null
                      ? 'Nunca'
                      : DateFormat("dd/MM/yyyy 'as' HH:mm")
                          .format(estado.atualizadoEm!),
                ),
                _linhaInfo('Lojas', '${estado.conteudo.lojas.length}'),
                _linhaInfo('Produtos', '${estado.conteudo.produtos.length}'),
                _linhaInfo(
                  'Registros de preco',
                  '${estado.conteudo.precos.length}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: estado.sincronizando ? null : _sincronizar,
              icon: estado.sincronizando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('Sincronizar'),
            ),
            OutlinedButton.icon(
              onPressed: estado.sincronizando ? null : _limparCache,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Limpar cache local'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _linhaInfo(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            valor,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Transforma a excecao tecnica numa frase curta.
String _descreverErro(Object erro) {
  final texto = erro.toString().replaceFirst('Exception: ', '');
  return texto.length > 300 ? '${texto.substring(0, 300)}...' : texto;
}
