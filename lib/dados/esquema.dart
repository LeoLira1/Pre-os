/// Comandos que criam as tabelas caso ainda nao existam.
///
/// Rodam na primeira conexao com o banco. Nenhum deles apaga dados.
const List<String> comandosEsquema = <String>[
  '''
CREATE TABLE IF NOT EXISTS lojas (
  id INTEGER PRIMARY KEY,
  nome TEXT UNIQUE NOT NULL
)''',
  '''
CREATE TABLE IF NOT EXISTS produtos (
  id INTEGER PRIMARY KEY,
  chave TEXT UNIQUE NOT NULL,
  nome TEXT NOT NULL,
  marca TEXT,
  categoria TEXT,
  embalagem_qtd REAL,
  embalagem_unidade TEXT,
  unidade_venda TEXT,
  ean TEXT,
  criado_em TEXT
)''',
  '''
CREATE TABLE IF NOT EXISTS produto_apelidos (
  id INTEGER PRIMARY KEY,
  produto_id INTEGER NOT NULL REFERENCES produtos(id),
  loja_id INTEGER REFERENCES lojas(id),
  texto_original TEXT NOT NULL
)''',
  '''
CREATE TABLE IF NOT EXISTS precos (
  id INTEGER PRIMARY KEY,
  produto_id INTEGER NOT NULL REFERENCES produtos(id),
  loja_id INTEGER NOT NULL REFERENCES lojas(id),
  data TEXT NOT NULL,
  preco REAL NOT NULL,
  preco_ref REAL,
  unidade_ref TEXT,
  embalagem_qtd REAL,
  embalagem_unidade TEXT,
  tipo TEXT NOT NULL,
  limite_por_cliente INTEGER,
  observacao TEXT,
  fonte TEXT,
  criado_em TEXT,
  UNIQUE(produto_id, loja_id, data, tipo)
)''',
  '''
CREATE TABLE IF NOT EXISTS importacoes (
  id INTEGER PRIMARY KEY,
  criado_em TEXT,
  loja_id INTEGER,
  data_oferta TEXT,
  tipo TEXT,
  qtd_fotos INTEGER,
  qtd_itens_salvos INTEGER,
  tokens_entrada INTEGER,
  tokens_saida INTEGER,
  tokens_cache INTEGER,
  custo_estimado_usd REAL
)''',
  'CREATE INDEX IF NOT EXISTS idx_precos_produto ON precos(produto_id)',
  'CREATE INDEX IF NOT EXISTS idx_precos_data ON precos(data)',
  'CREATE INDEX IF NOT EXISTS idx_apelidos_produto ON produto_apelidos(produto_id)',
  'CREATE INDEX IF NOT EXISTS idx_apelidos_texto ON produto_apelidos(texto_original)',
];

/// Colunas acrescentadas depois da Fase 1.
///
/// Cada uma so e criada se ainda nao existir na tabela. Nenhuma tabela e
/// apagada ou recriada: os dados que ja estao no banco continuam intactos.
const List<ColunaNova> colunasNovas = <ColunaNova>[
  ColunaNova(tabela: 'precos', coluna: 'importacao_id', tipo: 'INTEGER'),
];

/// Uma coluna que pode faltar em bancos criados por uma versao anterior.
class ColunaNova {
  const ColunaNova({
    required this.tabela,
    required this.coluna,
    required this.tipo,
  });

  final String tabela;
  final String coluna;
  final String tipo;

  String get comando => 'ALTER TABLE $tabela ADD COLUMN $coluna $tipo';
}
