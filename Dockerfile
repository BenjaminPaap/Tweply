FROM nginx:alpine

COPY web/ /usr/share/nginx/html/
COPY dist/Tweply.zip /usr/share/nginx/html/Tweply.zip

EXPOSE 80
