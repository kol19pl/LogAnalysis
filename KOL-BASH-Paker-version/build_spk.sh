#!/bin/bash
set -e

SPK_OPTIONS="-czf"
PAK_OPTIONS="-cf"




if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Ten skrypt musi być uruchomiony jako root. Próbuję ponownie z sudo..."
    sudo bash "$0" "$@"
    exit
fi



echo "✅ Uruchomiono jako root"

# Sprawdzenie, czy pv jest dostępne
if command -v pv &>/dev/null; then
    USE_PV=true
else
    USE_PV=false
fi
#Jeśli pv nie jest dostępne, spytaj użytkownika, czy chce zainstalować
if ! $USE_PV; then
    read -p "ℹ Narzędzie pv nie jest zainstalowane. Czy chcesz je zainstalować? (t/n): " answer
    if [[ "$answer" == "t" || "$answer" == "T" ]]; then
        echo "ℹ Instaluję pv..."
        # Sprawdzenie, czy system to Debian/Ubuntu
        if [ -f /etc/debian_version ]; then
            echo "ℹ System Debian/Ubuntu wykryty."
            # Instalacja pv
            sudo apt-get update || { echo "⚠ Błąd podczas aktualizacji pakietów."; exit 1; }
        else
            # Sprawdzenie, czy system to arch Linux
            if [ -f /etc/arch-release ]; then
                echo "ℹ System Arch Linux wykryty."
                # Instalacja pv
                sudo pacman -Syu pv || { echo "⚠ Błąd podczas instalacji pv."; exit 1; }
            # Sprawdzenie, czy system to Fedora
            elif [ -f /etc/fedora-release ]; then
                echo "ℹ System Fedora wykryty."
                # Instalacja pv
                sudo dnf install pv || { echo "⚠ Błąd podczas instalacji pv."; exit 1; }
            # Sprawdzenie, czy system to CentOS
            elif [ -f /etc/centos-release ]; then
                echo "ℹ System CentOS wykryty."
                # Instalacja pv
                sudo yum install pv || { echo "⚠ Błąd podczas instalacji pv."; exit 1; }
            # Sprawdzenie, czy system to macOS
            elif [ "$(uname)" == "Darwin" ]; then
                echo "ℹ System macOS wykryty."
                # Instalacja pv
                brew install pv || { echo "⚠ Błąd podczas instalacji pv."; exit 1; }
            # Sprawdzenie, czy system to Windows
            elif [[ "$(uname)" == *"NT"* || "$(uname)" == *"MINGW"* ]]; then
                echo "ℹ System Windows wykryty."
                # Instalacja pv
                choco install pv || { echo "⚠ Błąd podczas instalacji pv."; exit 1; }
            else
                # Inny system operacyjny
                echo "⚠ Nieznany system operacyjny. Nie mogę zainstalować pv."
                exit 1
            fi
            # Sprawdzenie, czy instalacja pv zakończyła się sukcesem
            if command -v pv &>/dev/null; then
                echo "ℹ pv zostało zainstalowane pomyślnie."
            else
                echo "⚠ Błąd podczas instalacji pv. Sprawdź, czy narzędzie jest dostępne w PATH."
                exit 1
            fi                                 
        fi
        USE_PV=true
    else
        echo "ℹ Kontynuuję bez pv."
    fi
fi


# Katalog roboczy dla budowy pakietu (tymczasowy)
workDirMaster=$(pwd)/_build
workDir=$(pwd)/_build/Spk
releseDir=$(pwd)/relese

if [ -d "$workDirMaster" ]; then
    echo "ℹ Katalog roboczy już istnieje. Usuwam go przed kontynuowaniem."
    rm -rf "$workDirMaster"
fi
# Sprawdzenie, czy katalog relese istnieje
if [ -d "$releseDir" ]; then
    echo "ℹ Katalog relese już istnieje."
else
    echo "ℹ Katalog relese nie istnieje. Tworzę go."
    mkdir -p "$releseDir"
fi

mkdir -p "$workDirMaster"
mkdir -p "$workDir"
echo "ℹ Katalog roboczy utworzony w $workDir"


# Funkcja do naprawy kodowania plików
fix_line_endings() {
    if [ -f "$1" ]; then
        # Jeśli argument to plik, przetwórz tylko ten plik
        dos2unix "$1"
        echo "✅ Poprawiono zakończenia linii w pliku: $1"
    elif [ -d "$1" ]; then
        # Jeśli argument to katalog, przetwórz wszystkie pliki w nim
        find "$1" -type f -exec dos2unix {} \;
        echo "✅ Poprawiono zakończenia linii we wszystkich plikach w katalogu: $1"
    else
        echo "❌ Błąd: '$1' nie jest plikiem ani katalogiem!" >&2
        return 1
    fi
}



