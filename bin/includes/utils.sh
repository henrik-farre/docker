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

  msg_info "Checking for configured docker.env file"
  if [[ ! -f "${CONTAINER_DIR}/docker.env" ]]; then
    msg_error "\tYou need to copy ${CONTAINER_DIR}/docker.env.skel to ${CONTAINER_DIR}/docker.env"
    ERROR=1
  fi

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

function docker-exec-shell() {
  local CONTAINER_NAME
  local USER
  USER=$1
  CONTAINER_NAME=$(docker-get-running-container-name)

  if [[ "${USER}" == 'root' ]]; then
    docker exec -ti "$CONTAINER_NAME" bash
  elif [[ "${USER}" == 'www-data' ]]; then
    docker exec -tiu www-data php-dev-debian-jessie bash
  else
    msg_error "Not supported user '${USER}', use root or www-data (default)"
    exit 1
  fi
}

function usage() {
  echo "pilotboat [ACTION]"
  echo ""
  echo "Avaliable actions:"
  echo -e "\tstart\t\t\t: Starts a container, see container dir for avaliable containers"
  echo -e "\tsite-create [DOMAIN] [TYPE]\t: Creates a virtual host in $VHOST_DIR and directory structure in $SITE_DIR\nTYPE is optional, but can be one of: Drupal7, Drupal8, Wordpress, Prestashop or Symfony"
  echo -e "\tsite-remove [DOMAIN]\t: Creates a virtual host in $VHOST_DIR and directory structure in $SITE_DIR\nTYPE is optional, but can be one of: Drupal7, Drupal8, Wordpress, Prestashop or Symfony"
  echo -e "\tsite-set-permissions [SITE_NAME]: sets the file permissions of the site to your current user and the group to www-data"
  echo -e "\tdb-import\t\t: Imports a MySQL database dump. Note: be sure not to overwrite existing databases"
  echo -e "\twebserver-reload\t\t: Restarts the webserver (Apache/Nginx) in the container, for example to load a new virtual host"
  echo -e "\tshell [USER]\t\t\t: Executes an interactive shell inside the container. USER is default www-data, root is currently the only other option"
  echo -e "\texport\t\t\t: Exports a container to a tar file"
  echo -e "\tblackfire-curl [URL]\t: Call blackfire curl for URL"
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

  # If no site type is set, we just create an empty public_html
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
      SYMFONY)
        docker-exec-in-container "$CONTAINER_NAME" site-create-symfony "$SITE_NAME"
        ;;
      *)
        msg_error "Unknown site type $SITE_TYPE"
        exit 1
        ;;
    esac
  fi

  # TODO: support Nginx
  site-create-apache-vhost "${SITE_NAME}" "${SITE_TYPE^^}"

  # Use EUID of the user outside of docker
  docker-exec-in-container "$CONTAINER_NAME" site-set-permissions "$EUID" "www-data" "$SITE_NAME"
  webserver-reload
}

function site-remove() {
  local SITE_NAME
  local DATABASE_NAME
  local CONTAINER_NAME
  local REMOVE_SITE
  local REMOVE_DB
  local REMOVE_VHOST

  SITE_NAME=$1
  DATABASE_NAME=$(db-get-clean-name "$SITE_NAME")
  CONTAINER_NAME=$(docker-get-running-container-name)

  if [[ ! -d "$SITE_DIR/$SITE_NAME" ]]; then
    msg_error "site does not exist at $SITE_DIR/$SITE_NAME, will try to remove database and vhost"
    REMOVE_SITE="n"
  else
    read -p "Confirm that you want to delete everything at $SITE_DIR/$SITE_NAME (Y/n):" REMOVE_SITE
  fi

  read -p "Confirm that you want to drop the database $DATABASE_NAME (Y/n):" REMOVE_DB
  read -p "Confirm that you want to remove the virtual host $VHOST_DIR/${SITE_NAME}.conf (Y/n):" REMOVE_VHOST

  if [[ "${REMOVE_SITE:-y}" == "y" ]]; then
    docker-exec-in-container "$CONTAINER_NAME" site-remove-dirs "$SITE_NAME"
  fi

  if [[ "${REMOVE_DB:-y}" == "y" ]]; then
    docker-exec-in-container "$CONTAINER_NAME" db-drop "$DATABASE_NAME"
  fi

  if [[ "${REMOVE_VHOST:-y}" == "y" ]]; then
    msg_info "Removing $VHOST_DIR/${SITE_NAME}.conf"
    rm "$VHOST_DIR/${SITE_NAME}.conf"
  fi

  webserver-reload
}

