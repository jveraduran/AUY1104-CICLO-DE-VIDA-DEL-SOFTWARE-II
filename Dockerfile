FROM node:20-slim AS build

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --only=production

COPY index.js ./

FROM node:20-slim AS production

ENV NODE_ENV production
WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/index.js ./

EXPOSE 3000

CMD ["node", "index.js"]