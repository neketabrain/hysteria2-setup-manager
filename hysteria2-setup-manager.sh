#!/bin/bash
# =========================================
# Hysteria2 Setup Manager by neketabrain
# =========================================

SYSTEMD_SERVICE_PATH="/etc/systemd/system/hysteria-server.service"
HYSTERIA2_CONFIG_PATH="/etc/hysteria/config.json"
HYSTERIA2_YAML_CONFIG_PATH="/etc/hysteria/config.yaml"
FALLBACK_DIR_PATH="/var/www/masq"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NO_COLOR='\033[0m'

ColorRed() {
  echo -ne "${RED}${1}${NO_COLOR}"
}
ColorGreen() {
  echo -ne "${GREEN}${1}${NO_COLOR}"
}
ColorBlue() {
  echo -ne "${BLUE}${1}${NO_COLOR}"
}
ColorGray() {
  echo -ne "${GRAY}${1}${NO_COLOR}"
}

function confirm_action() {
  read -p "$1 (y/n): " response
  case "$response" in
    [Yy][Ee][Ss]|[Yy]) return 0 ;;
    *) return 1 ;;
  esac
}

function check_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "$(ColorRed 'Для корректной работы скрипта требуется библиотека jq')"
    return 1
  fi
}

function install_jq() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y jq

  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y jq

  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y jq

  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm jq

  elif command -v apk >/dev/null 2>&1; then
    sudo apk add jq

  elif command -v brew >/dev/null 2>&1; then
    brew install jq

  else
    echo "$(ColorRed 'Не удалось определить пакетный менеджер. Установите jq вручную.')"
    return 1
  fi
}

function press_any_key() {
  echo ""
  read -n 1 -s -r -p "$(ColorGray 'Нажмите любую кнопку, чтобы продолжить...')"
  echo ""
  echo ""
  echo ""
}

function start_hysteria2() {
  echo ""
  echo "Запускаю сервис..."

  if ! output1=$(systemctl daemon-reload 2>&1); then
    echo -e "${RED}${output1}${NO_COLOR}"
    return 1
  fi

  if ! output2=$(systemctl enable --now hysteria-server.service 2>&1); then
    echo -e "${RED}${output2}${NO_COLOR}"
    return 1
  fi

  echo "$(ColorGreen 'Готово! Сервис Hysteria2 запущен')"
}

function stop_hysteria2() {
  echo ""
  echo "Останавливаю сервис..."

  if ! output=$(systemctl disable --now hysteria-server.service 2>&1); then
    echo -e "${RED}${output}${NO_COLOR}"
    return 1
  fi

  echo "$(ColorGreen 'Готово! Сервис Hysteria2 остановлен')"
}

function restart_hysteria2() {
  echo ""
  echo "Начинаю перезапуск сервиса..."

  if ! output=$(systemctl restart hysteria-server.service 2>&1); then
    echo -e "${RED}${output}${NO_COLOR}"
    return 1
  fi

  echo "$(ColorGreen 'Готово! Сервис Hysteria2 перезапущен')"
}

function set_domain() {
  check_jq

  echo ""
  echo -ne "$(ColorBlue 'Введите ваш домен (example.com):') "
  read DOMAIN

  tmp=$(mktemp)

  if output=$(jq -e --arg domain "$DOMAIN" '.acme.domains[0] = $domain' $HYSTERIA2_CONFIG_PATH > $tmp && mv $tmp $HYSTERIA2_CONFIG_PATH 2>&1); then
    echo "Домен $(ColorBlue $DOMAIN) установлен"
  else
    echo -e "${RED}${output}${NO_COLOR}"
  fi
}

function set_email() {
  check_jq

  echo ""
  echo -ne "$(ColorBlue 'Введите ваш E-mail (your@email.com):') "
  read EMAIL

  tmp=$(mktemp)

  if output=$(jq -e --arg email "$EMAIL" '.acme.email = $email' $HYSTERIA2_CONFIG_PATH > $tmp && mv $tmp $HYSTERIA2_CONFIG_PATH 2>&1); then
    echo "E-mail $(ColorBlue $EMAIL) установлен"
  else
    echo -e "${RED}${output}${NO_COLOR}"
  fi
}

function add_user() {
  check_jq

  echo ""
  echo -ne "$(ColorBlue 'Введите имя нового пользователя:') "
  read USERNAME

  if jq -e ".auth.userpass | has(\"$USERNAME\")" "$HYSTERIA2_CONFIG_PATH" >/dev/null; then
    echo "$(ColorRed 'Пользователь с таким именем уже существует')"
    return 1
  fi

  echo ""
  echo -ne "$(ColorBlue 'Введите пароль нового пользователя:') "
  read PASSWORD

  tmp=$(mktemp)

  if output=$(jq -e --arg user "$USERNAME" --arg password "$PASSWORD" '.auth.userpass[$user] = $password' $HYSTERIA2_CONFIG_PATH > $tmp && mv $tmp $HYSTERIA2_CONFIG_PATH 2>&1); then
    echo "Пользователь $(ColorBlue $USERNAME) добавлен"
  else
    echo -e "${RED}${output}${NO_COLOR}"
  fi
}

