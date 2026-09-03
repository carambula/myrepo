FROM node:22-bookworm-slim

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src
COPY db ./db
COPY public ./public
COPY fixtures ./fixtures

RUN npm run build

ENV NODE_ENV=production
EXPOSE 4000

CMD ["npm", "run", "start"]
