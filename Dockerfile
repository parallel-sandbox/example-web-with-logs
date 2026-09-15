FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json build.mjs ./
COPY src ./src
RUN npm ci --no-audit --no-fund
ARG PSBX_RELEASE=dev
RUN PSBX_RELEASE=$PSBX_RELEASE npm run build

FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/40-write-config.sh /docker-entrypoint.d/40-write-config.sh
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
