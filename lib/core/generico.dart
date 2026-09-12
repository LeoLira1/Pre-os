import '../modelos/modelos.dart';
import 'grupos.dart';
import 'texto.dart';

/// Palavras que descrevem o recipiente, nunca o produto em si.
///
/// Saem do nome generico porque "Agua Sanitaria Garrafa 2L" e "Agua
/// Sanitaria 2L" sao a mesma coisa.
const _palavrasDeEmbalagem = <String>{
  'garrafa',
  'garrafas',
  'frasco',
  'frascos',
  'pacote',
  'pacotes',
  'pct',
  'embalagem',
  'unidade',
  'unidades',
  'und',
  'unid',
  'leve',
  'pague',
};

/// Unidades que podem vir grudadas no numero: "2L", "500 ml", "5 kg".
const _unidadesNoNome = <String>{
  'kg',
  'g',
  'mg',
  'ml',
  'l',
  'lt',
  'lts',
  'litro',
  'litros',
  'un',
  'und',
  'unid',
  'rolo',
  'rolos',
  'cx',
};

final _alternativaDeUnidade = _unidadesNoNome.join('|');
final _numeroComUnidade =
    RegExp('^\\d+([.,]\\d+)?($_alternativaDeUnidade)\$');
final _somenteNumero = RegExp(r'^\d+([.,]\d+)?$');
final _multiplicador = RegExp(r'^\d+([.,]\d+)?x(\d+([.,]\d+)?[a-z]*)?$');

/// Verdadeiro quando o texto fala de produto concentrado.
///
/// Concentrado rende muito mais que o comum, entao nunca entra no grupo
/// generico do comum sem o usuario mandar.
bool ehConcentrado(String? texto) {
  final normal = normalizar(texto);
  return normal.contains('concentrad');
}

/// O nome sem marca e sem embalagem: "Agua Sanitaria Qboa 2L" vira
/// "Agua Sanitaria".
///
/// Mantem os acentos e as maiusculas do texto original, para o nome ficar
/// apresentavel na tela. A palavra "concentrado" continua no nome de
/// proposito: e ela que separa o concentrado do comum.
String nomeSemMarcaEEmbalagem(String nome, {String? marca}) {
  final marcas = normalizar(marca)
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toSet();

  // "2 L" e "2L" viram a mesma coisa antes de separar as palavras.
  final juntado = nome.replaceAllMapped(
    RegExp('(\\d)\\s+($_alternativaDeUnidade)\\b', caseSensitive: false),
    (m) => '${m[1]}${m[2]}',
  );

  final mantidas = <String>[];
  for (final palavra in juntado.split(RegExp(r'\s+'))) {
    if (palavra.trim().isEmpty) continue;
    final limpa = normalizar(palavra).replaceAll(RegExp(r'[^a-z0-9.,]'), '');
    if (limpa.isEmpty) continue;
    if (marcas.contains(limpa)) continue;
    if (_palavrasDeEmbalagem.contains(limpa)) continue;
    if (_unidadesNoNome.contains(limpa)) continue;
    if (_somenteNumero.hasMatch(limpa)) continue;
    if (_numeroComUnidade.hasMatch(limpa)) continue;
    if (_multiplicador.hasMatch(limpa)) continue;
    mantidas.add(palavra.trim());
  }

  final resultado = mantidas.join(' ').trim();
  return resultado.isEmpty ? nome.trim() : resultado;
}

/// A chave usada para saber se dois nomes falam do mesmo tipo de produto.
///
/// Acucar e arroz nunca dao a mesma chave, entao nunca sao sugeridos juntos.
String chaveGenerica(String nome, {String? marca}) =>
    normalizarNomeBase(nomeSemMarcaEEmbalagem(nome, marca: marca));

/// Como um grupo aparece na comparacao entre marcas.
class ResumoGenerico {
  const ResumoGenerico({
    required this.grupo,
    required this.chave,
    required this.nome,
    required this.unidadeRef,
    required this.concentrado,
  });

  final Grupo grupo;

  /// Nome generico normalizado, usado so para comparar.
  final String chave;

  /// Nome generico como aparece na tela ("Agua Sanitaria").
  final String nome;

  /// Unidade de referencia do grupo, ja canonica ("l", "kg", "un").
  final String unidadeRef;
  final bool concentrado;
}

