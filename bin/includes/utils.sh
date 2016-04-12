#!/bin/bash
function msg_info {
  echo "$1"
}

function msg_warning {
  echo -e "\e[01;33m${1}\e[00m"
}

function msg_error {
  echo -e "\e[00;31m${1}\e[00m"
}

function msg_debug {
  echo -e "\e[00;45m${1}\e[00m"
}

function docker-get-running-container-name() {
  local CONTAINER
  CONTAINER=$(docker inspect --format '{{ .Name }}' $(docker ps -q | head -1))
  echo "${CONTAINER#/}"
}

function docker-exec-in-container() {
  local CONTAINER_NAME
  local ACTION
  local ARGS
  CONTAINER_NAME=$1
  shift
  ACTION=$1
  shift

  docker exec -ti "$CONTAINER_NAME" /usr/bin/docker-cmd "$ACTION" $*
}

function docker-export-container() {
  local IMAGE
  IMAGE=$1
  docker save -o "${IMAGE}.tar" "$IMAGE"
  gzip "${IMAGE}.tar"
}

function docker-setup() {
  declare -a REQUIRED_CMD
  local CMD
  local ERROR
  ERROR=0
  REQUIRED_CMD=('docker' 'docker-compose')

  msg_info "Checking for required commands"
  for CMD in "${REQUIRED_CMD[@]}"; do
    if ! command -v "$CMD" &>/dev/null; then
      msg_error "\tMissing command: $CMD"
      ERROR=1
    fi
  done

  if [[ $ERROR -gt 0 ]]; then
    msg_error "Setup did not succeed"
    exit 1
  fi

  touch "${WORK_DIR}/.setup-ok"
}

function docker-stop-all() {
  # TODO: replace with docker-compose stop?
  local RUNNING_CONTAINERS
  RUNNING_CONTAINERS=$(docker ps -q)
  # Suppress error if no containers are running by checking var first
  # Strip spaces
  if [[ ! -z "${RUNNING_CONTAINERS// }" ]]; then
    msg_info "Stopping all running containers:"
    docker stop $RUNNING_CONTAINERS
  fi
}

function docker-check-existing() {
  local NAME
  local RUNNING
  NAME=$1
  # Returns true if running, false if not, and exit status is 1 if no container with $NAME exists
  RUNNING=$(docker inspect --format="{{ .State.Running }}" "$NAME" 2> /dev/null)
  return $?
}

function docker-start() {
  local CONTAINER_NAME
  CONTAINER_NAME=$1
  cd "${CONTAINER_DIR}"

  docker-compose up "$CONTAINER_NAME"
}

function usage() {
  echo "pilotboat [ACTION]"
  echo ""
  echo "Avaliable actions:"
  echo -e "\tstart\t\t: Starts a container, see container dir for avaliable containers"
  echo -e "\tsite-create [TYPE]\t: Creates a virtual host in $VHOST_DIR and directory structure in $SITE_DIR\nTYPE is optional, but can be one of: Drupal7, Drupal8, Wordpress or Prestashop"
  echo -e "\tdb-import\t: Imports a MySQL database dump. Note: be sure not to overwrite existing databases"
  echo -e "\tapache-reload\t: Restarts Apache in the container, for example to load a new virtual host"
  echo -e "\tshell\t\t: Executes an interactive shell inside the container"
  echo -e "\texport\t\t: Exports a container to a tar file"
}

function site-create() {
  local SITE_NAME
  local SITE_TYPE
  SITE_NAME=$1
  SITE_TYPE=${2:-}
  if [[ -d "$SITE_DIR/$SITE_NAME" ]]; then
    msg_error "$SITE_DIR/$SITE_NAME exists"
    exit 1
  fi

  if [[ -f "$VHOST_DIR/${SITE_NAME}.conf" ]]; then
    msg_error "$VHOST_DIR/${SITE_NAME}.conf exists"
    exit 1
  fi

  if [[ ! -z "$SITE_TYPE" ]]; then
    declare -A SUPPORTED_SITE_TYPES=( [DRUPAL7]=1 [DRUPAL8]=1 [WORDPRESS]=1 [PRESTASHOP]=1 )
    if [[ ! ${SUPPORTED_SITE_TYPES[${SITE_TYPE^^}]} ]]; then
      msg_error "Unknown site type $SITE_TYPE"
      exit 1
    fi
  fi

  site-create-dirs "$SITE_NAME"
  site-create-vhost "$SITE_NAME"

  if [[ ! -z "$SITE_TYPE" ]]; then
    local CONTAINER_NAME
    CONTAINER_NAME=$(docker-get-running-container-name)

    case "${SITE_TYPE^^}" in
      DRUPAL7)
        docker-exec-in-container "$CONTAINER_NAME" site-create-drupal "$SITE_NAME"
        ;;
      DRUPAL8)
        docker-exec-in-container "$CONTAINER_NAME" site-create-drupal "$SITE_NAME" "8"
        ;;
      WORDPRESS)
        docker-exec-in-container "$CONTAINER_NAME" site-create-wordpress "$SITE_NAME"
        ;;
      PRESTASHOP)
        prestashop-download-latest "$SITE_NAME"
        docker-exec-in-container "$CONTAINER_NAME" site-create-prestashop "$SITE_NAME"
        ;;
    esac
  fi
  apache-reload
}

