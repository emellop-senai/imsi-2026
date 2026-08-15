# Roteiro: executar o IMSI 2026 com Docker Compose

## Objetivo

Neste roteiro, a estrutura criada anteriormente com comandos `docker build` e `docker run` será declarada em um arquivo `compose.yaml`.

O Docker Compose irá:

1. construir as imagens do frontend e do backend;
2. baixar a imagem do PostgreSQL;
3. criar a rede da aplicação;
4. criar o volume persistente do banco;
5. iniciar os três contêineres;
6. fornecer as variáveis de ambiente;
7. aguardar o banco ficar saudável antes de iniciar o backend;
8. aguardar o backend ficar saudável antes de iniciar o frontend.

Continuaremos sem Caddy, Nginx, proxy reverso ou HTTPS. O frontend permanecerá usando temporariamente o `vite preview` em HTTP.

## 1. Estrutura esperada

Na raiz do projeto, os arquivos devem ficar assim:

```text
imsi-2026/
├── backend/
├── frontend/
├── Dockerfile
├── compose.yaml
└── roteiro-docker-compose-imsi-2026.md
```

O `compose.yaml` usa os alvos existentes no Dockerfile:

| Serviço | Alvo do Dockerfile | Porta publicada |
|---|---|---|
| `frontend` | `frontend-runtime` | `8080:8080` |
| `backend` | `backend-runtime` | `3000:3000` |
| `database` | Imagem `postgres:18-alpine` | nenhuma |

O banco não publica a porta `5432` no computador. Somente o backend precisa acessá-lo, e essa comunicação ocorre pela rede interna do Docker.

## 2. Adicionar o arquivo Compose

Copie o arquivo `compose.yaml` entregue junto deste roteiro para a raiz do projeto.

O nome recomendado é:

```text
compose.yaml
```

Com esse nome, não é necessário usar a opção `-f` nos comandos.

## 3. Entender a estrutura do arquivo

### Nome do projeto

```yaml
name: imsi-2026
```

Define o nome do projeto Compose. Ele será usado pelo Docker para identificar e agrupar os recursos da aplicação.

### Serviços

```yaml
services:
```

Cada item dentro de `services` representa um contêiner da aplicação:

- `database`: PostgreSQL;
- `backend`: API Node.js;
- `frontend`: interface React/Vite.

## 4. Serviço do PostgreSQL

```yaml
database:
  image: postgres:18-alpine
```

O banco utiliza uma imagem existente. Por isso, não possui a opção `build`.

### Variáveis com valores padrão

```yaml
environment:
  POSTGRES_USER: ${POSTGRES_USER:-postgres}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-senai}
  POSTGRES_DB: ${POSTGRES_DB:-quitanda}
```

A expressão abaixo significa “usar a variável `POSTGRES_USER`; se ela não estiver definida, usar `postgres`”:

```text
${POSTGRES_USER:-postgres}
```

Os valores padrão são adequados somente para a atividade local.

### Volume

```yaml
volumes:
  - postgres-data:/var/lib/postgresql
```

O lado esquerdo é o volume administrado pelo Docker. O lado direito é o diretório de persistência usado pela imagem do PostgreSQL 18.

### Verificação de saúde

```yaml
healthcheck:
  test:
    - CMD-SHELL
    - pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}
```

O comando `pg_isready` verifica se o PostgreSQL já aceita conexões.

O uso de `$$` impede que o Compose substitua a variável antecipadamente. Dessa forma, `$POSTGRES_USER` e `$POSTGRES_DB` são lidos dentro do contêiner.

## 5. Serviço do backend

```yaml
backend:
  build:
    context: .
    target: backend-runtime
```

O Compose constrói a imagem usando:

- a pasta atual como contexto;
- o Dockerfile existente na raiz;
- o alvo `backend-runtime`.

Isso equivale conceitualmente a:

```bash
docker build --target backend-runtime -t imsi-backend:1.0 .
```

### Endereço do banco

```yaml
DB_HOST: database
```

Dentro da rede do Compose, o nome do serviço funciona como endereço DNS. Portanto, o backend acessa o PostgreSQL usando o nome `database`, não `localhost` e não o nome automático do contêiner.

```text
backend → database:5432 → PostgreSQL
```

### Publicação da API

```yaml
ports:
  - "3000:3000"
```

