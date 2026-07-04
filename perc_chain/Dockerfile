FROM node:20-alpine
WORKDIR /app
COPY package.json ./
COPY src ./src
ENV PERC_RENDEZVOUS_PORT=9478
EXPOSE 9478
CMD ["npm", "run", "start:rendezvous"]