function site-remove-dirs() {
    local SITE_NAME
    SITE_NAME=${1}
    msg_info "Removing /var/www/$SITE_NAME"
    rm -rf "/var/www/${SITE_NAME:?}"
}

function site-create-drupal() {
    local SITE_NAME
    local DRUPAL_VERSION
    local DATABASE_NAME
    SITE_NAME=${1}
    # Default to version 7
    DRUPAL_VERSION=${2:-7}
    DATABASE_NAME=$(db-get-clean-name "$SITE_NAME")

    site-create-dirs "${SITE_NAME}"
    cd "/var/www/${SITE_NAME}/"
    rmdir public_html

    msg_info "Creating Drupal ${DRUPAL_VERSION} site"
    drush dl "drupal-${DRUPAL_VERSION}" --drupal-project-rename=public_html -y
    cd public_html
    drush site-install standard --account-name=admin --account-pass=admin --db-url=mysql://root:${MYSQL_PASS}@${MYSQL_HOST}/"${DATABASE_NAME}" --site-name="$SITE_NAME" -y
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

  site-create-dirs "${SITE_NAME}"
  cd "/var/www/${SITE_NAME}/public_html"

  msg_info "Creating Wordpress site"
  wp core download --allow-root
  wp core config --dbhost=${MYSQL_HOST} --dbname="$DATABASE_NAME" --dbuser=root --dbpass=root --allow-root
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
  php index_cli.php --domain="$SITE_NAME" --db_server=${MYSQL_HOST} --db_name="$DATABASE_NAME" --db_user=root --db_password=root --email="admin@${SITE_NAME}" --password=admin
  cd ..
  rm -rf install
}

function site-create-symfony() {
  local SITE_NAME
  local DATABASE_NAME
  SITE_NAME=${1}
  DATABASE_NAME=$(db-get-clean-name "$SITE_NAME")

  cd "/var/www/"

  msg_info "Creating Symfony site"
  db-create "$DATABASE_NAME"
  symfony new "${SITE_NAME}" -n

  mkdir "/var/www/${SITE_NAME}/"{logs,sessions,upload,tmp}
}

function site-create-apache-vhost() {
  local SITE_NAME
  local SITE_TYPE
  local VHOST_TPL
  SITE_NAME=$1
  SITE_TYPE=$2
  VHOST_TPL="${WORK_DIR}/bin/includes/vhost.tpl"

  if [[ -f "${WORK_DIR}/bin/includes/vhost-${SITE_TYPE}.tpl" ]]; then
    VHOST_TPL="${WORK_DIR}/bin/includes/vhost-${SITE_TYPE}.tpl"
  fi

  sed -re "s/\[DOMAIN.TLD\]/$SITE_NAME/" "${VHOST_TPL}" > "${VHOST_DIR}/${SITE_NAME}.conf"
}

function site-create-dirs() {
  local SITE_NAME
  SITE_NAME=$1
  mkdir -p "/var/www/${SITE_NAME}"/{public_html,logs,sessions,upload,tmp}
}

function site-set-permissions() {
  local OWNER
  local GROUP
  local SITE_NAME
  OWNER=$1
  GROUP=$2
  SITE_NAME=$3

  msg_info "Setting owner to $OWNER, group to $GROUP, rwX permissions and group sticky bit on dirs"
  chgrp -R ${GROUP} "/var/www/${SITE_NAME}"
  chown -R ${OWNER} "/var/www/${SITE_NAME}"
  chmod -R g+rwX "/var/www/${SITE_NAME}"
  find "/var/www/${SITE_NAME}" -type d -exec chmod g+s "{}" \;
}

function webserver-reload() {
  local CONTAINER_NAME
  CONTAINER_NAME=$(docker-get-running-container-name)
  docker-exec-in-container "$CONTAINER_NAME" webserver-reload
}

function prestashop-download-latest() {
  msg_info "Downloading latest release of Prestashop"
  local SITE_NAME
  SITE_NAME=$1

  mkdir -p "${WORK_DIR}sites/${SITE_NAME}"/{logs,sessions,upload,tmp}
  cd "${WORK_DIR}sites/${SITE_NAME}"
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

function db-drop() {
  local DATABASE_NAME
  DATABASE_NAME=$1
  msg_info "Dropping db with name $DATABASE_NAME"
  mysql -e "Drop DATABASE \`$DATABASE_NAME\`"
}

function blackfire-curl() {
  local URL
  URL=$1
  source "${CONTAINER_DIR}/docker.env"
  docker run -it --rm -e BLACKFIRE_CLIENT_ID="${BLACKFIRE_CLIENT_ID}" -e BLACKFIRE_CLIENT_TOKEN="${BLACKFIRE_CLIENT_TOKEN}" blackfire/blackfire blackfire curl "$URL"
}
