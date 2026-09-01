# ============================================
# Stage 1: Instalação de dependências
# ============================================
FROM node:22-alpine AS dependencies

WORKDIR /app

# Copiar apenas arquivos de dependência para cache otimizado
COPY src/package.json src/package-lock.json ./

# Instalar apenas dependências de produção
RUN npm ci --only=production && \
    npm cache clean --force

# ============================================
# Stage 2: Imagem final de produção
# ============================================
FROM node:22-alpine AS production

# Metadados da imagem
LABEL maintainer="kube-news-team"
LABEL description="Kube News - Aplicação Node.js/Express com PostgreSQL"

# Criar usuário não-root para segurança
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

# Copiar dependências do stage anterior
COPY --from=dependencies --chown=appuser:appgroup /app/node_modules ./node_modules

# Copiar código-fonte da aplicação
COPY --chown=appuser:appgroup src/ ./

# Variáveis de ambiente padrão
ENV NODE_ENV=production
ENV PORT=8080

# Expor porta da aplicação
EXPOSE 8080

# Usar usuário não-root
USER appuser

# Healthcheck integrado
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Iniciar aplicação
CMD ["node", "server.js"]
