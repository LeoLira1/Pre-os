import 'package:flutter_test/flutter_test.dart';
import 'package:precos_supermercado/core/generico.dart';
import 'package:precos_supermercado/core/grupos.dart';
import 'package:precos_supermercado/modelos/modelos.dart';

// Dados reais: a mesma agua sanitaria em quatro marcas e duas embalagens.
const _qboa = Produto(
  id: 1,
  chave: 'agua sanitaria qboa 2 l',
  nome: 'Água Sanitária Qboa 2L',
  marca: 'Qboa',
  categoria: 'Limpeza',
  embalagemQtd: 2,
  embalagemUnidade: 'L',
);
const _sol = Produto(
  id: 2,
  chave: 'agua sanitaria sol 2 l',
  nome: 'Água Sanitária Sol 2L',
  marca: 'Sol',
  categoria: 'Limpeza',
  embalagemQtd: 2,
  embalagemUnidade: 'L',
);
const _ype = Produto(
  id: 3,
  chave: 'agua sanitaria ype 2 l',
  nome: 'Água Sanitária Ypê 2L',
  marca: 'Ypê',
  categoria: 'Limpeza',
  embalagemQtd: 2,
  embalagemUnidade: 'L',
);
const _zupp = Produto(
  id: 4,
  chave: 'agua sanitaria zupp 1 l',
  nome: 'Água Sanitária Zupp 1L',
  marca: 'Zupp',
  categoria: 'Limpeza',
  embalagemQtd: 1,
  embalagemUnidade: 'L',
);

Grupo _grupo(
  int id,
  String nome, {
  String unidade = 'L',
  bool ignoraMarca = false,
  String? nomeGenerico,
}) =>
    Grupo(
      id: id,
      nome: nome,
      categoria: 'Limpeza',
      unidadeRef: unidade,
      ignoraMarca: ignoraMarca,
      nomeGenerico: nomeGenerico,
    );

List<SugestaoGenerica> _sugerir(Map<Grupo, List<Produto>> mapa) {
  final porId = {for (final e in mapa.entries) e.key.id: e.value};
  return gerarSugestoesGenericas(
    grupos: mapa.keys.toList(),
    produtosDoGrupo: (id) => porId[id] ?? const <Produto>[],
  );
}

/// Um grupo por marca, como o app cria antes da junção genérica.
Map<Grupo, List<Produto>> _quatroAguasSanitarias() => {
      _grupo(10, _qboa.nome): [_qboa],
      _grupo(20, _sol.nome): [_sol],
      _grupo(30, _ype.nome): [_ype],
      _grupo(40, _zupp.nome): [_zupp],
    };

