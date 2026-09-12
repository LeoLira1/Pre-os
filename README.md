# Precos de Mercado

Aplicativo Android (Flutter) para acompanhar precos de supermercado e
identificar promocoes reais.

**Fase 1**: banco de dados, importacao de CSV e consulta do historico.
**Fase 2**: leitura dos precos direto das fotos do tabloide, com a API da
DeepSeek.
**Fase 3**: grupos de produto, juncao segura e **comparacao entre marcas**
("agua sanitaria e agua sanitaria"), com rota de compras.

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
| **Produtos** (inicial) | Busca por nome ou marca (ignora acentos e maiusculas), filtro por categoria e por loja, e **onde cada produto esta mais barato** sem precisar abrir. |
| **Produto** | "Mais barato hoje" com a loja, menor, maior, media e numero de registros; grafico de linha por loja (ou de barras comparando lojas, quando nao ha evolucao no tempo); historico completo com data, loja, preco, tipo e observacao. |
| **Rota de compras** | Voce marca os produtos da semana e o app diz, produto por produto, **em qual loja e de qual marca** sai mais barato por litro, quilo ou unidade, agrupado por loja. |
| **Juntar** | Sugestoes de juncao, separadas em "Comparar entre marcas" (grupo generico) e "Mesmo produto, nomes diferentes". Da para aceitar uma a uma ou todas de uma vez. |
| **Importar > Fotos** | Escolhe fotos do encarte (galeria ou camera), manda ler pela DeepSeek e mostra o andamento foto a foto. |
| **Revisao** | Tudo o que foi lido, agrupado por foto, com selos de "Novo produto", "Conferir" e "Ja registrado". Da para editar, excluir e trocar o produto vinculado antes de gravar. |
| **Importar > CSV** | Escolhe um arquivo `.csv`, mostra uma previa (novos, existentes, duplicados, linhas com erro) e so grava depois do "Confirmar importacao". |
| **Configuracao** | URL e token do Turso, chave da API DeepSeek, "Comparar entre marcas por padrao", raciocinio na extracao, precos da API, "Testar conexao", "Sincronizar" e "Limpar cache local". |

## Comparacao entre lojas

Na lista de produtos, cada card mostra onde o produto esta mais barato:

- O preco grande e o da **loja mais barata**.
- Com preco em uma loja so, o nome dela aparece embaixo do preco.
- Com mais de uma loja, vem uma linha por loja com o ultimo preco e o preco
  de referencia daquela loja, da mais barata para a mais cara. A primeira
  fica destacada em verde com o selo **"mais barato"**.
- A comparacao usa sempre o **preco de referencia** (por kg, L ou un); so
  quando ele nao existe e que entra o preco cheio. Assim um pacote de 5 kg
  nao parece caro so por custar mais na etiqueta.
- Se uma loja estiver com registro mais antigo que o das outras, a data
  aparece ao lado dela, para voce nao comparar oferta velha com preco de hoje.
- Os nomes saem curtos: "Supermercado Varejao" vira "Varejao".

Os chips no topo filtram por categoria e por loja, carregados do banco.

## Comparacao entre marcas (grupo generico)

Para muita coisa a marca nao muda nada: **agua sanitaria e agua sanitaria**.
Um grupo com `ignora_marca = 1` compara marcas e tamanhos de embalagem
diferentes entre si, desde que a **unidade de referencia seja a mesma**.

### Como o app sugere

Na tela **Juntar**, a secao "Comparar entre marcas" propoe transformar varios
grupos num grupo generico so:

```
Agua Sanitaria Qboa 2L
Agua Sanitaria Sol 2L    ->  grupo generico "Agua Sanitaria"
Agua Sanitaria Ype 2L
Agua Sanitaria Zupp 1L
```

O **nome generico** e o nome sem marca e sem embalagem. Duas travas nunca
saem:

- `unidade_ref` diferente **nunca** se mistura (por L com por kg, por
  exemplo);
- tipo de produto diferente **nunca** se mistura: a chave generica precisa
  ser exatamente igual, entao acucar nunca encontra arroz.

Cada sugestao vem marcada como **"Generica"** e pode ser aceita uma a uma ou
todas de uma vez. Recusar guarda a decisao, e ela nao volta na proxima
sincronizacao.

**Concentrado nunca entra sozinho no grupo do comum.** A palavra
"concentrado" fica no nome generico, entao "Amaciante Concentrado" e
"Amaciante" sao grupos diferentes. Os concentrados sao sugeridos entre si,
com o aviso de que o rendimento e outro.

Na tela do grupo, o interruptor **"Comparar entre marcas"** liga e desliga
`ignora_marca` a qualquer momento, e da para **renomear** o grupo generico.
Na **Configuracao**, "Comparar entre marcas por padrao" decide se os grupos
genericos aceitos na tela Juntar ja nascem ligados.

### Como o card aparece

No card de um grupo generico:

- O preco grande e o **menor preco de referencia** (por L, kg ou un), nao o
  menor preco de embalagem.
