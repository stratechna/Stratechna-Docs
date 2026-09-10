# Stratechna Docs

Paperless-ngx com a marca Stratechna.

    ghcr.io/stratechna/stratechna-docs:3.1      ← o que os clientes usam
    ghcr.io/stratechna/stratechna-docs:3.1.3    ← versão exacta
    ghcr.io/stratechna/stratechna-docs:latest   ← compatibilidade

`stratechna-vault` é o nome antigo, ainda publicado em paralelo.

## Como a marca é aplicada — e porque sobrevive às actualizações

1. **Versão fixa.** `ARG PAPERLESS_VERSION` no `Dockerfile`. Nada muda sem alguém mudar essa linha.
2. **Só ficheiros próprios.** Logos, favicons e CSS em `branding/ficheiros/`, copiados para
   `/static/custom/`. Nenhum ficheiro de código ou template do upstream é substituído por inteiro.
3. **Trocas de texto por padrão, com mínimo.** `branding/aplicar.py` troca o nome e os links do
   upstream no frontend, nos templates e nas traduções. Cada troca declara quantas ocorrências
   espera; se o upstream mudar e o padrão desaparecer, **o build falha** — nunca se publica uma
   imagem sem marca.
4. **Teste antes de publicar.** `branding/verificar.sh` arranca a imagem, abre o login, as
   páginas de conta, a aplicação com sessão iniciada e o admin, em português e inglês, e falha se
   o nome do upstream estiver visível. O workflow só publica se passar.
5. **O autoupdate segue a tag `3.1`**, que só avança com imagens que passaram o teste.

## Actualizar o Paperless

O workflow `upstream.yml` abre um issue quando sai versão nova. Para actualizar, mudar
`PAPERLESS_VERSION` e fazer push. Se o build ou a verificação falharem, ajustar os padrões no
`aplicar.py`.

Testar localmente (precisa de Docker):

    docker build -t docs:teste .
    bash branding/verificar.sh docs:teste

## Nos clientes (CCX13)

Os compose em `/opt/stratechna/vault/clientes/*/` usam `stratechna-docs:3.1`, sem ficheiros
montados por cima da imagem. O `/usr/local/bin/stratechna_autoupdate.sh` faz pull ao domingo.
