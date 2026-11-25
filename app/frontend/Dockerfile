# frontend/Dockerfile
FROM node:18

WORKDIR /app

COPY . .

RUN npm install
RUN npm run build

# Use a lightweight web server to serve React
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=0 /app/build /usr/share/nginx/html

EXPOSE 80

