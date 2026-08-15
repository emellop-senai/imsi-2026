# syntax=docker/dockerfile:1.7

# ==============================================================================
# ETAPA 1 — COMPILAÇÃO DO FRONTEND
# ==============================================================================
# Este estágio instala todas as dependências do frontend e gera os arquivos
# estáticos de produção. Como ele possui um nome (frontend-builder), seus
# artefatos podem ser copiados posteriormente para a imagem final.
FROM node:24-alpine AS frontend-builder

# Define o diretório usado pelos próximos comandos deste estágio.
WORKDIR /build/frontend

# Copia primeiro apenas os arquivos que descrevem as dependências.
# Essa separação permite que o Docker reaproveite a camada do "npm ci" quando
# o código-fonte mudar, mas package.json e package-lock.json continuarem iguais.
COPY frontend/package.json frontend/package-lock.json ./

# Instala exatamente as versões registradas no package-lock.json.
# As dependências de desenvolvimento também são necessárias aqui, pois o build
# normalmente utiliza ferramentas como Vite, TypeScript ou similares.
RUN npm ci

# Copia o restante do código do frontend para o diretório de trabalho.
COPY frontend/ ./

# Executa o script "build" definido em frontend/package.json.
# Este Dockerfile pressupõe que o resultado será criado em /build/frontend/dist.
RUN npm run build


# ==============================================================================
# ETAPA 2 — DEPENDÊNCIAS DE PRODUÇÃO DO BACKEND
# ==============================================================================
# O backend é preparado em um estágio separado para que somente suas
# dependências de produção sejam copiadas para a imagem final.
#
# Diferentemente do frontend, este backend não precisa ser compilado:
# - seu código-fonte já está em JavaScript;
# - o package.json usa "type": "module" para habilitar ES Modules;
# - seu arquivo de entrada é backend/src/main.js;
# - não existe um script "build" no backend/package.json.
FROM node:24-alpine AS backend-builder

# Define o diretório usado para instalar as dependências do backend.
WORKDIR /build/backend

# Copia primeiro os manifestos para aproveitar o cache de camadas do Docker.
COPY backend/package.json backend/package-lock.json ./

# Instala exatamente as versões registradas no package-lock.json.
# A opção --omit=dev ignora dependências de desenvolvimento e mantém somente o
# necessário para executar Express, CORS, dotenv e o cliente PostgreSQL.
#
# Não existe "RUN npm run build" nesta etapa porque o package.json do backend
# não possui esse script e o código JavaScript pode ser executado diretamente.
RUN npm ci --omit=dev


# ==============================================================================
# ETAPA 3 — OBTENÇÃO DO BINÁRIO OFICIAL DO CADDY
# ==============================================================================
# Este estágio existe somente para fornecer o binário oficial do Caddy. Dessa
# forma, não precisamos instalar o servidor web por um repositório de terceiros.
FROM caddy:2-alpine AS caddy-binary


# ==============================================================================
# ETAPA 4 — IMAGEM FINAL DE EXECUÇÃO
# ==============================================================================
# A imagem final parte novamente de uma imagem Node enxuta. Nenhum compilador do
# frontend ou backend é mantido nela.
FROM node:24-alpine AS runtime

# Informa ao Node.js e às bibliotecas que a aplicação roda em produção.
ENV NODE_ENV=production

# O backend lê as configurações do PostgreSQL pelas seguintes variáveis:
# DB_USER, DB_PASS, DB_HOST, DB_NAME e DB_PORT.
#
# Elas não são definidas na imagem para evitar armazenar credenciais no
# Dockerfile. Seus valores devem ser fornecidos ao iniciar o contêiner, usando
# --env-file, opções -e, Docker Compose ou a plataforma de implantação.

# Define diretórios graváveis usados internamente pelo Caddy.
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

# Instala:
# - supervisor: mantém backend e Caddy em execução no mesmo contêiner;
# - ca-certificates: permite conexões HTTPS com certificados confiáveis.
RUN apk add --no-cache supervisor ca-certificates

# Copia somente o executável do Caddy a partir da imagem oficial.
COPY --from=caddy-binary /usr/bin/caddy /usr/bin/caddy

# Define /app como diretório-base da aplicação na imagem final.
WORKDIR /app

