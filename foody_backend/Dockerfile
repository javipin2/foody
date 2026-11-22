FROM node:20-bookworm-slim AS build
WORKDIR /app
COPY package*.json ./
# ponytail: npm install en imagen linux — package-lock de Windows no trae opcionales sharp/@emnapi
RUN npm install
COPY . .
RUN npm run build

FROM node:20-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm install --omit=dev
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main.js"]
