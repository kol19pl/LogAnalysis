#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Supported architectures
SUPPORTED_ARCHS=("amd64" "i686" "aarch64" "armv7" "armv8")

# Sprawdzenie, czy skrypt działa w WSL
check_wsl() {
    if ! grep -qi microsoft /proc/version; then
        error_exit "This script must be run in WSL (Windows Subsystem for Linux)"
    fi
}

# Funkcja obsługi błędów
error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Funkcja sprawdzania katalogów
check_directory() {
    for dir in "$@"; do
        [ -d "$dir" ] || error_exit "Directory '$dir' not found!"
    done
}

# Sprawdzenie WSL
check_wsl

# Funkcja wyświetlania pomocy
usage() {
    echo "Usage: $0 [-a <architecture>] [-s <source_file>] [-d]"
    echo "If no architecture is specified, compilation will be performed for all architectures."
    echo "Supported architectures: ${SUPPORTED_ARCHS[*]}"
    echo "If no source file is provided, all C files in 'Source' will be compiled."
    echo "Options:"
    echo "  -d    Dynamic linking (default is static linking which includes libraries in the executable)"
    echo "Example: $0 -a amd64 -s Source/main.c -d"
    exit 1
}

# Sprawdzenie katalogów
check_directory "Source" "BIN" "LIB" "tools"

# Funkcja do sprawdzania i instalowania pakietów
check_and_install_packages() {
    local arch=$1
    local packages_to_install=()

    if ! command_exists dpkg; then
        error_exit "dpkg is not installed. Cannot check installed packages."
    fi

    case $arch in
        i686)
            dpkg-query -W -f='${Status}' gcc-multilib 2>/dev/null | grep -q "installed" || packages_to_install+=("gcc-multilib")
            ;;
        aarch64|armv8)
            command_exists aarch64-linux-gnu-gcc || packages_to_install+=("gcc-aarch64-linux-gnu")
            ;;
        armv7)
            command_exists arm-linux-gnueabihf-gcc || packages_to_install+=("gcc-arm-linux-gnueabihf")
            dpkg-query -W -f='${Status}' libc6-dev-armhf-cross 2>/dev/null | grep -q "installed" || packages_to_install+=("libc6-dev-armhf-cross")
            ;;
    esac

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        echo "[OK] All required tools for $arch are installed."
        return
    fi

    echo "[WARN] Missing packages for $arch: ${packages_to_install[*]}"
    read -p "Install them? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        command_exists sudo || error_exit "sudo is required to install packages."
        sudo apt-get update
        sudo apt-get install -y "${packages_to_install[@]}"
    else
        error_exit "Cannot proceed without required packages."
    fi
}

