#!/bin/bash
set -e

# Rozpoczęcie liczenia czasu operacji
start_time=$(date +%s)

# Sprawdzenie, czy skrypt jest uruchamiany z odpowiednimi uprawnieniami
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Ten skrypt musi być uruchomiony jako root. Próbuję ponownie z sudo..."
    sudo bash "$0" "$@"
    exit
fi

# Sprawdzenie, czy katalog SPK_AP_TEMPLATE istnieje
if [ ! -d "SPK_AP_TEMPLATE" ]; then
    echo "ℹ Katalog SPK_AP_TEMPLATE nie istnieje. Upewnij się, że skrypt jest uruchamiany w odpowiednim katalogu."
    exit 1
fi

# Ścieżka do katalogu BIN z plikami do przetworzenia
BIN_DIR="BIN"

# Ścieżka do katalogu, w którym będą przechowywane pliki binarne w pakiecie
TARGET_DIR="SPK_AP_TEMPLATE/pakiet/usr/local/bin"

# Sprawdzenie, czy katalog docelowy istnieje, jeśli nie, tworzymy go
if [ ! -d "$TARGET_DIR" ]; then
    echo "ℹ Katalog $TARGET_DIR nie istnieje. Tworzę katalog."
    mkdir -p "$TARGET_DIR"
fi

# Tablica do przechowywania wyników operacji
successful_operations=()
failed_operations=()

# Sprawdzanie, czy katalog BIN istnieje
if [ ! -d "$BIN_DIR" ]; then
    echo "ℹ Katalog BIN nie istnieje. Upewnij się, że pliki są dostępne w $BIN_DIR."
    read -p "Czy chcesz kontynuować bez plików binarnych? (t/n): " answer
    if [[ "$answer" =~ ^[Tt]$ ]]; then
        echo "ℹ Kontynuuję bez plików binarnych."
        echo "ℹ Uruchamiam skrypt build_spk.sh..."
        bash ./build_spk.sh
        if [ $? -eq 0 ]; then
            echo "ℹ Skrypt build_spk.sh zakończył się pomyślnie."
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            echo "ℹ Czas trwania operacji: $duration sekund"
        else
            echo "⚠ Skrypt build_spk.sh zakończył się z błędem."
            exit 1
        fi
    else
        echo "⚠ Zakończono proces. Brak plików binarnych."
        exit 1
    fi
fi

# Iterowanie po folderach w katalogu BIN (dla każdej architektury)
for arch_dir in "$BIN_DIR"/*; do
    # Sprawdzanie, czy to folder
    if [ -d "$arch_dir" ]; then
        echo "ℹ Sprawdzam folder: $arch_dir"
        
        # Sprawdzanie, czy w folderze znajdują się pliki inne niż *.log
        files_found=false
        for file in "$arch_dir"/*; do
            if [ -f "$file" ] && [[ ! "$file" =~ \.log$ ]]; then
                files_found=true
                break
            fi
        done
        
        # Jeśli pliki są dostępne, kopiujemy je
        if [ "$files_found" = true ]; then
            echo "ℹ Znalazłem pliki w folderze $arch_dir. Kopiuję je..."
            # Kopiowanie plików do docelowego katalogu
            for file in "$arch_dir"/*; do
                if [ -f "$file" ] && [[ ! "$file" =~ \.log$ ]]; then
                    cp "$file" "$TARGET_DIR/"
                    echo "ℹ Skopiowano plik: $file"
                fi
            done

            # Pobieramy nazwę architektury
            arch_name=$(basename "$arch_dir")
            
            # Uruchamiamy skrypt budujący pakiet SPK
            echo "ℹ Uruchamiam skrypt build_spk.sh..."
            bash ./build_spk.sh

           if [ $? -eq 0 ]; then
            echo "ℹ Skrypt build_spk.sh zakończył się pomyślnie."

             # Sprawdzamy folder 'relese' w celu znalezienia wygenerowanego pliku .spk
              spk_file=$(find relese/_temp -name "*.spk" -type f)

               # Jeśli plik .spk istnieje, sprawdzamy, czy nazwa zawiera architekturę
               if [ -n "$spk_file" ]; then
                # Sprawdzamy, czy w nazwie pliku nie ma już architektury (np. 'aarch64')
                 if [[ "$spk_file" =~ ${arch_name} ]]; then
                    echo "ℹ Plik $spk_file już zawiera architekturę $arch_name. Ignoruję zmianę nazwy."
           else
              # Jeśli plik nie ma architektury, zmieniamy jego nazwę na unikalną z architekturą
              # Pobieranie wersji pakietu i wersji DSM z plików INFO
              # Pobieranie wersji pakietu
              packageVer=$(grep '^version=' "SPK_AP_TEMPLATE/INFO" | cut -d'=' -f2 | sed 's/"//g' | tr -d ' ')

                 # Pobieranie wersji Synology z pliku INFO (jeśli istnieje)
                SynologyVer=$(grep '^os_min_ver=' "SPK_AP_TEMPLATE/INFO" | cut -d'=' -f2 | sed 's/"//g' | tr -d ' ' | cut -d'.' -f1)

                 # Sprawdzenie, czy wersja DSM została pobrana, jeśli nie, przypisanie domyślnej wartości (np. 0)
                if [ -z "$SynologyVer" ]; then
                       SynologyVer="UNKNOWN"
                fi

               # Tworzenie nowej nazwy pliku SPK
               new_spk_name="relese/$(basename "$spk_file" .spk)-${arch_name}-DSM${SynologyVer}-${packageVer}.spk"
               mv "$spk_file" "$new_spk_name"
               echo "ℹ Zmieniono nazwę pakietu na: $new_spk_name"
              successful_operations+=("$arch_name")
           fi
    else
        echo "⚠ Nie znaleziono pliku .spk w folderze relese."
        failed_operations+=("$arch_name")
    fi
else
    echo "⚠ Skrypt build_spk.sh zakończył się z błędem w folderze $arch_dir."
    failed_operations+=("$arch_name")
fi
        else
            echo "ℹ Brak plików do przetworzenia w folderze $arch_dir."
        fi
    fi
done

# Podsumowanie wyników
echo "✅ Podsumowanie:"
echo "Udane operacje: ${#successful_operations[@]}"
for arch in "${successful_operations[@]}"; do
    echo " - $arch"
done

echo "❌ Nieudane operacje: ${#failed_operations[@]}"
for arch in "${failed_operations[@]}"; do
    echo " - $arch"
done

# Obliczanie czasu trwania operacji
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "ℹ Czas trwania operacji: $duration sekund"

# Zapytanie użytkownika, czy chce ponowić proces
read -p "Czy chcesz ponowić proces? (t/n): " answer
if [[ "$answer" =~ ^[Tt]$ ]]; then
    echo "ℹ Ponawiam proces..."
    bash process_files.sh
else
    echo "ℹ Proces zakończony."
fi