A porta da esquerda pertence ao computador. A porta da direita pertence ao contêiner.

### Dependência do banco

```yaml
depends_on:
  database:
    condition: service_healthy
```

O Compose somente inicia o backend depois que o `healthcheck` do banco informar que ele está saudável.

## 6. Serviço do frontend

```yaml
frontend:
  build:
    context: .
    target: frontend-runtime
```

O alvo `frontend-runtime` instala as dependências, executa `npm run build` e inicia o `vite preview`.

### Publicação do frontend

```yaml
ports:
  - "8080:8080"
```

Depois da inicialização, o frontend estará disponível em:

```text
http://localhost:8080
```

O código existente do frontend acessa a API pelo navegador em:

```text
http://localhost:3000/frutas
```

Por isso, a porta `3000` do backend continua publicada no computador.

## 7. Rede e volume

No final do arquivo, os recursos são declarados:

```yaml
volumes:
  postgres-data:
    name: imsi-postgres-data

networks:
  imsi-network:
    name: imsi-network
```

O Compose criará automaticamente esses recursos quando o projeto for iniciado.

Não é mais necessário executar manualmente:

```bash
docker network create imsi-network
docker volume create imsi-postgres-data
```

## 8. Validar o arquivo

Antes de iniciar, peça ao Compose para interpretar e validar a configuração:

```bash
docker compose config
```

Esse comando apresenta a configuração final depois de aplicar valores padrão e variáveis de ambiente.

Para apenas verificar a validade sem imprimir o resultado:

```bash
docker compose config --quiet
```

## 9. Construir as imagens

```bash
docker compose build
```

O Compose construirá somente os serviços que possuem a seção `build`: frontend e backend.

Para acompanhar todas as etapas:

```bash
docker compose build --progress=plain
```

Para ignorar o cache:

```bash
docker compose build --no-cache
```

## 10. Iniciar toda a aplicação

```bash
docker compose up -d
```

Esse único comando:

- cria a rede;
- cria o volume;
- constrói imagens ausentes;
- cria os contêineres;
- inicia os serviços na ordem definida pelas dependências;
- mantém a aplicação em segundo plano por causa de `-d`.

Também é possível construir e iniciar em um único comando:

```bash
docker compose up -d --build
```

## 11. Verificar os serviços

```bash
docker compose ps
```

A coluna de estado permite verificar se os serviços estão em execução e saudáveis.

Também é possível usar:

```bash
docker ps
```

## 12. Restaurar o dump do banco

Depois que o PostgreSQL estiver saudável, copie o dump para o serviço `database`:

```bash
docker compose cp \
  backend/db/bkt_quitanda.sql \
  database:/tmp/bkt_quitanda.dump
```

Execute o `pg_restore` dentro do contêiner:

```bash
docker compose exec database pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --username=postgres \
  --dbname=quitanda \
  /tmp/bkt_quitanda.dump
```

Essa restauração precisa ser feita apenas quando o volume ainda não contém os dados desejados.

## 13. Acessar e testar

Frontend:

```text
http://localhost:8080
```

API:

```text
http://localhost:3000
```

Endpoint das frutas:

```text
http://localhost:3000/frutas
```

Testes pelo terminal:

```bash
curl http://localhost:8080
curl http://localhost:3000
curl http://localhost:3000/frutas
```

## 14. Visualizar os logs

Logs de todos os serviços:

```bash
docker compose logs -f
```

Logs de apenas um serviço:

```bash
docker compose logs -f frontend
docker compose logs -f backend
docker compose logs -f database
```

Use `Ctrl + C` para sair da visualização sem parar os serviços.

## 15. Executar comandos dentro dos contêineres

Abrir um shell no backend:

```bash
docker compose exec backend sh
```

Abrir o cliente PostgreSQL:

```bash
docker compose exec database psql -U postgres -d quitanda
```

Dentro do `psql`, listar as tabelas:

```sql
\dt
```

Para sair:

```sql
\q
```

## 16. Parar e reiniciar

Parar os contêineres sem removê-los:

```bash
docker compose stop
```

Iniciar novamente:

```bash
docker compose start
```

Reiniciar todos os serviços:

```bash
docker compose restart
```

Reiniciar somente o backend:

```bash
docker compose restart backend
```

## 17. Encerrar o projeto

