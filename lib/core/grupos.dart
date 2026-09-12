import '../modelos/modelos.dart';
import 'generico.dart';
import 'similaridade.dart';
import 'texto.dart';

enum ForcaSugestao { forte, possivel }

class SugestaoGrupo {
  const SugestaoGrupo({
    required this.produto,
    required this.grupo,
    required this.forca,
    required this.nota,
    this.atributosDiferentes = const <String>[],
    this.parteDoNome,
    this.generica = false,
  });

  final Produto produto;
  final Grupo grupo;
  final ForcaSugestao forca;
  final double nota;
  final List<String> atributosDiferentes;
  final String? parteDoNome;

  /// Verdadeiro quando o destino e um grupo generico, que compara marcas e
  /// embalagens diferentes entre si.
  final bool generica;
}

const _adjetivosIgnorados = <String>{
  'especial',
  'docinha',
  'caipira',
  'verdinho',
  'verdinha',
  'grande',
  'inteiro',
  'inteira',
  'nacional',
  'kg',
  'peca',
  'pedaco',
};

const _atributos = <String>[
  'congelado',
  'congelada',
  'resfriado',
  'resfriada',
  'com osso',
  'sem osso',
  'tipo 1',
  'tipo 2',
  'integral',
  'desnatado',
  'desnatada',
  'com pele',
  'sem pele',
];

String unidadeCanonica(String? unidade) {
  final valor = normalizar(unidade).replaceAll('.', '');
  if (const {'quilo', 'quilos', 'kilograma', 'kilogramas', 'kg'}.contains(valor)) {
    return 'kg';
  }
  if (const {'litro', 'litros', 'l'}.contains(valor)) return 'l';
  if (const {'un', 'und', 'unidade', 'unidades'}.contains(valor)) return 'un';
  return valor;
}

/// Divide nomes anunciados como alternativas. Quando so a ultima alternativa
/// traz qualificadores compartilhados, eles sao copiados para as anteriores.
List<String> dividirAlternativas(String nome) {
  final partes = nome
      .split(RegExp(r'\s+ou\s+|\s*,\s*', caseSensitive: false))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.length < 2) return <String>[nome.trim()];

  final palavrasUltima = partes.last.split(RegExp(r'\s+'));
  final sufixo = palavrasUltima.length > 1
      ? palavrasUltima.sublist(1).join(' ')
      : '';
  if (sufixo.isEmpty) return partes;

  return <String>[
    for (var i = 0; i < partes.length; i++)
      if (i < partes.length - 1 && partes[i].split(RegExp(r'\s+')).length == 1)
        '${partes[i]} ${_ajustarGeneroDoSufixo(partes[i], sufixo)}'
      else
        partes[i],
  ];
}

String _ajustarGeneroDoSufixo(String cabeca, String sufixo) {
  final nome = normalizar(cabeca);
  if (const {'pernil', 'lombo'}.contains(nome) &&
      normalizar(sufixo).startsWith('suina')) {
    return sufixo.replaceFirst(RegExp(r'^suína', caseSensitive: false), 'Suíno');
  }
  return sufixo;
}

String normalizarNomeBase(String nome, {bool removerAtributos = false}) {
  var texto = normalizar(nome)
      .replaceAll(RegExp(r'\btipo\s+b\b'), ' ')
      .replaceAllMapped(
        RegExp(r'(\d)\s+(kg|g|ml|l|un)\b'),
        (m) => '${m[1]}${m[2]}',
      )
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  if (removerAtributos) {
    for (final atributo in _atributos) {
      texto = texto.replaceAll(RegExp('\\b${RegExp.escape(atributo)}\\b'), ' ');
    }
  }
  final palavras = texto
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && !_adjetivosIgnorados.contains(p));
  return palavras.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> atributosDoNome(String nome) {
  final texto = normalizar(nome);
  return [for (final atributo in _atributos) if (texto.contains(atributo)) atributo];
}

List<String> atributosDiferentes(String a, String b) {
  final aa = atributosDoNome(a).toSet();
  final ab = atributosDoNome(b).toSet();
  return <String>[...aa.difference(ab), ...ab.difference(aa)];
}

