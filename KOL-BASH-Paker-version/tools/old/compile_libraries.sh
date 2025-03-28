#!/bin/bash

# Check if running in WSL
if ! grep -qi "microsoft\|wsl" /proc/version; then
    echo "This script is designed to run in Windows Subsystem for Linux (WSL)"
    echo "Please run this script in a WSL environment"
    exit 1
fi

# Funkcja obsługi błędów
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Funkcja sprawdzania katalogów
check_directory() {
    for dir in "$@"; do
        [ -d "$dir" ] || error_exit "Directory '$dir' not found!"
    done
}

# Funkcja do pobierania pakietów
download_package() {
    local package=$1
    local dest_dir=$2
    local url=$3
    local archive_name=$(basename "$url")

    # Jeśli katalog już istnieje, nic nie robimy
    if [ -d "$dest_dir" ]; then
        echo "✓ $package already exists in $dest_dir"
    else
        echo "\U0001F4E6 Downloading $package..."
        mkdir -p "$dest_dir"
        
        # Sprawdzanie, czy pakiet już został pobrany
        if [ ! -f "$dest_dir/$archive_name" ]; then
            wget -q "$url" -P "$dest_dir" || error_exit "Failed to download $package"
        fi
        
        # Jeśli pakiet został pobrany, rozpakowujemy go
        if [ -f "$dest_dir/$archive_name" ] && [ ! -d "$dest_dir/${package}" ]; then
            echo "\U0001F4E6 Extracting $package..."
            tar -xzf "$dest_dir/$archive_name" -C "$dest_dir" || error_exit "Failed to extract $package"
        fi
    fi
}

# Funkcja do kompilacji bibliotek
compile_libraries() {
    local arch=$1
    local lib_dir="Source/lib"
    
    # Set absolute paths
    current_dir=$(pwd)
    local lib_output_dir="$current_dir/LIB/$arch"
    mkdir -p "$lib_output_dir"

    case $arch in
        amd64) target="x86_64-linux-gnu" ;;
        i686) target="i686-linux-gnu" ;;
        aarch64) target="aarch64-linux-gnu" ;;
        armv7) target="arm-linux-gnueabihf" ;;
        armv8) target="aarch64-linux-gnu" ;;
        *) error_exit "Unsupported architecture for library compilation: $arch" ;;
    esac

    echo "\U0001F4E6 Compiling libraries for $arch..."
    start_time=$(date +%s)

    # Kompilacja glibc
    if [ -d "Source/lib/glibc" ]; then
        # Use absolute paths
        glibc_src_dir="$current_dir/Source/lib/glibc/glibc-2.34"
        if [ -d "$glibc_src_dir" ]; then
            echo "\U0001F4E6 Compiling glibc for $arch from $glibc_src_dir..."
            
            # Create and use build directory
            build_dir="$current_dir/Source/lib/glibc/build/$arch"
            mkdir -p "$build_dir"
            cd "$build_dir"
            
            # Configure glibc for the target architecture
            echo "\U0001F4E6 Configuring glibc in $build_dir..."
            "$glibc_src_dir/configure" \
                --prefix="$lib_output_dir" \
                --host="$target" \
                --enable-kernel=3.2 \
                --disable-werror || error_exit "Failed to configure glibc for $arch"
            
            # Compile glibc
            echo "\U0001F4E6 Building glibc..."
            make -j$(nproc) || error_exit "Failed to compile glibc for $arch"
            make install || error_exit "Failed to install glibc for $arch"
            
            # Return to original directory
            cd "$current_dir"
        else
            error_exit "No glibc-2.34 directory found in Source/lib/glibc!"
        fi
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo "✓ Libraries for $arch compiled in $duration seconds."
}

# Funkcja do pobierania źródeł przed kompilacją
download_sources() {
    local lib_dir="Source/lib"
    
    # Sprawdzamy, czy katalog Source/lib istnieje
    check_directory "Source/lib"

    # Jeśli nie mamy źródeł glibc, pobieramy je
    if [ ! -d "$lib_dir/glibc" ]; then
        echo "\U0001F4E6 Downloading glibc source..."
        download_package "glibc" "$lib_dir/glibc" "http://ftp.gnu.org/gnu/libc/glibc-2.34.tar.gz"
    fi

}

# Funkcja do sprawdzania, czy zależności są zainstalowane
check_dependencies() {
    dependencies=("wget" "tar" "make" "gcc" "gawk" "binutils")
    
    # Check if we have sudo access
    if ! command -v sudo &> /dev/null; then
        error_exit "sudo is required but not installed. Please run: apt-get install sudo"
    fi

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Warning: Required dependency '$dep' is not installed."
            
            read -p "Do you want to install '$dep'? (y/n): " install_choice
            if [[ "$install_choice" == "y" ]]; then
                echo "Installing $dep..."
                sudo apt-get update && sudo apt-get install -y "$dep" || error_exit "Failed to install $dep."
            else
                error_exit "Dependency '$dep' is required but not installed. Exiting."
            fi
        else
            version=$($dep --version | head -n 1)
            if [[ -n "$version" ]]; then
                echo "✓ $dep is already installed: $version"
            else
                echo "Warning: '$dep' is installed but cannot be executed. Please verify your installation."
            fi
        fi
    done
}

# Sprawdzanie i instalacja zależności
check_dependencies

# Pobieranie źródeł przed kompilacją
download_sources
echo "\U0001F4E6 All sources downloaded successfully!"

# Kompilacja bibliotek
for arch in "amd64" "i686" "aarch64" "armv7" "armv8"; do
    compile_libraries "$arch" || error_exit "Library compilation failed for $arch!"
done
echo "✓ All libraries compiled successfully!"