function delete_user() {
  check_jq

  echo ""
  echo -ne "$(ColorBlue 'Введите имя пользователя:') "
  read USERNAME

  if ! jq -e ".auth.userpass | has(\"$USERNAME\")" "$HYSTERIA2_CONFIG_PATH" >/dev/null; then
    echo "$(ColorRed 'Пользователя с таким именем не существует')"
    return 1
  fi

  tmp=$(mktemp)

  if output=$(jq -e --arg user "$USERNAME" '.auth.userpass |= del(.[$user])' $HYSTERIA2_CONFIG_PATH > $tmp && mv $tmp $HYSTERIA2_CONFIG_PATH 2>&1); then
    echo "Пользователь $(ColorBlue $USERNAME) удален"
  else
    echo -e "${RED}${output}${NO_COLOR}"
  fi
}

function get_users() {
  check_jq

  echo ""
  echo "Список пользователей: "
  echo "$(jq -e -r '.auth.userpass | to_entries[] | "\(.key) : \(.value)"' $HYSTERIA2_CONFIG_PATH)"
}

function get_user_link() {
  check_jq

  echo ""
  echo -ne "$(ColorBlue 'Введите имя нового пользователя:') "
  read USERNAME

  PASSWORD=$(jq -e -r --arg user "$USERNAME" '.auth.userpass[$user]' "$HYSTERIA2_CONFIG_PATH")

  if [[ "$PASSWORD" == "null" || -z "$PASSWORD" ]]; then
    echo "$(ColorRed 'Пользователя с таким именем не существует')"
    return 1
  fi

  DOMAIN=$(jq -e -r '.acme.domains[0]' "$HYSTERIA2_CONFIG_PATH")

  if [[ "$DOMAIN" == "null" || -z "$DOMAIN" ]]; then
    echo "$(ColorRed 'Не удалось сформировать ссылку, так как домен не установлен')"
    return 1
  fi

  echo -e "Ссылка: ${BLUE}hy2://${USERNAME}:${PASSWORD}@${DOMAIN}:443?sni=${DOMAIN}&alpn=h3&insecure=0&allowInsecure=0#${USERNAME}${NO_COLOR}"
}

function install_hysteria2() {
  echo ""
  echo "Начинаю установку..."

  if ! command -v jq >/dev/null 2>&1; then
    install_jq
  fi

  if ! output=$(bash <(curl -fsSL https://get.hy2.sh/) 2>&1); then
    echo -e "${RED}${output}${NO_COLOR}"
    return 1
  fi

  mkdir -p $FALLBACK_DIR_PATH || true
  rm -rf $HYSTERIA2_YAML_CONFIG_PATH || true

  wget -qO $HYSTERIA2_CONFIG_PATH https://raw.githubusercontent.com/neketabrain/hysteria2-setup-manager/main/configs/config.json
  wget -qO $FALLBACK_DIR_PATH/index.html https://raw.githubusercontent.com/neketabrain/hysteria2-setup-manager/main/configs/index.html

  chmod 600 $HYSTERIA2_CONFIG_PATH
  chgrp hysteria $HYSTERIA2_CONFIG_PATH
  chown hysteria:hysteria $HYSTERIA2_CONFIG_PATH

  systemctl daemon-reload
  sed -i'' -e "s|${HYSTERIA2_YAML_CONFIG_PATH}|${HYSTERIA2_CONFIG_PATH}|g" $SYSTEMD_SERVICE_PATH

  echo "$(ColorGreen 'Готово! Hysteria2 установлена')"

  set_domain
  set_email
  start_hysteria2
}

function remove_hysteria2() {
  stop_hysteria2

  echo ""
  echo "Начинаю удаление..."

  if ! output=$(bash <(curl -fsSL https://get.hy2.sh/) --remove 2>&1); then
    echo -e "${RED}${output}${NO_COLOR}"
    return 1
  fi

  echo "$(ColorGreen 'Готово! Hysteria2 удалена')"
}

function menu() {
  echo -ne "
  \033[1mHysteria2 Setup Manager\033[0m

  $(ColorGreen ' 1)') Установить или обновить Hysteria2
  $(ColorGreen ' 2)') Удалить Hysteria2
  $(ColorGreen ' 3)') Получить ссылку для подключения
  $(ColorGreen ' 4)') Добавить пользователя
  $(ColorGreen ' 5)') Удалить пользователя
  $(ColorGreen ' 6)') Посмотреть список пользователей
  $(ColorGreen ' 7)') Перезапустить сервис Hysteria2
  $(ColorGreen ' 8)') Остановить сервис Hysteria2
  $(ColorGreen ' 9)') Запустить сервис Hysteria2
  $(ColorGreen '10)') Изменить домен
  $(ColorGreen '11)') Изменить E-mail
  $(ColorGreen ' 0)') Выход

  $(ColorBlue 'Выберите пункт меню:') "

  read a
  case $a in
    1) install_hysteria2 ; press_any_key ; menu ;;
    2) remove_hysteria2 ; press_any_key ; menu ;;
    3) get_user_link ; press_any_key ; menu ;;
    4) add_user ; press_any_key ; menu ;;
    5) delete_user ; press_any_key ; menu ;;
    6) get_users ; press_any_key ; menu ;;
    7) restart_hysteria2 ; press_any_key ; menu ;;
    8) stop_hysteria2 ; press_any_key ; menu ;;
    9) start_hysteria2 ; press_any_key ; menu ;;
    10) set_domain ; press_any_key ; menu ;;
    11) set_email ; press_any_key ; menu ;;
    0) exit 0 ;;
    *) echo -e "$(ColorRed 'Такого пункта меню не существует')" ; press_any_key ; menu ;;
  esac
}

menu
