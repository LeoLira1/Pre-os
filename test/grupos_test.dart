import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/grupos.dart';
import 'package:precos_supermercado/modelos/modelos.dart';

Produto produto(
  int id,
  String nome, {
  String? marca,
  double? embalagemQtd,
  String? embalagemUnidade,
}) =>
    Produto(
      id: id,
      chave: '$id',
      nome: nome,
      marca: marca,
      embalagemQtd: embalagemQtd,
      embalagemUnidade: embalagemUnidade,
    );

Grupo grupo(int id, String nome, String unidade) =>
    Grupo(id: id, nome: nome, unidadeRef: unidade);

List<SugestaoGrupo> sugestoes({
  required List<Produto> produtos,
  required List<Grupo> grupos,
  required List<ProdutoGrupo> vinculos,
  required Map<int, String> unidades,
}) =>
    gerarSugestoesGrupos(
      produtos: produtos,
      grupos: grupos,
      vinculos: vinculos,
      rejeitadas: const [],
      unidadeDoProduto: (id) => unidades[id],
    );

void main() {
  test('divide X ou Y', () {
    expect(dividirAlternativas('Coxão Duro ou Lagarto'),
        ['Coxão Duro', 'Lagarto']);
  });

  test('propaga o complemento compartilhado', () {
    expect(
      dividirAlternativas('Pernil ou Paleta Suína com Pele e Osso'),
      ['Pernil Suíno com Pele e Osso', 'Paleta Suína com Pele e Osso'],
    );
  });

  test('normalizacao remove acentos e adjetivos descartaveis', () {
    expect(normalizarNomeBase('Melância Docinha Grande kg'), 'melancia');
  });

  test('Melancia Docinha sugere Melancia como forte', () {
    final itens = [produto(1, 'Melancia'), produto(2, 'Melancia Docinha')];
    final resultado = sugestoes(
      produtos: itens,
      grupos: [grupo(10, 'Melancia', 'kg'), grupo(20, 'Melancia Docinha', 'kg')],
      vinculos: const [
        ProdutoGrupo(produtoId: 1, grupoId: 10, origem: 'automatico'),
        ProdutoGrupo(produtoId: 2, grupoId: 20, origem: 'automatico'),
      ],
      unidades: {1: 'kg', 2: 'kg'},
    );
    expect(resultado, hasLength(1));
    expect(resultado.single.forca, ForcaSugestao.forte);
  });

  test('congelada e resfriada nao sao forte e destacam atributos', () {
    final itens = [
      produto(1, 'Coxa e Sobrecoxa Resfriada'),
      produto(2, 'Coxa e Sobrecoxa Congelada'),
    ];
    final resultado = sugestoes(
      produtos: itens,
      grupos: [
        grupo(10, itens[0].nome, 'kg'),
        grupo(20, itens[1].nome, 'kg'),
      ],
      vinculos: const [
        ProdutoGrupo(produtoId: 1, grupoId: 10, origem: 'automatico'),
        ProdutoGrupo(produtoId: 2, grupoId: 20, origem: 'automatico'),
      ],
      unidades: {1: 'kg', 2: 'kg'},
    );
    expect(resultado.single.forca, ForcaSugestao.possivel);
    expect(resultado.single.atributosDiferentes,
        containsAll(['congelada', 'resfriada']));
  });

  test('unidades de referencia diferentes nunca sao sugeridas', () {
    final itens = [produto(1, 'Melancia'), produto(2, 'Melancia')];
    final resultado = sugestoes(
      produtos: itens,
      grupos: [grupo(10, 'Melancia', 'kg'), grupo(20, 'Melancia', 'un')],
      vinculos: const [
        ProdutoGrupo(produtoId: 1, grupoId: 10, origem: 'automatico'),
        ProdutoGrupo(produtoId: 2, grupoId: 20, origem: 'automatico'),
      ],
      unidades: {1: 'kg', 2: 'un'},
    );
    expect(resultado, isEmpty);
  });

  test('produto com marca exige marca e embalagem iguais', () {
    final itens = [
      produto(1, 'Arroz Filé Tipo 1 5kg',
          marca: 'Filé', embalagemQtd: 5, embalagemUnidade: 'kg'),
      produto(2, 'Arroz File Tipo 1 5 kg',
          marca: 'Filé', embalagemQtd: 5, embalagemUnidade: 'kg'),
      produto(3, 'Arroz Filé Tipo 1 5kg',
          marca: 'Outra', embalagemQtd: 5, embalagemUnidade: 'kg'),
    ];
    final resultado = sugestoes(
      produtos: itens,
      grupos: [
        grupo(10, itens[0].nome, 'kg'),
        grupo(20, itens[1].nome, 'kg'),
        grupo(30, itens[2].nome, 'kg'),
      ],
      vinculos: const [
        ProdutoGrupo(produtoId: 1, grupoId: 10, origem: 'automatico'),
        ProdutoGrupo(produtoId: 2, grupoId: 20, origem: 'automatico'),
        ProdutoGrupo(produtoId: 3, grupoId: 30, origem: 'automatico'),
      ],
      unidades: {1: 'kg', 2: 'kg', 3: 'kg'},
    );
    expect(resultado.map((s) => s.produto.id), contains(2));
    expect(resultado.map((s) => s.produto.id), isNot(contains(3)));
  });

  test('arroz e acucar embalados sem marca nao sao sugeridos', () {
    final itens = [
      produto(1, 'Açúcar Cristal Ecoçúcar 5kg'),
      produto(2, 'Arroz Cristal Tipo 1 5kg'),
    ];
    final resultado = sugestoes(
      produtos: itens,
      grupos: [
        grupo(10, itens[0].nome, 'kg'),
        grupo(20, itens[1].nome, 'kg'),
      ],
      vinculos: const [
        ProdutoGrupo(produtoId: 1, grupoId: 10, origem: 'automatico'),
        ProdutoGrupo(produtoId: 2, grupoId: 20, origem: 'automatico'),
      ],
      unidades: {1: 'kg', 2: 'kg'},
    );
    expect(resultado, isEmpty);
  });

  test('separar vinculo nao altera os precos', () {
    final precos = <Preco>[
      const Preco(id: 1, produtoId: 2, lojaId: 1,
          data: '2026-09-11', preco: 9.99, tipo: 'oferta'),
    ];
    final antes = precos.map((p) => p.paraMapa()).toList();
    final vinculos = <ProdutoGrupo>[
      const ProdutoGrupo(produtoId: 2, grupoId: 10, origem: 'manual'),
    ]..removeWhere((v) => v.produtoId == 2 && v.grupoId == 10);
    expect(vinculos, isEmpty);
    expect(precos.map((p) => p.paraMapa()).toList(), antes);
  });
}
