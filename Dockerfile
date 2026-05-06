FROM nginx:alpine

ARG VERSION=dev

COPY web/ /usr/share/nginx/html/
COPY dist/Tweply.zip /usr/share/nginx/html/Tweply.zip

# Inject build version into the page
RUN sed -i "s/__VERSION__/${VERSION}/g" /usr/share/nginx/html/index.html

EXPOSE 80
