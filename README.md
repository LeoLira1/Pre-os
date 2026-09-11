# Precos de Mercado

Aplicativo Android (Flutter) para acompanhar precos de supermercado e
identificar promocoes reais.

Esta e a **Fase 1**: banco de dados, importacao de CSV e consulta do historico
de precos.

## Como funciona

- Flutter nativo, **sem backend proprio**. O aplicativo fala direto com o banco
  **Turso** (libSQL) pelo pacote `libsql_dart`.
- A URL e o token do banco sao digitados na tela **Configuracao** e ficam
  salvos **somente no aparelho**. Nunca aparecem no codigo nem neste
  repositorio.
- Uma copia dos dados fica guardada num arquivo dentro do aplicativo
  (**cache local**), entao o app abre e consulta mesmo **sem internet**.
- Na primeira conexao o aplicativo **cria as tabelas sozinho**, se ainda nao
  existirem.

## As telas

| Tela | O que faz |
| --- | --- |
| **Produtos** (inicial) | Busca por nome ou marca (ignora acentos e maiusculas), filtro por categoria, ultimo preco, preco de referencia e data do ultimo registro. |
| **Produto** | Ultimo preco, menor, maior, media e numero de registros; grafico do preco ao longo do tempo; historico completo com data, loja, preco, tipo e observacao. |
| **Importar** | Escolhe um arquivo `.csv`, mostra uma previa (novos, existentes, duplicados, linhas com erro) e so grava depois do "Confirmar importacao". |
| **Configuracao** | URL e token do Turso, chave da API DeepSeek (para a Fase 2), "Testar conexao", "Sincronizar" e "Limpar cache local". |

## Formato do arquivo CSV

Arquivo `.csv` em **UTF-8**, separado por **virgula**, decimal com **ponto**
(`3.99`). Campos podem vir entre aspas com virgulas dentro. A primeira linha
precisa ser exatamente:

```
data_oferta,loja,categoria,produto,marca,embalagem_qtd,embalagem_unidade,unidade_venda,preco,preco_ref,unidade_ref,ean,observacao
```

Regras da importacao:

- Cada linha vira uma loja (criada se nao existir), um produto (encontrado pela
  chave ou criado) e um registro em `precos` com `tipo='oferta'` e
  `fonte='csv'`.
- Se a `observacao` tiver algo como **"Limite 3 un"**, o campo
  `limite_por_cliente` e preenchido com `3` automaticamente.
- Campos vazios viram `NULL`.
- Tudo e gravado numa unica transacao, nao uma requisicao por linha.
- Importar o mesmo arquivo duas vezes **nao duplica** registros, por causa do
  `UNIQUE(produto_id, loja_id, data, tipo)`.

Ha um arquivo de exemplo em [`exemplos/ofertas_exemplo.csv`](exemplos/ofertas_exemplo.csv).

## Banco de dados

Tabelas criadas automaticamente: `lojas`, `produtos`, `produto_apelidos`
(ja criada, usada na Fase 2) e `precos`. O esquema completo esta em
[`lib/dados/esquema.dart`](lib/dados/esquema.dart).

A **chave** do produto e `nome + marca + embalagem_qtd + embalagem_unidade`,
em minusculas, sem acentos e sem espacos duplicados. E ela que evita cadastrar
o mesmo produto duas vezes.

## Baixar o APK

A cada push, o GitHub Actions compila o APK de release e deixa o arquivo para
download:

1. Abra a aba **Actions** do repositorio.
2. Clique na execucao mais recente de **Build APK**.
3. Em **Artifacts**, baixe `precos-supermercado-apk`.
4. Descompacte o `.zip` no celular e instale o `app-release.apk`.

O APK e compilado so para celular (ARM), o que deixa o arquivo em torno de
50 MB em vez de 78 MB. Ele **nao roda em emulador x86_64**.

## Rodar a partir do codigo

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Proximas fases (ainda nao implementadas)

- **Fase 2**: extrair precos de foto de encarte com a DeepSeek (a chave da API
  ja e guardada na tela Configuracao).
- **Fase 3**: selos de promocao real e lista de compras com alertas.
- **Fase 4**: leitura de QR code da NFC-e e outras lojas.