# Check if SPK_AP_TEMPLATE exists
if [ ! -d "SPK_AP_TEMPLATE" ]; then
    echo "ℹ SPK_AP_TEMPLATE folder not found. Please create it with the required INFO file."
    exit 1
fi

# Read package name from INFO file
packageName=$(grep '^package=' "SPK_AP_TEMPLATE/INFO" | cut -d'=' -f2 | sed 's/"//g' | tr -d ' ')

# Copy necessary files

#cp -R SPK_AP_TEMPLATE/INFO "$workDir/" || { echo "⚠ Error copying INFO NIEUDANE."; exit 1; }
rsync -av --exclude='pakiet' SPK_AP_TEMPLATE/ "$workDir/"

#if [ -d "$workDir/" ]; then


#

echo "ℹ Skrypty startowe skopiowane"
# Fix line endings for copied files





# Copy install.sh to the package structure
if [ -f "SPK_AP_TEMPLATE/install.sh" ]; then
    cp "SPK_AP_TEMPLATE/install.sh" "$workDir/" || { echo "⚠ Error copying install.sh."; exit 1; }
    echo "ℹ Plik install.sh skopiowany do struktury pakietu."
    # Set executable permission for install.sh
   # chmod +x "$workDir/install.sh"
    echo "ℹ Ustawiono uprawnienia do wykonywania dla install.sh."
    # Fix line endings for install.sh
    fix_line_endings "$workDir/install.sh"
   # echo "⚠ Plik install.sh nie znaleziony! Upewnij się, że plik jest obecny w katalogu SPK_AP_TEMPLATE."
fi
# Copy LICENSE to the package structure
if [ -f "SPK_AP_TEMPLATE/LICENSE" ]; then
    cp "SPK_AP_TEMPLATE/LICENSE" "$workDir/" || { echo "⚠ Error copying LICENSE"; exit 1; }
    echo "ℹ Plik LICENSE skopiowany do struktury pakietu."
    # Set executable permission for install.sh
   # chmod +x "$workDir/install.sh"
    echo "ℹ test formatu dla LICENSE."
    # Fix line endings for install.sh
    fix_line_endings "$workDir/LICENSE"
   # echo "⚠ Plik install.sh nie znaleziony! Upewnij się, że plik jest obecny w katalogu SPK_AP_TEMPLATE."
fi





#fix_line_endings "$workDir/"
#echo "ℹ Formatowanie sprawdzone dla $workDir"

# Create package structure
mkdir -p "$workDirMaster/package"
echo "ℹ Tworzenie struktury pakietu w $workDirMaster/package"




   # cp -Rp SPK_AP_TEMPLATE/pakiet/* "$workDirMaster/package" || { echo "⚠ Error copying package content."; exit 1; }
    
   # tar cf - -C SPK_AP_TEMPLATE/pakiet . | pv | tar xf - -C "$workDirMaster/package" || { echo "⚠ Error copying package content."; exit 1; }

    echo "ℹ Nie używam pv do kopiowania plików."
    # Copy package content without pv
    rsync -ah --progress SPK_AP_TEMPLATE/pakiet/ "$workDirMaster/package" || { echo "⚠ Error copying package content."; exit 1; }


echo "ℹ Struktura pakietu utworzona w $workDirMaster/package"




# Create package.tgz
echo "📦 Tworzenie archiwum package.tgz..."
#ls -lR "$workDirMaster/package"
#echo "Zawartość $workDirMaster/package przed pakowaniem:"
#ls -la "$workDirMaster/package"
cd "$workDirMaster/package"
#nadajemy uprawnienia do katalogu package do wszystkich plików i katalogów w nim aby każdy mógł je  odczytać usunąć edytować
#chmod -R 755 "$workDirMaster/package"

#sprawdzenie, czy w katalogu jest katalog bin
if [ -d "bin" ]; then
    echo "ℹ Katalog bin istnieje. Przechodzę do katalogu bin."
    #nadajemy uprawnienia do katalogu bin do wszystkich plików i katalogów w nim aby każdy mógł je wykonać i odczytać
   # chmod -R 755 bin
    cd bin || { echo "⚠ Error navigating to bin directory."; exit 1; }
