# Railway GitHub deploys from the monorepo root. Min Cloud lives in
# services/min-cloud; `railway up` from that directory still uses
# services/min-cloud/Dockerfile.
FROM node:22-bookworm-slim

WORKDIR /app

COPY services/min-cloud/package.json services/min-cloud/package-lock.json* ./
RUN npm install

COPY services/min-cloud/tsconfig.json ./
COPY services/min-cloud/src ./src
COPY services/min-cloud/db ./db
COPY services/min-cloud/public ./public
COPY services/min-cloud/fixtures ./fixtures

RUN npm run build

ENV NODE_ENV=production
EXPOSE 4000

CMD ["npm", "run", "start"]