- Embaixo dele vem qual embalagem deu esse preco: `R$ 2,49/L` com
  `Zupp 1 L - R$ 2,49`.
- Uma linha por loja, ordenada pelo preco de referencia, com loja, marca,
  embalagem, preco e preco por unidade. A primeira leva o selo
  **"mais barato"**.
- Duas lojas com menos de **2%** de diferenca no preco de referencia levam as
  duas o selo **"empate"**: `R$ 2,49/L` e `R$ 2,50/L` nao sao precos
  diferentes na pratica.

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

## Leitura por foto (Fase 2)

Uma requisicao por foto, no maximo 3 ao mesmo tempo, com 120 s de limite.
Em erro 429 ou falha de rede o app tenta de novo ate 3 vezes, esperando
cada vez um pouco mais.

- Modelo `deepseek-flash`, o unico da DeepSeek que aceita imagem.
- A imagem vai em base64 com `detail: "original"`. Nunca `low`: isso
  reduziria a foto para 512x512 e apagaria os centavos em fonte pequena.
- Foto maior que ~1,7 milhao de pixels e reduzida antes de enviar, mantendo
  a proporcao. Foto de tabloide de WhatsApp (906x1600) vai sem mexer.
- As instrucoes ficam em [`assets/prompts/extracao.txt`](assets/prompts/extracao.txt)
  e vao sempre no comeco da mensagem: essa parte repetida entra no cache da
  DeepSeek e sai bem mais barata.
- O **preco de referencia e calculado pelo app**, nunca pelo modelo:
  g -> por kg, ml -> por L, kg/L/un/rolo -> divide pela quantidade.

### Nao pagar duas vezes pela mesma foto

Assim que cada foto volta, o resultado e gravado num rascunho no aparelho.
Se o app fechar no meio, ao abrir de novo ele oferece **"Continuar
importacao pendente"** e so envia as fotos que ainda faltam.

### Como o app evita produtos duplicados

O mesmo tabloide escreve o produto igual toda semana, mas o nome
padronizado pode variar. Por isso a busca segue esta ordem:

1. O texto do tabloide ja visto nesta loja (`produto_apelidos`).
2. A chave do produto (nome + marca + embalagem).
3. Candidatos com a mesma embalagem e marca, ranqueados por semelhanca de
   nome. As 3 melhores aparecem para voce escolher. Se so houver um muito
   parecido, o app vincula sozinho e avisa "Vinculado automaticamente".

Ao gravar, o texto do tabloide vira apelido, e na semana seguinte o vinculo
ja sai automatico.

### Custo

O app guarda os tokens de cada chamada (entrada, saida e cache) e estima o
custo em dolares. Os precos por milhao de tokens ficam editaveis na
Configuracao, junto com o interruptor "horario de pico dobra o preco"
(pico da DeepSeek: 01:00-04:00 e 06:00-10:00 UTC, de segunda a sexta).
O total gasto aparece na Configuracao, e o custo de cada importacao no
resumo final.

## Banco de dados

Tabelas criadas automaticamente: `lojas`, `produtos`, `produto_apelidos`,
`precos`, `importacoes`, `grupos`, `produto_grupos`, `sugestoes_rejeitadas` e
`sugestoes_genericas_rejeitadas`. O esquema completo esta em
[`lib/dados/esquema.dart`](lib/dados/esquema.dart).

A **chave** do produto e `nome + marca + embalagem_qtd + embalagem_unidade`,
em minusculas, sem acentos e sem espacos duplicados. E ela que evita cadastrar
o mesmo produto duas vezes.

### Migracao segura

O banco ja tem dados reais, entao nada e apagado nem recriado. Toda tabela
usa `CREATE TABLE IF NOT EXISTS`, e coluna nova (como `precos.importacao_id`,
`grupos.ignora_marca` e `grupos.nome_generico`) so recebe
`ALTER TABLE ADD COLUMN` depois de conferir com `PRAGMA table_info` que ela
ainda nao existe.

Em `grupos`, `ignora_marca INTEGER DEFAULT 0` nasce desligado: nenhum grupo
que ja existe muda de comportamento sozinho. `nome_generico TEXT` so e
preenchido quando o grupo vira generico.

## Baixar o APK

A cada push, o GitHub Actions compila o APK de release e publica na aba
**Releases**, em "APK mais recente".

**Pelo celular (mais facil):** abra a release
[`apk-mais-recente`](../../releases/tag/apk-mais-recente) e toque em
`precos-de-mercado.apk`. E o arquivo direto, sem zip e sem precisar estar
logado no GitHub. O link e sempre o mesmo e aponta sempre para a versao mais
nova.

**Pelo computador:** o mesmo APK tambem fica na aba **Actions**, na execucao
mais recente de **Build APK**, em **Artifacts** (ali vem dentro de um `.zip`).

Depois de baixar, o Android vai pedir para permitir a instalacao de
aplicativos de fora da Play Store. E normal, porque o APK nao passa pela loja.

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

- **Fase 4**: selos de promocao real e alertas de preco.
- **Fase 5**: leitura de QR code da NFC-e e outras lojas.
