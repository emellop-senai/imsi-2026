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

O ponto final significa que a pasta atual será usada como contexto do build.

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

### Alternativa rápida: PostgreSQL em outro contêiner

Criar uma rede:

```bash
docker network create imsi-network
```

Criar um volume:

```bash
docker volume create imsi-postgres-data
```

Iniciar o PostgreSQL:

```bash
docker run -d \
    --name imsi-db \
    --network imsi-network \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=quitanda \
    -v imsi-postgres-data:/var/lib/postgresql/data \
    postgres:18-alpine
```

Aguardar o banco ficar disponível:

```bash
docker exec imsi-db pg_isready -U postgres -d quitanda
```

## 6. Restaurar o dump existente

O arquivo `backend/db/bkt_quitanda.sql` é um dump binário do PostgreSQL e deve ser restaurado com `pg_restore`.

Copiar o arquivo para o contêiner do banco:

```bash
docker cp \
    backend/db/bkt_quitanda.sql \
    imsi-db:/tmp/bkt_quitanda.dump
```

Restaurar:

```bash
docker exec imsi-db \
    pg_restore \
    --clean \
    --if-exists \
    --no-owner \
    --username=postgres \
    --dbname=quitanda \
    /tmp/bkt_quitanda.dump
```

## 7. Executar a aplicação sem alterar o código

Como o banco está na rede `imsi-network`, execute:

```bash
docker run --rm \
    --name imsi-app \
    --network imsi-network \
    -p 8080:8080 \
    -p 3000:3000 \
    -e DB_USER=postgres \
    -e DB_PASS=postgres \
    -e DB_HOST=imsi-db \
    -e DB_NAME=quitanda \
    -e DB_PORT=5432 \
    imsi-2026
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