# Copia os manifestos do backend para documentação e inspeção da aplicação.
COPY backend/package.json backend/package-lock.json ./backend/

# Copia o código-fonte JavaScript do backend diretamente para a imagem final.
# Como o projeto não usa TypeScript nem transpilador, não existe uma pasta dist.
COPY backend/src ./backend/src

# Copia somente as dependências de produção instaladas no backend-builder.
# É importante usar backend-builder aqui, e não frontend-builder.
COPY --from=backend-builder /build/backend/node_modules ./backend/node_modules

# Copia os arquivos estáticos compilados do frontend para serem servidos pelo
# Caddy. O código-fonte e as dependências do frontend não entram na imagem final.
COPY --from=frontend-builder /build/frontend/dist ./frontend/dist


# ==============================================================================
# PREPARAÇÃO DOS DIRETÓRIOS E PERMISSÕES
# ==============================================================================
# O backend e o Caddy serão executados pelo usuário "node", que já existe na
# imagem-base. Por isso, criamos os diretórios de trabalho do Caddy e entregamos
# a propriedade deles a esse usuário não privilegiado.
RUN mkdir -p /etc/caddy /config/caddy /data/caddy \
    && chown -R node:node /config /data


# ==============================================================================
# SCRIPT DE CRIAÇÃO DA CONFIGURAÇÃO DO CADDY
# ==============================================================================
# "RUN <<'EOF'" inicia um heredoc: todas as linhas até o EOF final são enviadas
# ao shell como um único script durante o build da imagem.
#
# O delimitador está entre aspas simples para impedir que o shell expanda
# variáveis, curingas ou substituições enquanto cria o arquivo.
RUN <<'EOF'
# Garante que o diretório exista. A opção -p não causa erro se ele já existir.
mkdir -p /etc/caddy

# "cat > arquivo" cria ou substitui o Caddyfile.
# O segundo heredoc termina na linha que contém somente CADDYFILE.
cat > /etc/caddy/Caddyfile <<'CADDYFILE'
# Escuta requisições HTTP em todas as interfaces na porta 8080.
:8080 {
    # Define onde estão os arquivos estáticos compilados do frontend.
    root * /app/frontend/dist

    # Comprime as respostas com Zstandard quando suportado e usa gzip como
    # alternativa para clientes que não aceitam zstd.
    encode zstd gzip

    # Primeiro tenta servir exatamente o caminho solicitado. Se o arquivo não
    # existir, retorna index.html. Esse fallback permite que rotas de uma SPA,
    # como /usuarios/123, sejam tratadas pelo roteador do frontend.
    try_files {path} /index.html

    # Habilita o servidor de arquivos estáticos do Caddy.
    file_server
}
CADDYFILE
EOF


# ==============================================================================
# SCRIPT DE CRIAÇÃO DA CONFIGURAÇÃO DO SUPERVISOR
# ==============================================================================
#
# VISÃO GERAL DO QUE ACONTECE NESTE TRECHO
#
# 1. Durante o "docker build", a instrução RUN abre um shell temporário.
# 2. O comando "cat" recebe o texto localizado entre SUPERVISOR e SUPERVISOR.
# 3. O operador ">" grava esse texto no arquivo /etc/supervisord.conf.
# 4. O shell termina e o arquivo fica armazenado em uma camada da imagem.
# 5. Nenhum serviço é iniciado durante esses passos.
# 6. Somente quando o contêiner for iniciado, o CMD localizado no final deste
#    Dockerfile executará o supervisord.
# 7. O supervisord lerá /etc/supervisord.conf e iniciará o backend e o Caddy.
#
# Em resumo:
#
#   docker build
#       -> RUN cria /etc/supervisord.conf
#
#   docker run
#       -> CMD inicia supervisord
#       -> supervisord inicia backend
#       -> supervisord inicia Caddy
#
# O Supervisor é usado porque um contêiner possui um único processo principal,
# mas esta imagem precisa manter dois serviços ativos ao mesmo tempo. Ele se
# torna o processo principal e passa a gerenciar os outros dois processos.
RUN <<'EOF'
# Esta linha é executada pelo shell somente durante o build:
#
# - cat: recebe texto pela entrada padrão;
# - >: cria ou substitui o arquivo informado à direita;
# - <<'SUPERVISOR': começa um segundo heredoc;
# - as aspas simples fazem o conteúdo ser gravado literalmente, sem expandir
#   variáveis como $HOME e sem interpretar outros caracteres do shell;
# - a palavra SUPERVISOR, sozinha no fim do bloco, encerra esse heredoc interno.
cat > /etc/supervisord.conf <<'SUPERVISOR'

