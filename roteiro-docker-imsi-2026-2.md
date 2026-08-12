# Roteiro: clonar e criar a imagem do IMSI 2026

Projeto: [emellop-senai/imsi-2026](https://github.com/emellop-senai/imsi-2026).

## Objetivo

O Dockerfile irá:

1. instalar as dependências do frontend;
2. executar o build do Vite;
3. instalar as dependências do backend;
4. obter o servidor Caddy a partir de sua imagem oficial;
5. instalar o Supervisor na imagem final;
6. executar o frontend e o backend no mesmo contêiner.

O frontend continuará acessando exatamente o endereço existente no código:

```text
http://localhost:3000/frutas
```

Por isso, o contêiner publicará duas portas:

- `8080`: página do frontend;
- `3000`: API do backend.

## 1. Clonar o projeto

```bash
git clone https://github.com/emellop-senai/imsi-2026.git
```

Entrar na pasta:

```bash
cd imsi-2026
```

Conferir os arquivos:

```bash
ls
```

A estrutura principal deve ser semelhante a:

```text
imsi-2026/
├── backend/
├── frontend/
├── README.md
└── Dockerfile-referencia-pt-BR.md
```

## 2. Criar apenas o Dockerfile

Na raiz do projeto, crie um arquivo chamado exatamente `Dockerfile`, sem extensão.

Depois, adicione o seguinte conteúdo:

```dockerfile
# syntax=docker/dockerfile:1

# Estágio 1: build do frontend React/Vite
FROM node:24-alpine AS frontend-build

WORKDIR /build/frontend

COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build

# Estágio 2: dependências de produção do backend
FROM node:24-alpine AS backend-dependencies

WORKDIR /build/backend

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev

# Estágio 3: obter o binário oficial do Caddy
FROM caddy:2-alpine AS caddy-binary

# Estágio 4: imagem final
FROM node:24-alpine AS runtime

ENV NODE_ENV=production

RUN apk add --no-cache supervisor ca-certificates

COPY --from=caddy-binary /usr/bin/caddy /usr/bin/caddy

WORKDIR /app

COPY backend/package.json backend/package-lock.json ./backend/
COPY backend/src ./backend/src

COPY --from=backend-dependencies \
    /build/backend/node_modules \
    ./backend/node_modules

COPY --from=frontend-build \
    /build/frontend/dist \
    ./frontend/dist

# Configuração do Caddy criada dentro da própria imagem
RUN <<'EOF'
mkdir -p /etc/caddy
cat > /etc/caddy/Caddyfile <<'CADDYFILE'
:8080 {
    root * /app/frontend/dist
    encode zstd gzip
    try_files {path} /index.html
    file_server
}
CADDYFILE
EOF

# Supervisor mantém o backend e o Caddy em execução
RUN <<'EOF'
cat > /etc/supervisord.conf <<'SUPERVISOR'
[supervisord]
nodaemon=true
user=root
logfile=/dev/null
logfile_maxbytes=0
pidfile=/tmp/supervisord.pid

[program:backend]
command=node /app/backend/src/main.js
directory=/app/backend
user=node
autostart=true
autorestart=true
startretries=30
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0

[program:caddy]
command=/usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
directory=/app
user=node
autostart=true
autorestart=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
SUPERVISOR
EOF

EXPOSE 8080
EXPOSE 3000

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=15s \
    --retries=3 \
    CMD node -e "Promise.all([fetch('http://127.0.0.1:8080/'), fetch('http://127.0.0.1:3000/')]).then(responses => process.exit(responses.every(response => response.ok) ? 0 : 1)).catch(() => process.exit(1))"

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
```

Nenhuma configuração do Caddy ou do Supervisor precisa ser criada fora do Dockerfile. Esses arquivos são gerados dentro da imagem durante o build.

## 3. Entender os quatro estágios

### Estágio `frontend-build`

```dockerfile
FROM node:24-alpine AS frontend-build
```

Esse estágio instala as dependências do Vite e executa:

```bash
npm run build
```

O resultado fica temporariamente em `/build/frontend/dist`.

### Estágio `backend-dependencies`

```dockerfile
FROM node:24-alpine AS backend-dependencies
```

Esse estágio executa:

```bash
npm ci --omit=dev
```

Somente as dependências necessárias para executar o backend são instaladas.

### Estágio `caddy-binary`

```dockerfile
FROM caddy:2-alpine AS caddy-binary
```

Esse estágio utiliza a imagem oficial do Caddy. O binário `/usr/bin/caddy` é copiado para a imagem final, evitando instalar uma versão mantida por outro repositório de pacotes.

### Estágio `runtime`

O estágio final recebe:

- o código original do backend;
- as dependências de produção do backend;
- o frontend já compilado;
- Caddy para servir o frontend;
- Supervisor para manter Caddy e Node.js em execução.

O código-fonte original não é reescrito. Ele é apenas copiado para a imagem.

## 4. Construir a imagem

Execute na raiz do projeto:

```bash
docker build -t imsi-2026 .
```
O -t `imsi-2026` define o nome da imagem.

O ponto final significa que a pasta atual será usada como contexto do build.

A tag de versao vai ficar imsi-2026:latest, mas você pode especificar uma versão específica com `imsi-2026:1.0`.

Para visualizar todas as etapas:

```bash
docker build --progress=plain -t imsi-2026 .
```

Conferir a imagem:

```bash
docker image ls imsi-2026
```

## 5. Preparar o PostgreSQL

O backend precisa acessar um PostgreSQL. Ele pode estar:

- instalado na própria máquina;
- instalado em outro servidor;
- executando em outro contêiner.

O banco não deve ser iniciado dentro da mesma imagem da aplicação.

## Alternativa rápida: PostgreSQL em outro contêiner

Ao final, teremos a seguinte organização:

```text
Rede Docker: imsi-network
├── imsi-db           → contêiner do PostgreSQL
└── imsi-2026         → contêiner da aplicação (adicionado posteriormente ou antes) 

Volume Docker: imsi-postgres-data
└── armazena permanentemente os dados do PostgreSQL
```

## 1. Criar uma rede Docker

```bash
docker network create imsi-network
```

### O que esse comando faz?

Esse comando cria uma rede Docker personalizada chamada `imsi-network`.

| Parte | Explicação |
|---|---|
| `docker` | Executa o Docker pela linha de comando. |
| `network` | Indica que trabalharemos com redes Docker. |
| `create` | Solicita a criação de uma nova rede. |
| `imsi-network` | Define o nome da rede criada. |

### Por que criar uma rede?

A rede permite que diferentes contêineres se comuniquem de maneira isolada. Por exemplo, o contêiner da aplicação poderá acessar o PostgreSQL usando o nome do contêiner do banco:

```env
DB_HOST=imsi-db
DB_PORT=5432
```

Nesse cenário, não se deve usar `localhost` como endereço do banco dentro do contêiner da aplicação. Dentro de um contêiner, `localhost` aponta para o próprio contêiner, não para outro contêiner.

Quando ambos estiverem conectados à mesma rede, a comunicação será:

```text
Aplicação → imsi-db:5432 → PostgreSQL
```

### Como verificar a rede criada?

Listar as redes disponíveis:

```bash
docker network ls
```

Exibir os detalhes da rede:

```bash
docker network inspect imsi-network
```

---

## 2. Criar um volume Docker

```bash
docker volume create imsi-postgres-data
```

### O que esse comando faz?

Esse comando cria um volume chamado `imsi-postgres-data`.

| Parte | Explicação |
|---|---|
| `docker` | Executa o Docker pela linha de comando. |
| `volume` | Indica que trabalharemos com volumes. |
| `create` | Solicita a criação de um novo volume. |
| `imsi-postgres-data` | Define o nome do volume. |

### O que é um volume?

Um volume é uma área de armazenamento administrada pelo Docker. Ele fica separado do sistema de arquivos interno do contêiner.

Sem um volume, os dados gravados somente dentro do contêiner podem ser perdidos quando o contêiner for removido. Com um volume, é possível remover e recriar o contêiner sem apagar os dados do banco.

```text
Contêiner PostgreSQL
        │
        │ grava e lê dados
        ▼
Volume imsi-postgres-data
        │
        └── continua existindo se o contêiner for removido
```

### Como verificar o volume?

Listar os volumes disponíveis:

```bash
docker volume ls
```

Exibir os detalhes do volume:

```bash
docker volume inspect imsi-postgres-data
```

> Remover o contêiner não remove automaticamente esse volume nomeado. Para apagar o volume e todos os dados armazenados nele, seria necessário executar explicitamente `docker volume rm imsi-postgres-data`.

---

## 3. Iniciar o PostgreSQL

```bash
docker run -d --name imsi-db --network imsi-network -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=senai -e POSTGRES_DB=quitanda -v imsi-postgres-data:/var/lib/postgresql postgres:18-alpine
```

A barra invertida `\` no final de cada linha apenas permite escrever um único comando em várias linhas. O mesmo comando poderia ser escrito em uma única linha.

### Explicação geral

O comando cria e inicia um contêiner chamado `imsi-db`, conecta-o à rede `imsi-network`, configura o banco inicial, associa o volume persistente e usa a imagem `postgres:18-alpine`.

### `docker run`

```bash
docker run
```

Cria um novo contêiner a partir de uma imagem e inicia sua execução.

É diferente de `docker start`, que apenas inicia um contêiner criado anteriormente.

### `-d`

```bash
-d
```

É a forma abreviada de `--detach`. Faz o contêiner executar em segundo plano e libera o terminal para novos comandos.

Sem `-d`, os logs do PostgreSQL permaneceriam ligados diretamente ao terminal atual.

Para acompanhar os logs posteriormente:

```bash
docker logs -f imsi-db
```

O parâmetro `-f` acompanha continuamente as novas linhas do log. Para sair da visualização sem parar o contêiner, pressione `Ctrl + C`.

### `--name imsi-db`

```bash
--name imsi-db
```

Define `imsi-db` como nome do contêiner.

Esse nome pode ser usado tanto em comandos Docker quanto como endereço de rede por outros contêineres conectados à `imsi-network`.

Exemplos:

```bash
docker logs imsi-db
docker stop imsi-db
docker start imsi-db
docker inspect imsi-db
```

No backend, esse nome será usado como endereço do PostgreSQL:

```env
DB_HOST=imsi-db
```

### `--network imsi-network`

```bash
--network imsi-network
```

Conecta o novo contêiner à rede `imsi-network`.

A rede precisa existir antes da execução. Por isso, o comando `docker network create imsi-network` aparece como primeiro passo deste roteiro.

### `-e POSTGRES_USER=postgres`

```bash
-e POSTGRES_USER=postgres
```

O parâmetro `-e` cria uma variável de ambiente dentro do contêiner.

`POSTGRES_USER` define o nome do usuário administrativo inicial do PostgreSQL:

```text
Usuário: postgres
```

### `-e POSTGRES_PASSWORD=postgres`

```bash
-e POSTGRES_PASSWORD=postgres
```

Define a senha do usuário inicial:

```text
Senha: postgres
```

Essa senha simples é adequada somente para exercícios em ambiente local. Em produção, deve-se utilizar uma senha forte e evitar registrá-la diretamente no histórico do terminal.

### `-e POSTGRES_DB=quitanda`

```bash
-e POSTGRES_DB=quitanda
```

Solicita a criação de um banco inicial chamado `quitanda`.

As três variáveis juntas representam:

| Configuração | Valor |
|---|---|
| Usuário | `postgres` |
| Senha | `postgres` |
| Banco | `quitanda` |

Essas configurações de inicialização são aplicadas quando o diretório de dados está vazio. Se o volume já contiver um banco inicializado, alterar essas variáveis não recriará automaticamente o usuário ou o banco.

### `-v imsi-postgres-data:/var/lib/postgresql`

```bash
-v imsi-postgres-data:/var/lib/postgresql
```

O parâmetro `-v` associa um volume a um caminho dentro do contêiner.

A sintaxe é:

```text
-v NOME_DO_VOLUME:CAMINHO_DENTRO_DO_CONTÊINER
```

Neste caso:

| Parte | Função |
|---|---|
| `imsi-postgres-data` | Volume administrado pelo Docker no computador hospedeiro. |
| `/var/lib/postgresql` | Diretório usado pela imagem oficial do PostgreSQL 18 para persistência. |

Assim, os dados não ficam dependentes da existência do contêiner `imsi-db`.

### `postgres:18-alpine`

```bash
postgres:18-alpine
```

Indica a imagem usada na criação do contêiner.

| Parte | Explicação |
|---|---|
| `postgres` | Nome da imagem oficial do PostgreSQL. |
| `18-alpine` | Tag que seleciona o PostgreSQL 18 sobre uma base Linux Alpine. |

Se a imagem ainda não existir localmente, o Docker fará seu download antes de criar o contêiner.

---

## 4. Comandos completos em ordem

### Passo 1 — Criar a rede

```bash
docker network create imsi-network
```

### Passo 2 — Criar o volume

```bash
docker volume create imsi-postgres-data
```

### Passo 3 — Criar e iniciar o PostgreSQL

```bash
docker run -d --name imsi-db --network imsi-network -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=senai -e POSTGRES_DB=quitanda -v imsi-postgres-data:/var/lib/postgresql postgres:18-alpine
```

---

## 5. Verificar se o PostgreSQL iniciou corretamente

Listar os contêineres em execução:

```bash
docker ps
```

Ver os logs do PostgreSQL:

```bash
docker logs imsi-db
```

Quando o banco estiver pronto, o log apresentará uma mensagem indicando que o PostgreSQL está preparado para aceitar conexões.

Também é possível testar o banco executando o cliente `psql` dentro do próprio contêiner:

```bash
docker exec -it imsi-db psql -U postgres -d quitanda
```

Dentro do `psql`, listar as tabelas:

```sql
\dt
```

Para sair:

```sql
\q
```

---

## 6. Variáveis usadas pelo backend

Quando o contêiner da aplicação estiver conectado à mesma rede, o backend poderá usar:

```env
DB_USER=postgres
DB_PASS=postgres
DB_HOST=imsi-db
DB_NAME=quitanda
DB_PORT=5432
```

Observe que os nomes esperados pelo backend (`DB_USER`, `DB_PASS`, `DB_HOST`, `DB_NAME` e `DB_PORT`) são diferentes das variáveis de inicialização da imagem PostgreSQL (`POSTGRES_USER`, `POSTGRES_PASSWORD` e `POSTGRES_DB`).

- As variáveis `POSTGRES_*` configuram o contêiner do banco.
- As variáveis `DB_*` informam ao backend como se conectar ao banco.

---

## 7. O que acontece se o contêiner for removido?

Parar e remover o contêiner:

```bash
docker stop imsi-db
docker rm imsi-db
```

Esses comandos removem o contêiner, mas o volume `imsi-postgres-data` continua existindo.

Ao criar outro contêiner PostgreSQL usando o mesmo volume, os dados armazenados anteriormente serão reutilizados.

Para apagar definitivamente os dados, seria necessário remover também o volume:

```bash
docker volume rm imsi-postgres-data
```

> Atenção: a remoção do volume apaga os dados persistidos do PostgreSQL e não deve ser executada se essas informações ainda forem necessárias.

Aguardar o banco ficar disponível:

```bash
docker exec imsi-db pg_isready -U postgres -d quitanda
```

## 6. Restaurar o dump existente

O arquivo `backend/db/bkt_quitanda.sql` é um dump binário do PostgreSQL e deve ser restaurado com `pg_restore`.

Copiar o arquivo para o contêiner do banco:

```bash
docker cp backend/db/bkt_quitanda.sql imsi-db:/tmp/bkt_quitanda.dump
```

Restaurar:

```bash
docker exec imsi-db pg_restore --clean --if-exists --no-owner --username=postgres --dbname=quitanda /tmp/bkt_quitanda.dump
```

## 7. Executar a aplicação sem alterar o código

Como o banco está na rede `imsi-network`, execute:

```bash
docker run --rm --name imsi-app --network imsi-network -p 8080:8080 -p 3000:3000 -e DB_USER=postgres -e DB_PASS=senai -e DB_HOST=imsi-db -e DB_NAME=quitanda -e DB_PORT=5432 imsi-2026
```

As duas portas são necessárias porque o código existente do frontend acessa diretamente `http://localhost:3000/frutas`.

## 8. Acessar o projeto

Frontend:

```text
http://localhost:8080
```

Backend:

```text
http://localhost:3000
```

Endpoint das frutas:

```text
http://localhost:3000/frutas
```

## 9. Testar

Testar o frontend:

```bash
curl http://localhost:8080
```

Testar o backend:

```bash
curl http://localhost:3000
```

Testar as frutas:

```bash
curl http://localhost:3000/frutas
```

Conferir o estado do contêiner:

```bash
docker ps
```

Conferir os logs do Caddy e do backend:

```bash
docker logs -f imsi-app
```

## 10. Usar um PostgreSQL instalado na máquina

No Docker Desktop para macOS ou Windows, use `host.docker.internal`:

```bash
docker run --rm \
    --name imsi-app \
    -p 8080:8080 \
    -p 3000:3000 \
    -e DB_USER=postgres \
    -e DB_PASS=postgres \
    -e DB_HOST=host.docker.internal \
    -e DB_NAME=quitanda \
    -e DB_PORT=5432 \
    imsi-2026
```

No Linux, acrescente:

```text
--add-host=host.docker.internal:host-gateway
```

Exemplo:

```bash
docker run --rm \
    --name imsi-app \
    --add-host=host.docker.internal:host-gateway \
    -p 8080:8080 \
    -p 3000:3000 \
    -e DB_USER=postgres \
    -e DB_PASS=postgres \
    -e DB_HOST=host.docker.internal \
    -e DB_NAME=quitanda \
    -e DB_PORT=5432 \
    imsi-2026
```

## 11. Parar e limpar

Se a aplicação estiver sendo executada sem `--rm`:

```bash
docker stop imsi-app
docker rm imsi-app
```

Parar e remover o banco:

```bash
docker stop imsi-db
docker rm imsi-db
```

O volume continuará preservado.

Para remover definitivamente os dados:

```bash
docker volume rm imsi-postgres-data
```

Remover a rede:

```bash
docker network rm imsi-network
```

## 12. Reconstruir depois de atualizar o repositório

Atualizar o clone:

```bash
git pull
```

Reconstruir:

```bash
docker build -t imsi-2026 .
```

Reconstruir ignorando o cache:

```bash
docker build --no-cache -t imsi-2026 .
```

## 13. Problemas comuns

### O frontend abre, mas não carrega as frutas

Confirme que as duas portas foram publicadas:

```text
-p 8080:8080 -p 3000:3000
```

Teste diretamente:

```bash
curl http://localhost:3000/frutas
```

### O backend reinicia repetidamente

Isso normalmente significa que ele não conseguiu conectar ao PostgreSQL.

Confira:

```bash
docker logs imsi-app
docker logs imsi-db
```

### Erro de conexão com o banco

Se o banco estiver em outro contêiner, confirme:

- ambos estão na rede `imsi-network`;
- `DB_HOST=imsi-db`;
- usuário, senha e nome do banco estão corretos.

### A porta está ocupada

As portas 8080 e 3000 precisam estar livres no host. Para o frontend, a porta externa pode ser alterada, por exemplo:

```text
-p 8081:8080
```

A porta externa 3000 deve permanecer 3000 enquanto o endereço estiver fixo no código do frontend.

## 14. Checklist

- [ ] O repositório foi apenas clonado.
- [ ] Nenhum arquivo original foi alterado.
- [ ] Somente `Dockerfile` foi adicionado na raiz.
- [ ] A imagem possui quatro estágios.
- [ ] O frontend foi compilado com `npm run build`.
- [ ] O backend recebeu suas dependências com `npm ci --omit=dev`.
- [ ] Caddy e backend são iniciados pelo Supervisor.
- [ ] O banco está disponível antes de iniciar a aplicação.
- [ ] As portas `8080:8080` e `3000:3000` foram publicadas.
- [ ] O frontend abre em `http://localhost:8080`.
- [ ] A API responde em `http://localhost:3000/frutas`.

## Referências

- [Repositório IMSI 2026](https://github.com/emellop-senai/imsi-2026)
- [Docker: referência do Dockerfile](https://docs.docker.com/reference/dockerfile/)
- [Docker: builds em múltiplos estágios](https://docs.docker.com/build/building/multi-stage/)
- [Docker: redes de contêineres](https://docs.docker.com/engine/network/)
- [Caddy: servidor de arquivos estáticos](https://caddyserver.com/docs/caddyfile/directives/file_server)
- [Caddy: imagem e instalação](https://caddyserver.com/docs/install#docker)
- [PostgreSQL: pg_restore](https://www.postgresql.org/docs/current/app-pgrestore.html)
