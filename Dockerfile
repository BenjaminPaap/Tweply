FROM nginx:alpine

ARG VERSION=dev
ARG APP_VERSION=0.0.0

COPY web/ /usr/share/nginx/html/
COPY dist/Tweply.zip /usr/share/nginx/html/Tweply.zip

# Inject build SHA into the landing page
RUN sed -i "s/__VERSION__/${VERSION}/g" /usr/share/nginx/html/index.html

# Generate version endpoint consumed by the in-app update checker
RUN printf '{"version":"%s","url":"https://tweply.paap.one/Tweply.zip"}' "${APP_VERSION}" \
    > /usr/share/nginx/html/version.json

EXPOSE 80
