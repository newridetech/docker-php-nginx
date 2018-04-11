#!/bin/bash
set -e

echoerr() { echo "$@" 1>&2; }

# Split out host and port from DB_HOST env variable
IFS=":" read -r DB_HOST_NAME DB_PORT <<< "$DB_HOST"
DB_PORT=${DB_PORT:-3306}

if [ ! -f "/var/www/.env" ]; then
  if [[ "${DB_HOST}" ]]; then
  cat > "/var/www/.env" <<EOF
      # Environment
      APP_ENV=production
      APP_DEBUG=${APP_DEBUG:-false}
      APP_KEY=${APP_KEY:-SomeRandomStringWith32Characters}

      APP_URL=${APP_URL:-null}

      DB_HOST=${DB_HOST:-db}
      DB_DATABASE=${DB_DATABASE:-homestead}
      DB_USERNAME=${DB_USERNAME:-root}
      DB_PASSWORD=${DB_PASSWORD:-secret}

      # Cache and session
      CACHE_DRIVER=file
      SESSION_DRIVER=file
      # If using Memcached, comment the above and uncomment these
      #CACHE_DRIVER=memcached
      #SESSION_DRIVER=memcached
      QUEUE_DRIVER=sync

      # Memcached settings
      # If using a UNIX socket path for the host, set the port to 0
      # This follows the following format: HOST:PORT:WEIGHT
      # For multiple servers separate with a comma
      MEMCACHED_SERVERS=127.0.0.1:11211:100

      # Storage
      STORAGE_TYPE=${STORAGE_TYPE:-local}
      # Amazon S3 Config
      STORAGE_S3_KEY=${STORAGE_S3_KEY:-false}
      STORAGE_S3_SECRET=${STORAGE_S3_SECRET:-false}
      STORAGE_S3_REGION=${STORAGE_S3_REGION:-false}
      STORAGE_S3_BUCKET=${STORAGE_S3_BUCKET:-false}
      # Storage URL
      # Used to prefix image urls for when using custom domains/cdns
      STORAGE_URL=${STORAGE_URL:-false}

      # General auth
      AUTH_METHOD=${AUTH_METHOD:-standard}

      # Social Authentication information. Defaults as off.
      GITHUB_APP_ID=${GITHUB_APP_ID:-false}
      GITHUB_APP_SECRET=${GITHUB_APP_SECRET:-false}
      GOOGLE_APP_ID=${GOOGLE_APP_ID:-false}
      GOOGLE_APP_SECRET=${GOOGLE_APP_SECRET:-false}

      # External services such as Gravatar
      DISABLE_EXTERNAL_SERVICES=${DISABLE_EXTERNAL_SERVICES:-false}

      # LDAP Settings
      LDAP_SERVER=${LDAP_SERVER:-false}
      LDAP_BASE_DN=${LDAP_BASE_DN:-false}
      LDAP_DN=${LDAP_DN:-false}
      LDAP_PASS=${LDAP_PASS:-false}
      LDAP_USER_FILTER=${LDAP_USER_FILTER:-false}
      LDAP_VERSION=${LDAP_VERSION:-false}

      # Mail settings
      MAIL_DRIVER=${MAIL_DRIVER:-smtp}
      MAIL_HOST=${MAIL_HOST:-localhost}
      MAIL_PORT=${MAIL_PORT:-1025}
      MAIL_USERNAME=${MAIL_USERNAME:-null}
      MAIL_PASSWORD=${MAIL_PASSWORD:-null}
      MAIL_ENCRYPTION=${MAIL_ENCRYPTION:-null}
      # URL used for social login redirects, NO TRAILING SLASH
EOF
sed -ie "s/single/errorlog/g" config/app.php
    else
        echo >&2 'error: missing DB_HOST environment variable'
        exit 1
    fi
fi

echoerr wait-for-db: waiting for ${DB_HOST_NAME}:${DB_PORT}

timeout 15 bash <<EOT
while ! (echo > /dev/tcp/${DB_HOST_NAME}/${DB_PORT}) >/dev/null 2>&1;
    do sleep 1;
done;
EOT
RESULT=$?

if [ $RESULT -eq 0 ]; then
  # sleep another second for so that we don't get a "the database system is starting up" error
  sleep 1
  echoerr wait-for-db: done
else
  echoerr wait-for-db: timeout out after 15 seconds waiting for ${DB_HOST_NAME}:${DB_PORT}
fi

SSL_DOMAIN=${SSL_DOMAIN:-newride.construction}
SSL_REGION=${SSL_REGION:-MAZOVIAN}
SSL_CITY=${SSL_CITY:-Warsaw}
SSL_ORG=${SSL_ORG:-Newride.Tech}
if [[ $SSL_DOMAIN ]]; then
    openssl req -x509 -newkey rsa:4096 -keyout /root/ssl.key -out /root/ssl.crt -days 365 -subj "/C=PL/ST=${SSL_REGION}/L=${SSL_CITY}/O=${SSL_ORG}/OU=${SSL_ORG}/CN=${SSL_DOMAIN}" -nodes
fi

composer install

php artisan key:generate --no-interaction --force

php artisan migrate --no-interaction --force


echo "Setting folder permissions for uploads"
mkdir -p public/uploads && chown -R www-data: public/uploads && chmod -R 775 public/uploads
mkdir -p storage/uploads && chown -R www-data: storage/uploads && chmod -R 775 storage/uploads

php artisan cache:clear

php artisan view:clear

exec "$@"