# Kompilacja dla danej architektury
compile_for_arch() {
    local arch=$1
    local cc="gcc"
    local target=""
    local output_dir="BIN/$arch"
    local compile_success=true
    local linking_flags=""
    mkdir -p "$output_dir"
    
    case $arch in
        amd64) target="-m64" ;;
        i686) target="-m32" && check_and_install_packages "i686" ;;
        aarch64) cc="aarch64-linux-gnu-gcc" && check_and_install_packages "aarch64" ;;
        armv7) cc="arm-linux-gnueabihf-gcc" && target="-march=armv7-a -mfloat-abi=soft" && check_and_install_packages "armv7" ;;
        armv8) cc="aarch64-linux-gnu-gcc" && target="-march=armv8-a" && check_and_install_packages "armv8" ;;
        *) error_exit "Unsupported architecture: $arch" ;;
    esac

    # Handle static linking
    if [ "$STATIC_LINKING" = true ]; then
        echo "-> Compiling for $arch with static linking..."
        echo "[WARN] Static linking will increase executable file size significantly"
        linking_flags="-static"
        
        # Check for problematic libraries that might need special handling with static linking
        if [[ "$arch" == "aarch64" || "$arch" == "armv8" || "$arch" == "armv7" ]]; then
            echo "[WARN] Some libraries might not be available for static linking on $arch architecture"
        fi
    else
        echo "-> Compiling for $arch..."
    fi
    
    # Zapisujemy czas rozpoczęcia
    start_time=$(date +%s)

    # Tablica przechowująca nieudane kompilacje
    failed_compilations=()

    if [ -n "$SOURCE_FILE" ]; then
        output_file="$output_dir/$(basename "$SOURCE_FILE" .c)"
        echo "-> Compiling $SOURCE_FILE -> $output_file"
        libraries=$(tools/detect_libraries.sh "$SOURCE_FILE")
        
        # Skip dynamic linking for problematic libraries if static linking is enabled
        if [ "$STATIC_LINKING" = true ]; then
            # NSS, GLIBC and other problematic libraries need special handling
            if echo "$libraries" | grep -q "\-ldl"; then
                echo "[WARN] Found -ldl library which may not work with full static linking. Will link it dynamically."
                linking_flags="-Wl,-Bstatic $(echo $libraries | sed 's/-ldl//g') -Wl,-Bdynamic -ldl"
            elif echo "$libraries" | grep -qE '\-l(nss|resolv|pthread)'; then
                echo "[WARN] Found libraries that may have issues with static linking. Using partial static linking."
                # Apply static linking to most libraries but keep problematic ones dynamic
                local dynamic_libs=$(echo $libraries | grep -oE '\-l(nss|resolv|pthread)( |$)' | tr '\n' ' ')
                local static_libs=$(echo $libraries | sed -E 's/-l(nss|resolv|pthread)( |$)//g')
                linking_flags="-Wl,-Bstatic $static_libs -Wl,-Bdynamic $dynamic_libs"
            else
                linking_flags="-static $libraries"
            fi
        else
            linking_flags="$libraries"
        fi
        
        if ! $cc -Wall -Wextra $target -o "$output_file" "$SOURCE_FILE" $linking_flags 2>&1 | while read line; do echo "$(date '+%Y-%m-%d %H:%M:%S') $line"; done | tee "$output_dir/compile.log"; then
            failed_compilations+=("$SOURCE_FILE")
            compile_success=false
        fi
    else
        for file in Source/*.c; do
            output_file="$output_dir/$(basename "$file" .c)"
            echo "-> Compiling $file -> $output_file"
            libraries=$(tools/detect_libraries.sh "$file")
            
            # Skip dynamic linking for problematic libraries if static linking is enabled
            if [ "$STATIC_LINKING" = true ]; then
                # NSS, GLIBC and other problematic libraries need special handling
                if echo "$libraries" | grep -q "\-ldl"; then
                    echo "[WARN] Found -ldl library which may not work with full static linking. Will link it dynamically."
                    linking_flags="-Wl,-Bstatic $(echo $libraries | sed 's/-ldl//g') -Wl,-Bdynamic -ldl"
                elif echo "$libraries" | grep -qE '\-l(nss|resolv|pthread)'; then
                    echo "[WARN] Found libraries that may have issues with static linking. Using partial static linking."
                    # Apply static linking to most libraries but keep problematic ones dynamic
                    local dynamic_libs=$(echo $libraries | grep -oE '\-l(nss|resolv|pthread)( |$)' | tr '\n' ' ')
                    local static_libs=$(echo $libraries | sed -E 's/-l(nss|resolv|pthread)( |$)//g')
                    linking_flags="-Wl,-Bstatic $static_libs -Wl,-Bdynamic $dynamic_libs"
                else
                    linking_flags="-static $libraries"
                fi
            else
                linking_flags="$libraries"
            fi
            
            if ! $cc -Wall -Wextra $target -o "$output_file" "$file" $linking_flags 2>&1 | while read line; do echo "$(date '+%Y-%m-%d %H:%M:%S') $line"; done | tee -a "$output_dir/compile.log"; then
                failed_compilations+=("$file")
                compile_success=false
            fi
        done
    fi

    # Zapisujemy czas zakończenia
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Wyświetlamy czas kompilacji
    echo "[OK] Compilation for $arch completed in $duration seconds. Logs in $output_dir/compile.log"
    
    # Add file size information if static linking was used
    if [ "$STATIC_LINKING" = true ]; then
        echo "[INFO] Due to static linking, executable files may be significantly larger than with dynamic linking"
        if [ -n "$SOURCE_FILE" ]; then
            local file_size=$(stat -c %s "$output_dir/$(basename "$SOURCE_FILE" .c)" 2>/dev/null || echo "unknown")
            if [ "$file_size" != "unknown" ]; then
                echo "[INFO] Output file size: $(numfmt --to=iec-i --suffix=B $file_size)"
            fi
        fi
    fi

    # Jeśli wystąpiły nieudane kompilacje, zgłaszamy je
    if [ ${#failed_compilations[@]} -gt 0 ]; then
        echo "[ERROR] Compilation failed for the following files:"
        for failed_file in "${failed_compilations[@]}"; do
            echo "    - $failed_file"
        done
    fi

    $compile_success
    return $?
}

# Function to compile for all architectures
compile_all() {
    local start_time=$(date +%s)
    local failed_archs=()
    
    echo "[INFO] Starting compilation for all architectures..."
    for arch in "${SUPPORTED_ARCHS[@]}"; do
        echo "[INFO] ----------------------------------------"
        echo "[INFO] Starting compilation for $arch"
        if ! compile_for_arch "$arch"; then
            failed_archs+=("$arch")
        fi
    done
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    echo "[INFO] ----------------------------------------"
    echo "[INFO] Total compilation time: $total_duration seconds"
    
    if [ ${#failed_archs[@]} -gt 0 ]; then
        echo "[ERROR] Compilation failed for the following architectures:"
        for failed_arch in "${failed_archs[@]}"; do
            echo "    - $failed_arch"
        done
        return 1
    else
        echo "[OK] All architectures compiled successfully"
        return 0
    fi
}

# Parsowanie argumentów
ARCH=""
SOURCE_FILE=""
STATIC_LINKING=true
while getopts "a:s:dh" opt; do
    case $opt in
        a) ARCH="$OPTARG" ;;
        s) SOURCE_FILE="$OPTARG" ;;
        d) STATIC_LINKING=false ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Execute compilation based on arguments
if [ -z "$ARCH" ]; then
    compile_all
else
    # Validate specified architecture
    arch_valid=0
    for valid_arch in "${SUPPORTED_ARCHS[@]}"; do
        if [ "$ARCH" = "$valid_arch" ]; then
            arch_valid=1
            break
        fi
    done
    
    if [ $arch_valid -eq 0 ]; then
        error_exit "Invalid architecture: $ARCH. Supported architectures: ${SUPPORTED_ARCHS[*]}"
    fi
    
    compile_for_arch "$ARCH"
fi
