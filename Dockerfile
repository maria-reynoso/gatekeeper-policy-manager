# Copyright (c) 2022 SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.
FROM node:lts-alpine AS node
COPY app/web-client /web-client
WORKDIR /web-client
RUN yarn install && yarn cache clean && yarn build


FROM python:3.10-slim
LABEL org.opencontainers.vendor="SIGHUP.io"
LABEL org.opencontainers.image.authors="SIGHUP https://sighup.io"
LABEL org.opencontainers.image.source="https://github.com/sighupio/gatekeeper-policy-manager"

RUN groupadd -r gpm && useradd --no-log-init -r -g gpm gpm 
WORKDIR /app
COPY --chown=gpm ./app /app
COPY --from=node --chown=gpm /web-client/build/ /app/static-content/
RUN pip install --no-cache-dir -r /app/requirements.txt

# Remove unused packages
RUN apt-get purge -y --allow-remove-essential \
    openssl \
    gzip

# Remove sensitive data
RUN rm \
    /usr/local/lib/python3.10/site-packages/future/backports/test/ssl_key.pem \
    /usr/local/lib/python3.10/site-packages/future/backports/test/ssl_key.passwd.pem \
    /usr/local/lib/python3.10/site-packages/future/backports/test/keycert.pem \
    /usr/local/lib/python3.10/site-packages/future/backports/test/keycert.passwd.pem \
    /usr/local/lib/python3.10/site-packages/future/backports/test/badcert.pem \
    /usr/local/lib/python3.10/site-packages/future/backports/test/keycert2.pem

USER 999
EXPOSE 8080
CMD ["gunicorn", "--bind=:8080", "--workers=2", "--threads=4", "--worker-class=gthread", "app:app"]
