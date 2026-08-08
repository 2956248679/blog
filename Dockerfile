FROM hugomods/hugo:exts as builder

WORKDIR /src
COPY . /src

RUN hugo --minify

FROM nginx:1.27-alpine
COPY --from=builder /src/public /usr/share/nginx/html
COPY nginx/blog.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
