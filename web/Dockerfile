FROM node:20-alpine
WORKDIR /app

# Cai dat dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy ma nguon
COPY . .

# Tao thu muc uploads va dam bao quyen ghi
RUN mkdir -p /app/public/uploads && chown -R node:node /app

EXPOSE 3000

CMD ["node", "src/server.js"]