# ------------------------------------------------------------------------------
# CONFIGURAÇÃO DO PROCESSO PRINCIPAL: SUPERVISORD
# ------------------------------------------------------------------------------
# Uma seção entre colchetes agrupa configurações. A seção [supervisord] controla
# o próprio gerenciador; ela não representa o backend nem o Caddy.
[supervisord]

# false faria o Supervisor se separar do terminal e ir para segundo plano.
# true faz com que ele permaneça em primeiro plano. Isso é necessário em um
# contêiner, pois o encerramento do processo principal encerra o contêiner.
nodaemon=true

# Define o usuário do processo supervisord. Ele inicia como root para poder criar
# os filhos e trocar o usuário deles para "node". Observe que as seções dos dois
# programas possuem "user=node", portanto backend e Caddy não rodam como root.
user=root

# Desabilita o arquivo de log próprio do Supervisor ao apontá-lo para /dev/null.
# Os logs do backend e do Caddy terão destinos separados mais abaixo.
logfile=/dev/null

# Impede rotação do logfile acima. Como o destino é /dev/null, não há arquivo
# real para crescer nem necessidade de criar versões antigas do log.
logfile_maxbytes=0

# Guarda o número identificador do processo supervisord em /tmp, um diretório
# gravável dentro do contêiner. Esse arquivo é usado para identificar o processo.
pidfile=/tmp/supervisord.pid


# ------------------------------------------------------------------------------
# PROGRAMA GERENCIADO 1: BACKEND NODE.JS
# ------------------------------------------------------------------------------
# [program:backend] cria um programa chamado "backend" dentro do Supervisor.
# Esse nome aparece nos logs e também poderia ser usado com supervisorctl.
[program:backend]

# Comando exato que o Supervisor executará para iniciar o backend:
#
# - node: executável do Node.js disponível no PATH da imagem;
# - /app/backend/src/main.js: ponto de entrada JavaScript do backend.
#
# Esta linha não é executada durante o build. Ela será executada pelo Supervisor
# somente quando o contêiner estiver rodando.
command=node /app/backend/src/main.js

# Define o diretório de trabalho do processo antes de executar o comando.
# Por exemplo, se o backend abrir "./arquivo.json", o caminho será interpretado
# como /app/backend/arquivo.json.
directory=/app/backend

# Solicita ao Supervisor que troque do usuário root para o usuário node antes de
# iniciar o comando. Isso limita os privilégios do backend dentro do contêiner.
user=node

# true manda iniciar o backend automaticamente quando o supervisord iniciar.
# Se fosse false, seria necessário iniciar o programa manualmente.
autostart=true

# true manda reiniciar o backend sempre que ele encerrar, seja por erro ou por
# encerramento normal. Isso mantém o serviço disponível enquanto o contêiner vive.
autorestart=true

# Durante a fase inicial, o Supervisor tentará iniciar o backend novamente até
# 30 vezes antes de classificá-lo como FATAL. Essa opção trata falhas de partida;
# depois que o programa já estiver estável, autorestart controla as reinicializações.
startretries=30

# Ao parar o backend, envia o sinal de encerramento para todo o grupo de processos,
# não apenas para o processo Node principal. Isso inclui subprocessos que o Node
# eventualmente tenha criado.
stopasgroup=true

# Se for necessário forçar a parada, também envia o sinal de finalização forçada
# para todo o grupo. Isso evita subprocessos órfãos dentro do contêiner.
killasgroup=true

# /dev/fd/1 é o stdout do contêiner. Tudo que o backend escrever na saída padrão
# aparecerá no terminal e em "docker logs <nome-do-container>".
stdout_logfile=/dev/fd/1

# 0 desabilita a rotação feita pelo Supervisor. A plataforma de contêineres pode
# continuar aplicando sua própria política externa de rotação dos logs.
stdout_logfile_maxbytes=0