Parar e remover os contêineres e a rede:

```bash
docker compose down
```

O volume `imsi-postgres-data` será preservado.

Para remover também o volume e apagar os dados do PostgreSQL:

```bash
docker compose down --volumes
```

> Atenção: `--volumes` remove os dados persistidos. Use somente quando a perda do banco for intencional.

## 18. Atualizar depois de alterar o código

Reconstruir e recriar os serviços:

```bash
docker compose up -d --build
```

Se quiser reconstruir apenas o backend:

```bash
docker compose up -d --build backend
```

Para o frontend:

```bash
docker compose up -d --build frontend
```

## 19. Usar variáveis próprias

O Compose lê automaticamente um arquivo chamado `.env` localizado ao lado do `compose.yaml`.

Exemplo opcional:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=outra_senha
POSTGRES_DB=quitanda
```

Não é obrigatório criar esse arquivo, pois o Compose já possui valores padrão para a aula.

Não versione `.env` quando ele contiver credenciais reais.

Depois de alterar variáveis, recrie os serviços:

```bash
docker compose up -d --force-recreate
```

As variáveis `POSTGRES_*` só inicializam usuário e banco quando o volume está vazio. Se o volume já possuir um banco, mudar essas variáveis não altera automaticamente os dados existentes.

## 20. Problemas comuns

### O backend não inicia

Verifique o estado e os logs:

```bash
docker compose ps
docker compose logs backend
docker compose logs database
```

Confirme que o banco ficou saudável:

```bash
docker compose exec database pg_isready -U postgres -d quitanda
```

### O frontend não inicia

Confirme que `frontend/package.json` possui o script:

```json
{
  "scripts": {
    "preview": "vite preview"
  }
}
```

Depois, consulte:

```bash
docker compose logs frontend
```

### O frontend abre, mas não carrega as frutas

O navegador precisa alcançar a API pela porta publicada no computador:

```bash
curl http://localhost:3000/frutas
```

Confira se `backend` está saudável:

```bash
docker compose ps backend
```

### A porta está ocupada

Altere apenas a porta do lado esquerdo.

Exemplo para abrir o frontend em `http://localhost:8081`:

```yaml
ports:
  - "8081:8080"
```

A porta externa do backend deve continuar `3000` enquanto o endereço estiver fixo no código do frontend.

### As credenciais foram alteradas, mas o banco continua usando as antigas

As configurações iniciais são persistidas no volume. Para recomeçar apagando os dados:

```bash
docker compose down --volumes
docker compose up -d --build
```

> Esse procedimento apaga o banco persistido.

## 21. Comparação com os comandos anteriores

| Antes | Com Docker Compose |
|---|---|
| `docker network create` | Rede declarada em `networks` |
| `docker volume create` | Volume declarado em `volumes` |
| Dois comandos `docker build` | `docker compose build` |
| Três comandos `docker run` | `docker compose up -d` |
| `docker logs` por nome de contêiner | `docker compose logs` por serviço |
| `docker stop` e `docker rm` | `docker compose down` |

O Compose não substitui o Docker. Ele organiza e executa, de forma declarativa, os mesmos conceitos já estudados.

## 22. Checklist

- [ ] O `compose.yaml` está na raiz do projeto.
- [ ] O comando `docker compose config --quiet` não apresentou erros.
- [ ] O frontend foi construído pelo alvo `frontend-runtime`.
- [ ] O backend foi construído pelo alvo `backend-runtime`.
- [ ] O PostgreSQL utiliza o volume `imsi-postgres-data`.
- [ ] Os três serviços estão conectados à rede `imsi-network`.
- [ ] O banco fica saudável antes do backend iniciar.
- [ ] O backend fica saudável antes do frontend iniciar.
- [ ] O frontend abre em `http://localhost:8080`.
- [ ] A API responde em `http://localhost:3000/frutas`.
- [ ] Não há servidor HTTPS nesta etapa.

## Referências

- [Docker Compose](https://docs.docker.com/compose/)
- [Referência do arquivo Compose](https://docs.docker.com/reference/compose-file/)
- [Ordem de inicialização](https://docs.docker.com/compose/how-tos/startup-order/)
- [Variáveis no Compose](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)
- [Volumes](https://docs.docker.com/engine/storage/volumes/)
- [Redes](https://docs.docker.com/engine/network/)