function site-create-drupal() {
    local SITE_NAME
    local DRUPAL_VERSION
    local DATABASE_NAME
    SITE_NAME=${1}
    # Default to version 7
    DRUPAL_VERSION=${2:-7}
    DATABASE_NAME=$(db-get-clean-name "$SITE_NAME")
    cd "/var/www/${SITE_NAME}/"
    rmdir public_html
    msg_info "Creating Drupal ${DRUPAL_VERSION} site"
    drush dl "drupal-${DRUPAL_VERSION}" --drupal-project-rename=public_html -y
    cd public_html
    drush site-install standard --account-name=admin --account-pass=admin --db-url=mysql://root:${MYSQL_PASS}@localhost/"${DATABASE_NAME}" --site-name="$SITE_NAME" -y
    case $DRUPAL_VERSION in
      7)
        drush -y vset file_temporary_path "/var/www/${SITE_NAME}/tmp"
        ;;
      8)
        drush -y config-set system.file path.temporary "/var/www/${SITE_NAME}/tmp/"
    esac
}

function site-create-wordpress() {
  local SITE_NAME
  local DATABASE_NAME
  SITE_NAME=${1}
  DATABASE_NAME=$(db-get-clean-name "$SITE_NAME")
  cd "/var/www/${SITE_NAME}/public_html"
  msg_info "Creating Wordpress site"
  wp core download --allow-root
  wp core config --dbhost=localhost --dbname="$DATABASE_NAME" --dbuser=root --dbpass=root --allow-root
  wp db create --allow-root
  chmod 600 wp-config.php
  wp core install --url="$SITE_NAME" --title="$SITE_NAME" --admin_name=admin --admin_password=admin --admin_email="admin@${SITE_NAME}" --allow-root
  msg_info "Removing wp cli cache"
  rm -rf /root/.wp-cli/cache
}

function site-create-prestashop() {
  local SITE_NAME
  local DATABASE_NAME
  SITE_NAME=${1}
  DATABASE_NAME=$(db-get-clean-name "$SITE_NAME")
  cd "/var/www/${SITE_NAME}/public_html/install"
  msg_info "Creating Prestashop site"
  db-create "$DATABASE_NAME"
  php index_cli.php --domain="$SITE_NAME" --db_server=localhost --db_name="$DATABASE_NAME" --db_user=root --db_password=root --email="admin@${SITE_NAME}"
  cd ..
  rm -rf install
}

function site-create-vhost() {
  local SITE_NAME
  SITE_NAME=$1
  sed -re "s/\[DOMAIN.TLD\]/$SITE_NAME/" "${WORK_DIR}/bin/includes/vhost.tpl" > "${VHOST_DIR}/${SITE_NAME}.conf"
}

function site-create-dirs() {
  local SITE_NAME
  SITE_NAME=$1
  mkdir -p "${SITE_DIR}/${SITE_NAME}"/{public_html,logs,sessions,upload,tmp}
}

function site-fix-permissions() {
  msg_info "Setting group to www-data, rwX permissions and group sticky bit on dirs"
  local SITE_NAME
  SITE_NAME=$1
  chgrp -R www-data "/var/www/${SITE_NAME}"
  chmod -R g+rwX "/var/www/${SITE_NAME}"
  find "/var/www/${SITE_NAME}" -type d -exec chmod g+s "{}" \;
}

function apache-reload() {
  local CONTAINER_NAME
  CONTAINER_NAME=$(docker-get-running-container-name)
  docker-exec-in-container "$CONTAINER_NAME" apache-reload
}

function prestashop-download-latest() {
  msg_info "Downloading latest release of Prestashop"
  local SITE_NAME
  SITE_NAME=$1
  cd "${WORK_DIR}sites/${SITE_NAME}"
  rmdir public_html
  # From http://stackoverflow.com/questions/24085978/github-url-for-latest-release-of-the-download-file because providing a direct link is hard...
  curl -o latest.zip -L $(curl -s https://api.github.com/repos/PrestaShop/PrestaShop/releases/latest | grep 'browser_' | cut -d\" -f4)
  unzip latest.zip
  rm latest.zip
  mv prestashop public_html
}

function db-get-clean-name() {
  local SITE_NAME
  SITE_NAME=${1}
  # Lowercase and replace " " and . with _
  DATABASE_NAME=${SITE_NAME,,}
  DATABASE_NAME=${DATABASE_NAME//./_}
  DATABASE_NAME=${DATABASE_NAME// /_}
  echo $DATABASE_NAME
}

function db-create() {
  local DATABASE_NAME
  DATABASE_NAME=$1
  msg_info "Creating db with name $DATABASE_NAME"
  mysql -e "CREATE DATABASE \`$DATABASE_NAME\`"
}
