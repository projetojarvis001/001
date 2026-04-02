FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache git openssh-client postgresql-client redis
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["node", "dist/server.js"]