/// Gera sugestoes sem alterar nenhum dado. Rejeicoes e vinculos existentes
/// sao respeitados, e unidades de referencia diferentes nunca se misturam.
List<SugestaoGrupo> gerarSugestoesGrupos({
  required List<Produto> produtos,
  required List<Grupo> grupos,
  required List<ProdutoGrupo> vinculos,
  required List<SugestaoRejeitada> rejeitadas,
  required String? Function(int produtoId) unidadeDoProduto,
}) {
  final produtosPorId = {for (final p in produtos) p.id: p};
  final grupoIdsPorProduto = <int, Set<int>>{};
  final produtoIdsPorGrupo = <int, Set<int>>{};
  for (final vinculo in vinculos) {
    grupoIdsPorProduto.putIfAbsent(vinculo.produtoId, () => <int>{}).add(vinculo.grupoId);
    produtoIdsPorGrupo.putIfAbsent(vinculo.grupoId, () => <int>{}).add(vinculo.produtoId);
  }
  final recusadas = {
    for (final r in rejeitadas) '${r.produtoId}:${r.grupoId}',
  };
  final sugestoes = <SugestaoGrupo>[];

  for (final produto in produtos) {
    final unidadeProduto = unidadeCanonica(unidadeDoProduto(produto.id));
    if (unidadeProduto.isEmpty) continue;
    final partes = dividirAlternativas(produto.nome);
    final ehLista = partes.length > 1;

    for (final grupo in grupos) {
      if ((grupoIdsPorProduto[produto.id] ?? const <int>{}).contains(grupo.id)) continue;
      if (recusadas.contains('${produto.id}:${grupo.id}')) continue;
      if (unidadeCanonica(grupo.unidadeRef) != unidadeProduto) continue;
      final membros = produtoIdsPorGrupo[grupo.id] ?? const <int>{};
      if (membros.isEmpty) continue;

      // Grupo generico: a marca e o tamanho da embalagem nao importam, desde
      // que a unidade de referencia seja a mesma e o tipo de produto tambem.
      if (grupo.ignoraMarca) {
        final generica = _sugerirNoGrupoGenerico(
          produto: produto,
          grupo: grupo,
          membros: membros.map((id) => produtosPorId[id]).nonNulls.toList(),
        );
        if (generica != null) sugestoes.add(generica);
        continue;
      }

      final membroBase = produtosPorId[membros.reduce((a, b) => a < b ? a : b)];
      if (membroBase == null) continue;
      if (dividirAlternativas(membroBase.nome).length > 1) continue;
      if (!ehLista && produto.id < membroBase.id) continue;

      final marcaProduto = normalizar(produto.marca);
      final marcaMembro = normalizar(membroBase.marca);
      if (marcaProduto.isNotEmpty || marcaMembro.isNotEmpty) {
        if (marcaProduto != marcaMembro ||
            formatarNumeroCanonico(produto.embalagemQtd) !=
                formatarNumeroCanonico(membroBase.embalagemQtd) ||
            unidadeCanonica(produto.embalagemUnidade) !=
                unidadeCanonica(membroBase.embalagemUnidade)) {
          continue;
        }
      } else if (!_podeCompararComoProdutoFresco(
        produto,
        membroBase,
        unidadeProduto,
      )) {
        // Sem marca, a aproximacao flexivel e exclusiva de hortifruti e
        // acougue vendidos a granel. Pacotes como arroz e acucar de 5 kg nao
        // podem entrar nessa regra, mesmo que a marca tenha vindo vazia.
        continue;
      }

      SugestaoGrupo? melhor;
      for (final parte in partes) {
        final candidata = _comparar(
          produto: produto,
          nomeProduto: parte,
          grupo: grupo,
          nomeGrupo: grupo.nome,
          parteDoNome: ehLista ? parte : null,
        );
        if (candidata != null && (melhor == null || candidata.nota > melhor.nota)) {
          melhor = candidata;
        }
      }
      if (melhor != null) sugestoes.add(melhor);
    }
  }

  sugestoes.sort((a, b) {
    final forca = a.forca.index.compareTo(b.forca.index);
    if (forca != 0) return forca;
    return b.nota.compareTo(a.nota);
  });
  return sugestoes;
}

/// Sugere um produto para um grupo generico.
///
/// So aceita quando o nome sem marca e sem embalagem e exatamente o mesmo,
/// entao acucar nunca cai no grupo do arroz. Concentrado nunca entra no
/// grupo do comum: o rendimento e outro.
SugestaoGrupo? _sugerirNoGrupoGenerico({
  required Produto produto,
  required Grupo grupo,
  required List<Produto> membros,
}) {
  final resumo = descreverGrupo(grupo: grupo, produtos: membros);
  if (resumo == null) return null;
  if (ehConcentrado(produto.nome) != resumo.concentrado) return null;

  final chaveProduto = chaveGenerica(produto.nome, marca: produto.marca);
  if (chaveProduto.isEmpty || chaveProduto != resumo.chave) return null;

  return SugestaoGrupo(
    produto: produto,
    grupo: grupo,
    forca: ForcaSugestao.forte,
    nota: 1,
    generica: true,
  );
}

bool _podeCompararComoProdutoFresco(
  Produto a,
  Produto b,
  String unidade,
) {
  if (unidade != 'kg') return false;
  if (a.embalagemQtd != null || b.embalagemQtd != null) return false;
  if ((a.embalagemUnidade ?? '').trim().isNotEmpty ||
      (b.embalagemUnidade ?? '').trim().isNotEmpty) {
    return false;
  }
  final nomeA = normalizar(a.nome).replaceAll(' ', '');
  final nomeB = normalizar(b.nome).replaceAll(' ', '');
  final embalagemNoNome = RegExp(r'\d+(kg|g|l|ml|un)\b');
  return !embalagemNoNome.hasMatch(nomeA) &&
      !embalagemNoNome.hasMatch(nomeB);
}

SugestaoGrupo? _comparar({
  required Produto produto,
  required String nomeProduto,
  required Grupo grupo,
  required String nomeGrupo,
  String? parteDoNome,
}) {
  final atributos = atributosDiferentes(nomeProduto, nomeGrupo);
  final normalProduto = normalizarNomeBase(nomeProduto);
  final normalGrupo = normalizarNomeBase(nomeGrupo);
  final semAtributosProduto = normalizarNomeBase(nomeProduto, removerAtributos: true);
  final semAtributosGrupo = normalizarNomeBase(nomeGrupo, removerAtributos: true);

  if (normalProduto == normalGrupo && atributos.isEmpty) {
    return SugestaoGrupo(
      produto: produto,
      grupo: grupo,
      forca: ForcaSugestao.forte,
      nota: 1,
      parteDoNome: parteDoNome,
    );
  }

  final nota = similaridadeNomes(semAtributosProduto, semAtributosGrupo);
  if (semAtributosProduto == semAtributosGrupo || nota >= 0.68) {
    return SugestaoGrupo(
      produto: produto,
      grupo: grupo,
      forca: ForcaSugestao.possivel,
      nota: nota,
      atributosDiferentes: atributos,
      parteDoNome: parteDoNome,
    );
  }
  return null;
}