void main() {
  group('nome genérico', () {
    test('tira a marca e a embalagem', () {
      expect(
        nomeSemMarcaEEmbalagem(_qboa.nome, marca: _qboa.marca),
        'Água Sanitária',
      );
      expect(
        nomeSemMarcaEEmbalagem(_zupp.nome, marca: _zupp.marca),
        'Água Sanitária',
      );
    });

    test('aceita a embalagem separada do número', () {
      expect(
        nomeSemMarcaEEmbalagem('Detergente Ypê 500 ml', marca: 'Ypê'),
        'Detergente',
      );
    });

    test('as quatro marcas dão a mesma chave', () {
      final chaves = {
        for (final p in [_qboa, _sol, _ype, _zupp])
          chaveGenerica(p.nome, marca: p.marca),
      };
      expect(chaves, {'agua sanitaria'});
    });

    test('açúcar e arroz nunca dão a mesma chave', () {
      expect(
        chaveGenerica('Açúcar União 5kg', marca: 'União'),
        isNot(chaveGenerica('Arroz Tio João 5kg', marca: 'Tio João')),
      );
    });

    test('concentrado continua no nome, para não virar o comum', () {
      expect(
        nomeSemMarcaEEmbalagem('Amaciante Concentrado Downy 500ml',
            marca: 'Downy'),
        'Amaciante Concentrado',
      );
      expect(ehConcentrado('Amaciante Concentrado Downy 500ml'), isTrue);
      expect(ehConcentrado('Amaciante Downy 2L'), isFalse);
    });

    test('nome que é só marca e embalagem não some', () {
      expect(nomeSemMarcaEEmbalagem('Qboa 2L', marca: 'Qboa'), 'Qboa 2L');
    });
  });

  group('sugestões genéricas', () {
    test('junta as quatro marcas de água sanitária num grupo só', () {
      final sugestoes = _sugerir(_quatroAguasSanitarias());

      expect(sugestoes, hasLength(1));
      final sugestao = sugestoes.single;
      expect(sugestao.nomeGenerico, 'Água Sanitária');
      expect(sugestao.unidadeRef, 'l');
      expect(sugestao.concentrado, isFalse);
      expect(sugestao.idsParaJuntar, [10, 20, 30, 40]);
      expect(sugestao.destino.id, 10);
    });

    test('nenhum grupo genérico mistura unidade_ref diferente', () {
      final mapa = _quatroAguasSanitarias();
      // Uma loja anunciou a mesma água sanitária por unidade, não por litro.
      mapa[_grupo(50, 'Água Sanitária Brilhante', unidade: 'un')] = [
        const Produto(
          id: 5,
          chave: 'agua sanitaria brilhante',
          nome: 'Água Sanitária Brilhante',
          marca: 'Brilhante',
        ),
      ];
      mapa[_grupo(60, 'Água Sanitária Limpol', unidade: 'un')] = [
        const Produto(
          id: 6,
          chave: 'agua sanitaria limpol',
          nome: 'Água Sanitária Limpol',
          marca: 'Limpol',
        ),
      ];

      final sugestoes = _sugerir(mapa);
      expect(sugestoes, hasLength(2));
      for (final sugestao in sugestoes) {
        final unidades = sugestao.grupos
            .map((g) => unidadeCanonica(g.unidadeRef))
            .toSet();
        expect(unidades, hasLength(1));
        expect(unidades.single, sugestao.unidadeRef);
      }
      expect(
        sugestoes.firstWhere((s) => s.unidadeRef == 'l').idsParaJuntar,
        [10, 20, 30, 40],
      );
      expect(
        sugestoes.firstWhere((s) => s.unidadeRef == 'un').idsParaJuntar,
        [50, 60],
      );
    });

    test('nunca junta tipos de produto diferentes', () {
      final sugestoes = _sugerir({
        _grupo(10, 'Açúcar União 5kg', unidade: 'kg'): [
          const Produto(
            id: 1,
            chave: 'acucar uniao 5 kg',
            nome: 'Açúcar União 5kg',
            marca: 'União',
            embalagemQtd: 5,
            embalagemUnidade: 'kg',
          ),
        ],
        _grupo(20, 'Arroz Tio João 5kg', unidade: 'kg'): [
          const Produto(
            id: 2,
            chave: 'arroz tio joao 5 kg',
            nome: 'Arroz Tio João 5kg',
            marca: 'Tio João',
            embalagemQtd: 5,
            embalagemUnidade: 'kg',
          ),
        ],
      });
      expect(sugestoes, isEmpty);
    });

    test('concentrado não entra automaticamente no grupo do comum', () {
      final sugestoes = _sugerir({
        _grupo(10, 'Amaciante Ypê 2L'): [
          const Produto(
            id: 1,
            chave: 'amaciante ype 2 l',
            nome: 'Amaciante Ypê 2L',
            marca: 'Ypê',
            embalagemQtd: 2,
            embalagemUnidade: 'L',
          ),
        ],
        _grupo(20, 'Amaciante Comfort 2L'): [
          const Produto(
            id: 2,
            chave: 'amaciante comfort 2 l',
            nome: 'Amaciante Comfort 2L',
            marca: 'Comfort',
            embalagemQtd: 2,
            embalagemUnidade: 'L',
          ),
        ],
        _grupo(30, 'Amaciante Concentrado Downy 500ml'): [
          const Produto(
            id: 3,
            chave: 'amaciante concentrado downy 500 ml',
            nome: 'Amaciante Concentrado Downy 500ml',
            marca: 'Downy',
            embalagemQtd: 500,
            embalagemUnidade: 'ml',
          ),
        ],
      });

      expect(sugestoes, hasLength(1));
      expect(sugestoes.single.idsParaJuntar, [10, 20]);
      expect(sugestoes.single.concentrado, isFalse);
    });

    test('concentrados são sugeridos entre si, com o aviso de rendimento', () {
      final sugestoes = _sugerir({
        _grupo(10, 'Amaciante Concentrado Downy 500ml'): [
          const Produto(
            id: 1,
            chave: 'amaciante concentrado downy 500 ml',
            nome: 'Amaciante Concentrado Downy 500ml',
            marca: 'Downy',
            embalagemQtd: 500,
            embalagemUnidade: 'ml',
          ),
        ],
        _grupo(20, 'Amaciante Concentrado Ypê 500ml'): [
          const Produto(
            id: 2,
            chave: 'amaciante concentrado ype 500 ml',
            nome: 'Amaciante Concentrado Ypê 500ml',
            marca: 'Ypê',
            embalagemQtd: 500,
            embalagemUnidade: 'ml',
          ),
        ],
      });

      expect(sugestoes, hasLength(1));
      expect(sugestoes.single.concentrado, isTrue);
      expect(sugestoes.single.nomeGenerico, 'Amaciante Concentrado');
    });

    test('sugestão recusada não volta', () {
      final mapa = _quatroAguasSanitarias();
      final porId = {for (final e in mapa.entries) e.key.id: e.value};
      final antes = _sugerir(mapa);

      final depois = gerarSugestoesGenericas(
        grupos: mapa.keys.toList(),
        produtosDoGrupo: (id) => porId[id] ?? const <Produto>[],
        rejeitadas: {antes.single.identidade},
      );
      expect(depois, isEmpty);
    });

    test('grupo sem produto vinculado fica de fora', () {
      final sugestoes = _sugerir({
        _grupo(10, _qboa.nome): [_qboa],
        _grupo(20, _sol.nome): const <Produto>[],
      });
      expect(sugestoes, isEmpty);
    });
  });

  group('grupo genérico aceita marcas e embalagens diferentes', () {
    List<SugestaoGrupo> sugerir({
      required List<Produto> produtos,
      required List<Grupo> grupos,
      required List<ProdutoGrupo> vinculos,
    }) =>
        gerarSugestoesGrupos(
          produtos: produtos,
          grupos: grupos,
          vinculos: vinculos,
          rejeitadas: const [],
          unidadeDoProduto: (_) => 'L',
        );

    test('Zupp 1L entra no grupo genérico de Água Sanitária', () {
      final resultado = sugerir(
        produtos: [_qboa, _zupp],
        grupos: [
          _grupo(10, 'Água Sanitária',
              ignoraMarca: true, nomeGenerico: 'Água Sanitária'),
          _grupo(40, _zupp.nome),
        ],
        vinculos: const [
          ProdutoGrupo(produtoId: 1, grupoId: 10, origem: 'manual'),
          ProdutoGrupo(produtoId: 4, grupoId: 40, origem: 'automatico'),
        ],
      );

      final paraOGenerico = resultado.where((s) => s.grupo.id == 10).toList();
      expect(paraOGenerico, hasLength(1));
      expect(paraOGenerico.single.produto.id, _zupp.id);
      expect(paraOGenerico.single.generica, isTrue);
      expect(paraOGenerico.single.forca, ForcaSugestao.forte);
    });

    test('sabão em pó não entra no grupo genérico da água sanitária', () {
      const sabao = Produto(
        id: 9,
        chave: 'sabao em po omo 2 l',
        nome: 'Sabão Líquido Omo 2L',
        marca: 'Omo',
        embalagemQtd: 2,
        embalagemUnidade: 'L',
      );
      final resultado = sugerir(
        produtos: [_qboa, sabao],
        grupos: [
          _grupo(10, 'Água Sanitária',
              ignoraMarca: true, nomeGenerico: 'Água Sanitária'),
          _grupo(90, sabao.nome),
        ],
        vinculos: const [
          ProdutoGrupo(produtoId: 1, grupoId: 10, origem: 'manual'),
          ProdutoGrupo(produtoId: 9, grupoId: 90, origem: 'automatico'),
        ],
      );
      expect(resultado.where((s) => s.grupo.id == 10), isEmpty);
    });

    test('concentrado não é sugerido para o grupo genérico do comum', () {
      const concentrado = Produto(
        id: 8,
        chave: 'amaciante concentrado downy 500 ml',
        nome: 'Amaciante Concentrado Downy 500ml',
        marca: 'Downy',
        embalagemQtd: 500,
        embalagemUnidade: 'ml',
      );
      const comum = Produto(
        id: 7,
        chave: 'amaciante ype 2 l',
        nome: 'Amaciante Ypê 2L',
        marca: 'Ypê',
        embalagemQtd: 2,
        embalagemUnidade: 'L',
      );
      final resultado = sugerir(
        produtos: [comum, concentrado],
        grupos: [
          _grupo(10, 'Amaciante',
              ignoraMarca: true, nomeGenerico: 'Amaciante'),
          _grupo(80, concentrado.nome),
        ],
        vinculos: const [
          ProdutoGrupo(produtoId: 7, grupoId: 10, origem: 'manual'),
          ProdutoGrupo(produtoId: 8, grupoId: 80, origem: 'automatico'),
        ],
      );
      expect(resultado.where((s) => s.grupo.id == 10), isEmpty);
    });
  });
}
