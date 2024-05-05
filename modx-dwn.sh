#!/bin/bash

# Переменные по умолчанию
MODX_VERSION=""
DIST_DIR=""
INIT_MOXI=""

# Функция для вывода помощи
function showHelp() {
    echo "---"
    echo "Пример использования: $0 -v 2 -d ./www"
    echo "Опции:"
    echo "  -v <2|3>        - Выбор последней версии MODX Revolution (2.x или 3.x)"
    echo "  -d <PATH_DIR>   - Целевая директория для установки MODX Revolution"
    echo "  -x <y|n>        - После загрузки modx требуется ли загрузить moxi"
    echo "  -h              - Вывод этой помощи"
    echo "---"
}

# Обработка аргументов
while getopts ":v:d:h:x:" opt; do
    case $opt in
        v)
            if [[ "$OPTARG" == "2" || "$OPTARG" == "3" ]]; then
                MODX_VERSION=$OPTARG
            else
                echo "Неизвестный значение флага версии modx"
                showHelp
                exit 1
            fi
            ;;
        x)
            if [[ "$OPTARG" == "y" || "$OPTARG" == "n" ]]; then
                INIT_MOXI=$OPTARG
            else
                echo "Неизвестное значение флага инициализации moxi"
                showHelp
                exit 1
            fi
            ;;
        d) DIST_DIR=$OPTARG
        ;;
        c) COMPOSER_PATH=$OPTARG
        ;;
        h)
            showHelp
            exit 1
            ;;
        * )
            echo "Неизвестный флаг $opt $OPTARG"
            showHelp
            exit 1
            ;;
    esac
done

# Очистка остатков опций
shift $((OPTIND-1))

if [ -z "$DIST_DIR" ]; then
    read -p "Введите путь к директории для установки: " DIST_DIR
    if [ ! -d "$DIST_DIR" ]; then
        echo "Ошибка: Папка '$DIST_DIR' не существует."
        exit 1
    fi

    if [ "$(ls -A "$DIST_DIR")" ]; then
        echo "Ошибка: Папка '$DIST_DIR' не пуста."
        exit 1
    fi

    if [ -z "$DIST_DIR" ]; then
        echo "Не указан путь к директории для установки. Установка не будет продолжена."
        exit 1
    fi
fi

VERSIONS=$(wget -qO- https://repo.packagist.org/p2/modx/revolution.json | grep -o '"version":"v[0-9.]\{1,\}-pl",' | cut -d '"' -f4 | sed 's/^v//; s/-pl$//')

latest_versions_3=$(echo "$VERSIONS" | grep "^3" | sort -V | tail -n 3)
latest_versions_2=$(echo "$VERSIONS" | grep '^2' | sort -V | tail -n 3)
mapfile -t options < <(echo "$latest_versions_3"; echo "$latest_versions_2")
options=($(printf "%s\n" "${options[@]}" | sort -rV))

# Если MODX_VERSION уже задана, выбираем самую новую версию из списка
if [[ "$MODX_VERSION" == "2" ]]; then
    MODX_VERSION=$(echo "$latest_versions_2" | tail -n 1)
elif [[ "$MODX_VERSION" == "3" ]]; then
    MODX_VERSION=$(echo "$latest_versions_3" | tail -n 1)
else
    echo "Выберите версию modx:"
    i=1
    for option in "${options[@]}"; do
        echo "$i) $option"
        ((i++))
    done

    while true; do
        read -p "Введите номер версии: " selection
        if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le "${#options[@]}" ]]; then
            MODX_VERSION=${options[$((selection-1))]}
            break
        else
            echo "Ошибка: Неверный ввод. Введите номер из списка."
        fi
    done
fi

ZIP_NAME="./dwn-modx-${MODX_VERSION}.zip"
ZIP_DIR="./dwn-modx-${MODX_VERSION}"
modx_url="https://modx.s3.amazonaws.com/releases/${MODX_VERSION}/modx-${MODX_VERSION}-pl.zip"
if wget --spider "$modx_url" 2>/dev/null; then
    wget "$modx_url" -O $ZIP_NAME
    unzip $ZIP_NAME -d $ZIP_DIR && rm $ZIP_NAME
    cp -R "${ZIP_DIR}"/*/* "${DIST_DIR}" && rm -rf "${ZIP_DIR}"
    echo "Загрузка MODX $MODX_VERSION в папку '$DIST_DIR' завершена."
else
    echo "Ошибка: Ссылка на версию $MODX_VERSION не существует."
    exit 1
fi

# MOXI
if [[ "$INIT_MOXI" != "n" ]]; then
    if [[ "$INIT_MOXI" != "y" ]]; then
        read -p "Хотите ли вы загрузить moxi в папку '$DIST_DIR'? (Y/n): " INIT_MOXI
    fi
    case $INIT_MOXI in
        [Yy]*|"") git clone https://github.com/alexsoin/moxi.git "$DIST_DIR/moxi" ;;
    esac
fi
