import 'texto.dart';

/// Quanto dois nomes de produto se parecem, de 0 (nada) a 1 (igual).
///
/// Combina duas medidas simples e baratas:
/// - quantas palavras os dois tem em comum (Jaccard);
/// - quantos pares de letras seguidas coincidem (bigramas de Dice).
///
/// Juntas elas seguram bem os casos reais: "Arroz Tio Joao 5kg" continua
/// parecido com "Arroz Branco Tio Joao Tipo 1 5kg", e erros de digitacao
/// nao derrubam a nota.
double similaridadeNomes(String? a, String? b) {
  final na = normalizar(a);
  final nb = normalizar(b);
  if (na.isEmpty || nb.isEmpty) return 0;
  if (na == nb) return 1;
  // "5 kg" e "5kg" sao o mesmo nome escrito de dois jeitos.
  if (na.replaceAll(' ', '') == nb.replaceAll(' ', '')) return 1;

  final porPalavra = _jaccardPalavras(na, nb);
  final porLetra = _diceBigramas(na, nb);
  return (porPalavra * 0.6) + (porLetra * 0.4);
}

double _jaccardPalavras(String a, String b) {
  final pa = a.split(' ').where((p) => p.isNotEmpty).toSet();
  final pb = b.split(' ').where((p) => p.isNotEmpty).toSet();
  if (pa.isEmpty || pb.isEmpty) return 0;
  final comuns = pa.intersection(pb).length;
  final total = pa.union(pb).length;
  return comuns / total;
}

double _diceBigramas(String a, String b) {
  final ba = _bigramas(a);
  final bb = _bigramas(b);
  if (ba.isEmpty || bb.isEmpty) return a == b ? 1 : 0;

  // Conta as repeticoes para nao premiar demais textos com letras repetidas.
  final restantes = <String, int>{};
  for (final g in bb) {
    restantes[g] = (restantes[g] ?? 0) + 1;
  }
  var comuns = 0;
  for (final g in ba) {
    final quantos = restantes[g] ?? 0;
    if (quantos > 0) {
      comuns++;
      restantes[g] = quantos - 1;
    }
  }
  return (2 * comuns) / (ba.length + bb.length);
}

List<String> _bigramas(String texto) {
  final limpo = texto.replaceAll(' ', '');
  if (limpo.length < 2) return limpo.isEmpty ? const [] : [limpo];
  return [
    for (var i = 0; i < limpo.length - 1; i++) limpo.substring(i, i + 2),
  ];
}

/// Um produto do banco que pode ser o mesmo que o item da foto.
class Candidato<T> {
  const Candidato({required this.item, required this.nota});

  final T item;
  final double nota;
}

/// Ordena os candidatos do mais parecido para o menos parecido.
///
/// [nomeDe] diz como tirar o nome de cada candidato.
List<Candidato<T>> ranquearCandidatos<T>({
  required String nomeBuscado,
  required Iterable<T> candidatos,
  required String? Function(T) nomeDe,
  int limite = 3,
}) {
  final notas = <Candidato<T>>[
    for (final c in candidatos)
      Candidato<T>(item: c, nota: similaridadeNomes(nomeBuscado, nomeDe(c))),
  ]..sort((a, b) => b.nota.compareTo(a.nota));
  return notas.take(limite).toList();
}

/// Acima disto o app vincula sozinho, sem perguntar.
const double limiarVinculoAutomatico = 0.85;