# /dev/fd/2 é o stderr do contêiner. Erros escritos pelo backend são encaminhados
# para a saída de erros e também ficam visíveis por meio de "docker logs".
stderr_logfile=/dev/fd/2

# Desabilita a rotação interna da saída de erros pelo Supervisor.
stderr_logfile_maxbytes=0


# ------------------------------------------------------------------------------
# PROGRAMA GERENCIADO 2: SERVIDOR WEB CADDY
# ------------------------------------------------------------------------------
# [program:caddy] registra um segundo programa, independente do backend, com o
# nome "caddy". O Supervisor monitora os dois programas separadamente.
[program:caddy]

# Comando executado para iniciar o servidor web:
#
# - /usr/bin/caddy: caminho absoluto do binário copiado da imagem oficial;
# - run: mantém o Caddy executando em primeiro plano;
# - --config /etc/caddy/Caddyfile: informa qual arquivo de configuração ler;
# - --adapter caddyfile: informa que o formato desse arquivo é Caddyfile.
command=/usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile

# Define /app como diretório de trabalho antes de iniciar o Caddy. Neste caso, o
# Caddyfile usa um caminho absoluto para o frontend, mas manter um diretório de
# trabalho explícito torna a execução previsível.
directory=/app

# Executa o Caddy como usuário node. Isso funciona porque ele escuta na porta
# 8080; no Linux, somente portas abaixo de 1024 normalmente exigem privilégio.
user=node

# Inicia o Caddy automaticamente junto com o Supervisor.
autostart=true

# Reinicia o Caddy sempre que o processo encerrar.
autorestart=true

# Tenta iniciar o Caddy até 30 vezes antes de marcar sua inicialização como FATAL.
startretries=30

# Envia o sinal de parada a todo o grupo de processos do Caddy.
stopasgroup=true

# Envia uma finalização forçada a todo o grupo, caso a parada normal não funcione.
killasgroup=true

# Encaminha a saída padrão do Caddy para o stdout do contêiner.
stdout_logfile=/dev/fd/1

# Desabilita a rotação interna da saída padrão.
stdout_logfile_maxbytes=0

# Encaminha a saída de erros do Caddy para o stderr do contêiner.
stderr_logfile=/dev/fd/2

# Desabilita a rotação interna da saída de erros.
stderr_logfile_maxbytes=0

# Esta palavra encerra o heredoc interno iniciado em
# "cat > /etc/supervisord.conf <<'SUPERVISOR'". Ela não é gravada no arquivo.
SUPERVISOR

# Esta palavra encerra o heredoc externo iniciado em "RUN <<'EOF'".
# Ela também não faz parte do script nem do arquivo supervisord.conf.
EOF


# Documenta as portas usadas pelos processos dentro do contêiner:
# - 8080: frontend servido pelo Caddy;
# - 3000: backend Node.js.
# EXPOSE não publica portas sozinho; a publicação ocorre com "docker run -p"
# ou pela configuração da plataforma de implantação.
#
# Como o frontend atual acessa http://localhost:3000/frutas diretamente no
# navegador, para testar localmente publique as duas portas, por exemplo:
# docker run -p 8080:8080 -p 3000:3000 ... imsi-2026
EXPOSE 8080 3000


# ==============================================================================
# VERIFICAÇÃO DE SAÚDE DO CONTÊINER
# ==============================================================================
# A cada 30 segundos, o Docker executa um script Node que consulta os dois
# serviços pela interface local do contêiner.
#
# - timeout=5s: cada execução pode durar no máximo cinco segundos;
# - start-period=15s: falhas nos primeiros 15 segundos não contam como erro;
# - retries=3: três falhas consecutivas marcam o contêiner como unhealthy.
#
# Promise.all espera as duas requisições. "responses.every" exige status 2xx
# nos dois serviços. Qualquer erro de rede ou status inválido encerra com código
# 1; sucesso encerra com código 0.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD node -e "Promise.all([fetch('http://127.0.0.1:8080/'), fetch('http://127.0.0.1:3000/')]).then((responses) => process.exit(responses.every((response) => response.ok) ? 0 : 1)).catch(() => process.exit(1))"


# Define o Supervisor como processo principal (PID 1) do contêiner. Ele inicia,
# monitora e encerra corretamente o backend e o Caddy.
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
