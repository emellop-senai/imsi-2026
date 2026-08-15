# syntax=docker/dockerfile:1.7

# ==============================================================================
# ALVO 1 — FRONTEND REACT/VITE
# ==============================================================================
# Este alvo instala as dependências, compila o frontend e usa o próprio comando
# "vite preview" para disponibilizar o resultado somente durante a aula.
# Não há Caddy, Nginx, proxy reverso, certificado ou configuração HTTPS.
FROM node:24-alpine AS frontend-runtime

# Define o diretório de trabalho do frontend.
WORKDIR /app/frontend

# Copia primeiro os manifestos para aproveitar o cache de camadas do Docker.
COPY frontend/package.json frontend/package-lock.json ./

# Instala todas as dependências, inclusive o Vite usado no build e no preview.
RUN npm ci

# Copia o código-fonte do frontend.
COPY frontend/ ./

# Gera os arquivos de produção na pasta dist.
RUN npm run build

# Executa o processo do frontend sem privilégios administrativos.
USER node

# Documenta a porta utilizada pelo preview do Vite.
EXPOSE 8080

# Verifica se o frontend responde dentro do contêiner.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:8080/').then((response) => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"

# Inicia o preview em todas as interfaces para permitir o acesso pela porta
# publicada com docker run -p 8080:8080.
# O preview do Vite é adequado para esta demonstração local de Docker. O
# servidor definitivo e o HTTPS serão adicionados em uma etapa posterior.
CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0", "--port", "8080"]


# ==============================================================================
# ALVO 2 — DEPENDÊNCIAS DE PRODUÇÃO DO BACKEND
# ==============================================================================
# O backend está em JavaScript e não possui etapa de compilação. Este estágio
# instala somente as dependências necessárias para sua execução.
FROM node:24-alpine AS backend-dependencies

WORKDIR /build/backend

COPY backend/package.json backend/package-lock.json ./

RUN npm ci --omit=dev


# ==============================================================================
# ALVO 3 — BACKEND NODE.JS
# ==============================================================================
# Este é o último alvo e, por isso, também é o alvo padrão quando o comando
# docker build é executado sem a opção --target.
FROM node:24-alpine AS backend-runtime

ENV NODE_ENV=production

# As credenciais do PostgreSQL não ficam gravadas na imagem. Elas serão
# fornecidas ao criar o contêiner com opções -e ou com --env-file.
WORKDIR /app/backend

# Copia os manifestos, o código JavaScript e as dependências de produção.
COPY backend/package.json backend/package-lock.json ./
COPY backend/src ./src
COPY --from=backend-dependencies /build/backend/node_modules ./node_modules

# Usa o usuário não privilegiado que já existe na imagem oficial do Node.js.
USER node

# Documenta a porta utilizada pela API.
EXPOSE 3000

# Verifica se existe um processo aceitando conexões TCP na porta da API, sem
# depender da existência de uma rota HTTP específica como "/".
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD node -e "const socket=require('node:net').connect(3000,'127.0.0.1');socket.on('connect',()=>{socket.end();process.exit(0)});socket.on('error',()=>process.exit(1))"

# Mantém o servidor Node.js como processo principal do contêiner.
CMD ["node", "src/main.js"]
