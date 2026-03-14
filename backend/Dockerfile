FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache python3 make g++
COPY package.json package-lock.json* ./
RUN npm install
COPY . .

ENV MEDUSA_ADMIN_BACKEND_URL=http://localhost
ENV REDIS_URL=redis://redis:6379

RUN npm run build && npx medusa build
RUN cd /app/.medusa/server && npm install --omit=dev
EXPOSE 9000
CMD ["sh", "-c", "npx medusa db:migrate && cd /app/.medusa/server && npx medusa start"]