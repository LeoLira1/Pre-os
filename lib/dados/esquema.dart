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
  'CREATE INDEX IF NOT EXISTS idx_precos_produto ON precos(produto_id)',
  'CREATE INDEX IF NOT EXISTS idx_precos_data ON precos(data)',
  'CREATE INDEX IF NOT EXISTS idx_apelidos_produto ON produto_apelidos(produto_id)',
];
