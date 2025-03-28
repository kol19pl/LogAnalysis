#!/bin/bash

# Sprawdzenie, czy podano plik źródłowy
if [[ -z "$1" ]]; then
    echo "Błąd: Nie podano pliku źródłowego."
    echo "Użycie: $0 <plik.c>"
    exit 1
fi

SOURCE_FILE="$1"
CONFIG_FILE="lib_mappings.conf"

# Sprawdzenie, czy plik istnieje
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Błąd: Plik '$SOURCE_FILE' nie istnieje."
    exit 1
fi

# Sprawdzenie, czy plik konfiguracyjny istnieje
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Błąd: Plik konfiguracji '$CONFIG_FILE' nie istnieje!"
    exit 1
fi

# Wczytaj mapowania nagłówków do bibliotek
declare -A LIBRARY_MAP
while IFS="=" read -r header lib; do
    LIBRARY_MAP["$header"]="$lib"
done < <(grep -vE '^\s*#' "$CONFIG_FILE" | grep '=')

# Wyszukiwanie nagłówków i obsługa warunkowych dyrektyw
detect_libraries() {
    local source_file=$1
    local libraries=()
    local inside_conditional=0

    while IFS= read -r line; do
        # Obsługa dyrektyw warunkowych
        if [[ "$line" =~ ^\s*#(ifdef|ifndef|if) ]]; then
            inside_conditional=1
            continue
        elif [[ "$line" =~ ^\s*#endif ]]; then
            inside_conditional=0
            continue
        fi

        # Wyszukiwanie #include
        if [[ "$line" =~ "#include"[[:space:]]*"<"([^>]+)">" ]] || [[ "$line" =~ "#include"[[:space:]]*"\""([^\"]+)"\"" ]]; then
            header="${BASH_REMATCH[1]}"
            if [[ $inside_conditional -eq 0 && -n "${LIBRARY_MAP[$header]}" ]]; then
                libraries+=("${LIBRARY_MAP[$header]}")
            fi
        fi
    done < "$source_file"

    # Deduplikacja i zwrócenie bibliotek
    echo "${libraries[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# Uruchomienie wykrywania
detect_libraries "$SOURCE_FILE"
echo