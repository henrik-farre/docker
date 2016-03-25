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

  # docker run -d -h "$CONTAINER_SETTING_HOSTNAME" -p 80:80 -p 8025:8025 --volumes-from "$CONTAINER_SETTING_DATA_VOLUME" -v "$WWW_DIR":/var/www -v "$VHOST_DIR":/etc/apache2/sites-enabled --name "$CONTAINER_SETTING_NAME" "$CONTAINER_SETTING_IMAGE"
}
