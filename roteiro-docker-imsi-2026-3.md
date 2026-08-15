# Roteiro: executar o IMSI 2026 com Docker

Projeto: [emellop-senai/imsi-2026](https://github.com/emellop-senai/imsi-2026).

## Objetivo

Este roteiro demonstra apenas conceitos do Docker:

1. criar imagens a partir de um Dockerfile;
2. usar alvos diferentes no mesmo Dockerfile;
3. executar frontend, backend e PostgreSQL em contêineres separados;
4. conectar contêineres por uma rede Docker;
5. persistir os dados do PostgreSQL em um volume;
6. publicar portas e fornecer variáveis de ambiente.

Não serão usados Caddy, Nginx, proxy reverso, domínio, certificado ou HTTPS. O frontend será disponibilizado temporariamente pelo `vite preview`. Um servidor definitivo e o HTTPS poderão ser implementados em outra etapa.

O frontend existente acessa:

```text
http://localhost:3000/frutas
```

Por isso, serão publicados no computador:

- `8080`: frontend;
- `3000`: API do backend.

Ao final, a organização será:

```text
Rede Docker: imsi-network
├── imsi-db        → PostgreSQL
├── imsi-backend   → API Node.js
└── imsi-frontend  → preview do frontend Vite

Volume: imsi-postgres-data
└── dados persistentes do PostgreSQL
```

## 1. Clonar o projeto

```bash
git clone https://github.com/emellop-senai/imsi-2026.git
cd imsi-2026
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

## 2. Criar o Dockerfile

Na raiz do projeto, crie um arquivo chamado exatamente `Dockerfile`, sem extensão, com o conteúdo do arquivo Dockerfile entregue junto deste roteiro.

O Dockerfile possui três alvos:

| Alvo | Função | Processo iniciado |
|---|---|---|
| `frontend-runtime` | Instala, compila e disponibiliza o frontend | `npm run preview` |
| `backend-dependencies` | Instala as dependências de produção do backend | nenhum |
| `backend-runtime` | Executa a API Node.js | `node src/main.js` |

### Por que há dois contêineres para a aplicação?

Cada contêiner mantém um único serviço principal. Assim, frontend e backend podem ser iniciados, parados, reconstruídos e inspecionados separadamente. Isso também elimina a necessidade do Supervisor.

### Sobre o frontend nesta aula

O comando `vite preview` disponibiliza os arquivos compilados em HTTP para a demonstração local. Ele não configura HTTPS e não substitui a solução de produção que será implementada posteriormente.

## 3. Construir as duas imagens

### Imagem do frontend

```bash
docker build --target frontend-runtime -t imsi-frontend:1.0 .
```

### Imagem do backend

```bash
docker build --target backend-runtime -t imsi-backend:1.0 .
```

Explicação das opções:

| Parte | Explicação |
|---|---|
| `docker build` | Constrói uma imagem a partir do Dockerfile. |
| `--target` | Escolhe qual alvo do Dockerfile será construído. |
| `-t` | Define o nome e a tag da imagem. |
| `.` | Usa a pasta atual como contexto do build. |

Para visualizar todas as etapas do build:

```bash
docker build --progress=plain --target frontend-runtime -t imsi-frontend:1.0 .
docker build --progress=plain --target backend-runtime -t imsi-backend:1.0 .
```

Conferir as imagens:

```bash
docker image ls imsi-frontend
docker image ls imsi-backend
```

## 4. Criar a rede Docker

```bash
docker network create imsi-network
```

A rede permite que os contêineres se encontrem pelo nome. O backend usará `imsi-db` como endereço do PostgreSQL:

```env
DB_HOST=imsi-db
DB_PORT=5432
```

Dentro de um contêiner, `localhost` aponta para o próprio contêiner. Portanto, o backend não deve usar `localhost` para acessar o contêiner do banco.

Verificar a rede:

```bash
docker network ls
docker network inspect imsi-network
```

## 5. Criar o volume do PostgreSQL

```bash
docker volume create imsi-postgres-data
```

O volume mantém os dados fora do sistema de arquivos descartável do contêiner. Dessa forma, remover e recriar `imsi-db` não apaga automaticamente o banco.

Verificar o volume:

```bash
docker volume ls
docker volume inspect imsi-postgres-data
```

## 6. Iniciar o PostgreSQL

```bash
docker run -d \
  --name imsi-db \
  --network imsi-network \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=senai \
  -e POSTGRES_DB=quitanda \
  -v imsi-postgres-data:/var/lib/postgresql \
  postgres:18-alpine
```

Principais opções:

| Opção | Função |
|---|---|
| `-d` | Executa o contêiner em segundo plano. |
| `--name imsi-db` | Define o nome do contêiner. |
| `--network imsi-network` | Conecta o banco à rede criada. |
| `-e` | Cria uma variável de ambiente no contêiner. |
| `-v` | Associa o volume ao diretório de dados. |
| `postgres:18-alpine` | Seleciona a imagem e sua tag. |

As variáveis `POSTGRES_*` inicializam a imagem do banco:

| Configuração | Valor |
|---|---|
| Usuário | `postgres` |
| Senha | `senai` |
| Banco | `quitanda` |

Essa senha é adequada apenas para a atividade local. Não registre senhas de produção diretamente em comandos.

Verificar se o banco iniciou:

```bash
docker ps
docker logs imsi-db
docker exec imsi-db pg_isready -U postgres -d quitanda
```

## 7. Restaurar o dump existente

O arquivo `backend/db/bkt_quitanda.sql` é um dump binário do PostgreSQL e deve ser restaurado com `pg_restore`.

Copiar o arquivo para o contêiner:

```bash
docker cp backend/db/bkt_quitanda.sql imsi-db:/tmp/bkt_quitanda.dump
```

Restaurar o banco:

```bash
docker exec imsi-db pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --username=postgres \
  --dbname=quitanda \
  /tmp/bkt_quitanda.dump
```

## 8. Iniciar o backend

```bash
docker run -d \
  --name imsi-backend \
  --network imsi-network \
  -p 3000:3000 \
  -e DB_USER=postgres \
  -e DB_PASS=senai \
  -e DB_HOST=imsi-db \
  -e DB_NAME=quitanda \
  -e DB_PORT=5432 \
  imsi-backend:1.0
```

As variáveis `DB_*` são lidas pelo backend e são diferentes das variáveis `POSTGRES_*`, usadas para inicializar o contêiner do banco.

## 9. Iniciar o frontend

```bash
docker run -d \
  --name imsi-frontend \
  --network imsi-network \
  -p 8080:8080 \
  imsi-frontend:1.0
```

O frontend e o backend estão em contêineres separados, mas o navegador acessa ambos pelas portas publicadas no computador:

```text
Frontend → http://localhost:8080
Backend  → http://localhost:3000
```

## 10. Acessar e testar

Abra no navegador:

```text
http://localhost:8080
```

Teste a API:

```bash
curl http://localhost:3000
curl http://localhost:3000/frutas
```

Teste o frontend:

```bash
curl http://localhost:8080
```

Conferir os contêineres e seus estados de saúde:

```bash
docker ps
```

Conferir os logs separadamente:

```bash
docker logs -f imsi-frontend
docker logs -f imsi-backend
docker logs -f imsi-db
```

Use `Ctrl + C` para sair da visualização dos logs sem parar o contêiner.

## 11. Usar um arquivo de variáveis

Para evitar um comando muito longo, crie localmente um arquivo chamado `.env.docker`:

```env
DB_USER=postgres
DB_PASS=senai
DB_HOST=imsi-db
DB_NAME=quitanda
DB_PORT=5432
```

Depois, substitua as opções `-e` do backend por:

```bash
docker run -d \
  --name imsi-backend \
  --network imsi-network \
  -p 3000:3000 \
  --env-file .env.docker \
  imsi-backend:1.0
```

O arquivo contém credenciais e não deve ser versionado no Git.

## 12. Comandos de administração

Parar os contêineres:

```bash
docker stop imsi-frontend imsi-backend imsi-db
```

Iniciar novamente contêineres existentes:

```bash
docker start imsi-db imsi-backend imsi-frontend
```

Remover os contêineres:

```bash
docker rm imsi-frontend imsi-backend imsi-db
```

O volume continuará existindo. Para removê-lo e apagar definitivamente os dados:

```bash
docker volume rm imsi-postgres-data
```

Remover a rede depois que nenhum contêiner estiver conectado:

```bash
docker network rm imsi-network
```

## 13. Reconstruir após atualizar o projeto

```bash
git pull
docker build --target frontend-runtime -t imsi-frontend:1.0 .
docker build --target backend-runtime -t imsi-backend:1.0 .
```

Para ignorar o cache:

```bash
docker build --no-cache --target frontend-runtime -t imsi-frontend:1.0 .
docker build --no-cache --target backend-runtime -t imsi-backend:1.0 .
```

Depois do novo build, remova e recrie os contêineres da aplicação para que eles usem as novas imagens.

## 14. Problemas comuns

### O frontend não inicia

Confira se `frontend/package.json` possui o script `preview`:

```json
{
  "scripts": {
    "preview": "vite preview"
  }
}
```

Consulte o erro real:

```bash
docker logs imsi-frontend
```

### O frontend abre, mas não carrega as frutas

O código atual acessa `http://localhost:3000/frutas`. Confirme que o backend publicou a porta `3000`:

```bash
docker ps
curl http://localhost:3000/frutas
```

### O backend não conecta ao banco

Confira:

- `imsi-backend` e `imsi-db` estão na rede `imsi-network`;
- `DB_HOST=imsi-db`;
- usuário, senha e banco correspondem aos valores usados no PostgreSQL;
- o banco está pronto para receber conexões.

```bash
docker network inspect imsi-network
docker logs imsi-backend
docker logs imsi-db
```

### Uma porta já está ocupada

A porta externa do frontend pode ser alterada:

```bash
docker run -d --name imsi-frontend -p 8081:8080 imsi-frontend:1.0
```

Nesse caso, acesse `http://localhost:8081`.

A porta externa do backend deve permanecer `3000` enquanto esse endereço estiver fixo no código do frontend.

## 15. Checklist

- [ ] O repositório foi clonado.
- [ ] O Dockerfile foi adicionado na raiz.
- [ ] Não há Caddy, Nginx, proxy reverso ou HTTPS nesta etapa.
- [ ] As imagens `imsi-frontend:1.0` e `imsi-backend:1.0` foram construídas.
- [ ] O PostgreSQL usa a rede `imsi-network` e o volume `imsi-postgres-data`.
- [ ] O backend recebeu as variáveis `DB_*`.
- [ ] O frontend está publicado em `8080:8080`.
- [ ] O backend está publicado em `3000:3000`.
- [ ] O frontend abre em `http://localhost:8080`.
- [ ] A API responde em `http://localhost:3000/frutas`.

## Referências

- [Repositório IMSI 2026](https://github.com/emellop-senai/imsi-2026)
- [Dockerfile](https://docs.docker.com/reference/dockerfile/)
- [Builds com múltiplos estágios](https://docs.docker.com/build/building/multi-stage/)
- [Redes Docker](https://docs.docker.com/engine/network/)
- [Volumes Docker](https://docs.docker.com/engine/storage/volumes/)
- [PostgreSQL: pg_restore](https://www.postgresql.org/docs/current/app-pgrestore.html)
