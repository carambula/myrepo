FROM node:20

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY tsconfig.json eslint.config.js ./
COPY src ./src

ENV NODE_ENV=production

CMD ["npm", "run", "bootstrap"]
