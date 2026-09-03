FROM node:20

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY tsconfig.json eslint.config.js ./
COPY src ./src

RUN npm run build

ENV NODE_ENV=production

CMD ["npm", "run", "start"]