else
    echo "ℹ Katalog bin nie istnieje. Przechodzę do katalogu $workDir."
    cd .. || { echo "⚠ Error navigating to package directory."; exit 1; }
fi

cd "$workDirMaster/package"




#$PAK_OPTIONS

if $USE_PV; then
    echo "ℹ Używam pv do tworzenia archiwum."
    # Create package.tgz with pv
    tar czf - * | pv -s $(du -sb . | awk '{print $1}') > $workDir/package.tgz || { echo "⚠ Error creating package.tgz."; exit 1; }
else
    echo "ℹ Nie używam pv do tworzenia archiwum."
    # Create package.tgz without pv
    tar czf $workDir/package.tgz * || { echo "⚠ Error creating package.tgz."; exit 1; }
fi





    # tar czf - * --no-same-permissions * | pv -s $(du -sb . | awk '{print $1}') > $workDir/package.tgz || { echo "⚠ Error creating package.tgz."; exit 1; }


    #tar czf $workDir/package.tgz * --no-same-permissions * || { echo "⚠ Error creating package.tgz."; exit 1; }

cd .. || { echo "⚠ Error navigating back to the work directory."; exit 1; }
cd ..

#Usunięcie katalogu package z katalogu roboczego
#if $USE_PV; then
#    echo "ℹ Używam pv do usuwania katalogu package."
    # Remove package directory with pv
#    tar cf - -C "$workDir" package | pv | tar xf - || { echo "⚠ Error removing package directory."; exit 1; }
#else
#    echo "ℹ Nie używam pv do usuwania katalogu package."
    # Remove package directory without pv
#    rm -rf "$workDir/package" || { echo "⚠ Error removing package directory."; exit 1; }
#fi

fix_line_endings "$workDir/INFO"
#chown root:root -R "$workDir"
#chown -R root:root "$workDir"
#chmod -R 755 "$workDir"
#chmod 775 "$workDir/INFO"
#echo "ℹ Formatowanie sprawdzone dla "$workDir/INFO""


fix_line_endings "$workDir/scripts"
echo "ℹ Formatowanie sprawdzone dla "$workDir/scripts""


# Create final .spk package
cd $workDirMaster
cd .. || { echo "⚠ Error navigating back to the work directory."; exit 1; }

outputFile=$(pwd)/relese/_temp/${packageName}.spk
echo "📦 Tworzenie pakietu .spk: $outputFile"



if [ ! -d "$(dirname "$outputFile")" ]; then
    echo "❌ Błąd: katalog docelowy nie istnieje. Tworzę..."
    mkdir -p "$(dirname "$outputFile")"
fi

cd "$workDir"

#Tworzenie listy plików do spakowania dla tar
echo "Zawartość katalogu przed pakowaniem:"
ls -la
#Pakowanie plików z workdir do spk
#if $USE_PV; then
    #echo "ℹ Używam pv do tworzenia pakietu .spk w "$(dirname "$outputFile")"" 
    # Create .spk package with pv
  #  tar cf - * --no-same-permissions *| pv -s $(du -sb . | awk '{print $1}') > "$outputFile" || { echo "⚠ Error creating .spk package."; exit 1; }
  #   tar --format=ustar -cf * --no-same-permissions *| pv -s $(du -sb . | awk '{print $1}') > "$outputFile" || { echo "⚠ Error creating .spk package."; exit 1; }
  
#else
  #  echo "ℹ Nie używam pv do tworzenia pakietu .spk."
    # Create .spk package without pv
   # tar cf "$outputFile" * --no-same-permissions *|| { echo "⚠ Error creating .spk package."; exit 1; }
   # tar --format=ustar -cf "$outputFile" * --no-same-permissions *|| { echo "⚠ Error creating .spk package."; exit 1; }
#fi

if $USE_PV; then
    echo "ℹ Używam pv do tworzenia pakietu .spk."
    # Create .spk package with pv
    tar cf - * | pv -s $(du -sb . | awk '{print $1}') > "$outputFile" || { echo "⚠ Error creating .spk package."; exit 1; }
else
    echo "ℹ Nie używam pv do tworzenia pakietu .spk."
    # Create .spk package without pv
    tar cf "$outputFile" * || { echo "⚠ Error creating .spk package."; exit 1; }
fi



echo "✅ Pakiet utworzony: $outputFile"

# Clean up
#rm -rf "$workDir"
echo "🧹 Usunięto katalog roboczy: $workDir"