/// Descreve um grupo pelo nome generico dos produtos que estao nele.
///
/// Quando o grupo ja tem nome_generico gravado, ele manda. Senao o nome
/// generico sai do nome do grupo, tirando a marca dos produtos vinculados.
ResumoGenerico? descreverGrupo({
  required Grupo grupo,
  required List<Produto> produtos,
  String? unidadeRef,
}) {
  final unidade = unidadeCanonica(unidadeRef ?? grupo.unidadeRef);
  if (unidade.isEmpty) return null;

  final gravado = (grupo.nomeGenerico ?? '').trim();
  final String nome;
  if (gravado.isNotEmpty) {
    nome = gravado;
  } else {
    // Tira a marca de qualquer produto do grupo: o nome do grupo costuma
    // copiar o nome de um deles.
    var candidato = grupo.nome;
    for (final produto in produtos) {
      candidato = nomeSemMarcaEEmbalagem(candidato, marca: produto.marca);
    }
    nome = nomeSemMarcaEEmbalagem(candidato);
  }

  final chave = normalizarNomeBase(nome);
  if (chave.isEmpty) return null;

  return ResumoGenerico(
    grupo: grupo,
    chave: chave,
    nome: nome,
    unidadeRef: unidade,
    concentrado:
        ehConcentrado(grupo.nome) || produtos.any((p) => ehConcentrado(p.nome)),
  );
}

/// Sugestao de juntar varios grupos num grupo generico.
class SugestaoGenerica {
  const SugestaoGenerica({
    required this.nomeGenerico,
    required this.chave,
    required this.unidadeRef,
    required this.grupos,
    required this.concentrado,
    this.categoria,
  });

  /// "Agua Sanitaria".
  final String nomeGenerico;

  /// Chave normalizada, usada para guardar a recusa.
  final String chave;

  /// Unidade canonica compartilhada por todos os grupos ("l", "kg", "un").
  final String unidadeRef;

  /// Os grupos que viram um so, do menor id para o maior.
  final List<Grupo> grupos;

  /// Verdadeiro quando a sugestao e de produtos concentrados. O rendimento
  /// e diferente do comum, entao a tela mostra um aviso.
  final bool concentrado;
  final String? categoria;

  /// O grupo que continua existindo e recebe os produtos dos outros.
  Grupo get destino => grupos.first;

  List<int> get idsParaJuntar => grupos.map((g) => g.id).toList();

  /// Identidade estavel da sugestao, para guardar a recusa.
  String get identidade => '$chave|$unidadeRef|${concentrado ? 1 : 0}';
}

/// Sugere juntar grupos que falam do mesmo produto, mesmo com marcas e
/// embalagens diferentes.
///
/// Duas travas que nunca saem:
/// - unidade_ref diferente nunca se mistura (por L com por kg, por exemplo);
/// - tipo de produto diferente nunca se mistura, porque a chave generica
///   precisa ser exatamente igual (acucar nunca encontra arroz).
///
/// Concentrado sai numa sugestao propria, nunca junto com o comum.
List<SugestaoGenerica> gerarSugestoesGenericas({
  required List<Grupo> grupos,
  required List<Produto> Function(int grupoId) produtosDoGrupo,
  String? Function(int grupoId)? unidadeDoGrupo,
  Set<String> rejeitadas = const <String>{},
}) {
  final baldes = <String, List<ResumoGenerico>>{};

  for (final grupo in grupos) {
    final produtos = produtosDoGrupo(grupo.id);
    if (produtos.isEmpty) continue;
    final resumo = descreverGrupo(
      grupo: grupo,
      produtos: produtos,
      unidadeRef: unidadeDoGrupo?.call(grupo.id) ?? grupo.unidadeRef,
    );
    if (resumo == null) continue;
    final balde =
        '${resumo.chave}|${resumo.unidadeRef}|${resumo.concentrado ? 1 : 0}';
    baldes.putIfAbsent(balde, () => <ResumoGenerico>[]).add(resumo);
  }

  final sugestoes = <SugestaoGenerica>[];
  for (final entrada in baldes.entries) {
    final itens = entrada.value;
    if (itens.length < 2) continue;
    if (rejeitadas.contains(entrada.key)) continue;
    itens.sort((a, b) => a.grupo.id.compareTo(b.grupo.id));

    // Nome mais curto ganha: "Agua Sanitaria" em vez de "Agua Sanitaria Ype".
    final nome = itens
        .map((i) => i.nome)
        .reduce((a, b) => a.length <= b.length ? a : b);
    final categoria = itens
        .map((i) => (i.grupo.categoria ?? '').trim())
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');

    sugestoes.add(
      SugestaoGenerica(
        nomeGenerico: nome,
        chave: itens.first.chave,
        unidadeRef: itens.first.unidadeRef,
        grupos: itens.map((i) => i.grupo).toList(),
        concentrado: itens.first.concentrado,
        categoria: categoria.isEmpty ? null : categoria,
      ),
    );
  }

  sugestoes.sort((a, b) {
    // Comum antes de concentrado; depois o que junta mais lojas.
    if (a.concentrado != b.concentrado) return a.concentrado ? 1 : -1;
    final porTamanho = b.grupos.length.compareTo(a.grupos.length);
    if (porTamanho != 0) return porTamanho;
    return normalizar(a.nomeGenerico).compareTo(normalizar(b.nomeGenerico));
  });
  return sugestoes;
}
