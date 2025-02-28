#!/bin/bash

# ======================================================
# WRF Automated Installation and Compilation Script
# ======================================================

# Global variables
SCRIPT_VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/wrf_install.log"
ERROR_LOG_FILE="${SCRIPT_DIR}/wrf_error.log"
WRF_VERSION="4.4.1"  # Latest stable version as of writing
WRF_URL="https://github.com/wrf-model/WRF/archive/v${WRF_VERSION}.tar.gz"
WPS_URL="https://github.com/wrf-model/WPS/archive/v${WRF_VERSION}.tar.gz"
INSTALL_DIR=""
NCORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
declare -A SYSTEM_INFO

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ======= Utility Functions =======

# Function to log messages
log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} - ${message}" >> "${LOG_FILE}"
}

# Function to log errors
log_error() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} - ERROR: ${message}" >> "${ERROR_LOG_FILE}"
    echo -e "${timestamp} - ERROR: ${message}" >> "${LOG_FILE}"
}

# Function to display messages
display_message() {
    local message="$1"
    local prefix="${2:-INFO}"
    local color="${3:-$NC}"
    
    echo -e "${color}[${prefix}] ${message}${NC}"
    log "[${prefix}] ${message}"
}

# Function to display errors
display_error() {
    local message="$1"
    display_message "${message}" "ERROR" "${RED}"
    log_error "${message}"
}

# Function to display success messages
display_success() {
    local message="$1"
    display_message "${message}" "SUCCESS" "${GREEN}"
}

# Function to display section headers
display_section() {
    local section="$1"
    echo -e "\n${BLUE}=== ${section} ===${NC}"
    log "=== ${section} ==="
}

# Function to check command execution status
check_status() {
    local status=$1
    local error_message="$2"
    
    if [ ${status} -ne 0 ]; then
        display_error "${error_message}"
        return 1
    fi
    return 0
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to ask for user confirmation
ask_user() {
    local question="$1"
    local default="${2:-y}"
    
    while true; do
        if [ "${default}" = "y" ]; then
            echo -n -e "${question} [Y/n]: "
        else
            echo -n -e "${question} [y/N]: "
        fi
        
        read -r answer
        
        [ -z "${answer}" ] && answer="${default}"
        
        case "${answer}" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# ======= Environment Detection Module =======

# Function to detect operating system
detect_operating_system() {
    local os=""
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os="${ID}"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        os="${DISTRIB_ID,,}"  # Convert to lowercase
    elif [ -f /etc/debian_version ]; then
        os="debian"
    elif [ -f /etc/redhat-release ]; then
        if grep -q "CentOS" /etc/redhat-release; then
            os="centos"
        else
            os="redhat"
        fi
    elif [ "$(uname)" == "Darwin" ]; then
        os="macos"
    else
        os="unknown"
    fi
    
    echo "${os}"
}

# Function to detect architecture
detect_architecture() {
    uname -m
}

# Function to check available compilers
check_available_compilers() {
    local compilers=()
    
    # Check for GNU compilers
    if command_exists gcc && command_exists gfortran; then
        compilers+=("gnu")
    fi
    
    # Check for Intel compilers
    if command_exists icc && command_exists ifort; then
        compilers+=("intel")
    fi
    
    # Check for PGI compilers
    if command_exists pgcc && command_exists pgfortran; then
        compilers+=("pgi")
    fi
    
    echo "${compilers[@]}"
}

# Function to check available MPI implementations
check_available_mpi() {
    local mpi_impls=()
    
    # Check for OpenMPI
    if command_exists ompi_info; then
        mpi_impls+=("openmpi")
    fi
    
    # Check for MPICH
    if command_exists mpichversion || command_exists mpich2version; then
        mpi_impls+=("mpich")
    fi
    
    # Check for Intel MPI
    if command_exists mpiicc; then
        mpi_impls+=("intel_mpi")
    fi
    
    echo "${mpi_impls[@]}"
}

# Function to check available libraries
check_available_libraries() {
    local libraries=()
    
    # Check for NetCDF
    if command_exists nc-config || [ -d "/usr/include/netcdf" ] || [ -d "/usr/local/include/netcdf" ]; then
        libraries+=("netcdf")
    fi
    
    # Check for HDF5
    if command_exists h5dump || [ -d "/usr/include/hdf5" ] || [ -d "/usr/local/include/hdf5" ]; then
        libraries+=("hdf5")
    fi
    
    # Check for Jasper
    if [ -d "/usr/include/jasper" ] || [ -d "/usr/local/include/jasper" ]; then
        libraries+=("jasper")
    fi
    
    echo "${libraries[@]}"
}

# Function to detect system environment
detect_system_environment() {
    display_section "Detecting System Environment"
    
    SYSTEM_INFO["os"]=$(detect_operating_system)
    SYSTEM_INFO["architecture"]=$(detect_architecture)
    SYSTEM_INFO["compilers"]=$(check_available_compilers)
    SYSTEM_INFO["mpi"]=$(check_available_mpi)
    SYSTEM_INFO["libraries"]=$(check_available_libraries)
    SYSTEM_INFO["disk_space"]=$(df -h . | awk 'NR==2 {print $4}')
    
    if [ "$(uname)" == "Darwin" ]; then
        SYSTEM_INFO["memory"]=$(sysctl -n hw.memsize | awk '{print $0/1024/1024/1024 " GB"}')
    else
        SYSTEM_INFO["memory"]=$(free -h | awk '/^Mem:/ {print $2}')
    fi
    
    display_message "Operating System: ${SYSTEM_INFO["os"]}"
    display_message "Architecture: ${SYSTEM_INFO["architecture"]}"
    display_message "Available Compilers: ${SYSTEM_INFO["compilers"]}"
    display_message "Available MPI: ${SYSTEM_INFO["mpi"]}"
    display_message "Available Libraries: ${SYSTEM_INFO["libraries"]}"
    display_message "Available Disk Space: ${SYSTEM_INFO["disk_space"]}"
    display_message "Available Memory: ${SYSTEM_INFO["memory"]}"
}

# ======= Dependency Handling Module =======

# Function to install prerequisites on Debian-based systems
install_debian_prerequisites() {
    display_section "Installing Prerequisites for Debian-based System"
    
    display_message "Updating package lists..."
    sudo apt-get update -qq
    check_status $? "Failed to update package lists"
    
    display_message "Installing essential build tools..."
    sudo apt-get install -y build-essential csh gfortran m4 curl wget
    check_status $? "Failed to install essential build tools"
    
    display_message "Installing required libraries..."
    sudo apt-get install -y libhdf5-dev libnetcdf-dev netcdf-bin libnetcdff-dev
    check_status $? "Failed to install NetCDF and HDF5 libraries"
    
    sudo apt-get install -y mpich libmpich-dev
    check_status $? "Failed to install MPICH"
    
    sudo apt-get install -y libpng-dev zlib1g-dev libjasper-dev
    check_status $? "Failed to install additional libraries"
    
    display_success "Prerequisites installed successfully."
}

# Function to install prerequisites on RedHat-based systems
install_redhat_prerequisites() {
    display_section "Installing Prerequisites for RedHat-based System"
    
    display_message "Installing essential build tools..."
    sudo yum -y install gcc gcc-gfortran gcc-c++ csh m4 curl wget make
    check_status $? "Failed to install essential build tools"
    
    display_message "Installing required libraries..."
    sudo yum -y install netcdf-devel netcdf-fortran-devel hdf5-devel
    check_status $? "Failed to install NetCDF and HDF5 libraries"
    
    sudo yum -y install mpich-devel
    check_status $? "Failed to install MPICH"
    
    sudo yum -y install libpng-devel zlib-devel jasper-devel
    check_status $? "Failed to install additional libraries"
    
    display_success "Prerequisites installed successfully."
}

# Function to install prerequisites on macOS
install_macos_prerequisites() {
    display_section "Installing Prerequisites for macOS"
    
    if ! command_exists brew; then
        display_error "Homebrew is not installed. Please install it from https://brew.sh/"
        display_message "You can install it with: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi
    
    display_message "Updating Homebrew..."
    brew update
    check_status $? "Failed to update Homebrew"
    
    display_message "Installing essential build tools..."
    brew install gcc coreutils wget
    check_status $? "Failed to install essential build tools"
    
    display_message "Installing required libraries..."
    brew install netcdf netcdf-fortran hdf5
    check_status $? "Failed to install NetCDF and HDF5 libraries"
    
    brew install open-mpi
    check_status $? "Failed to install OpenMPI"
    
    brew install libpng jasper
    check_status $? "Failed to install additional libraries"
    
    display_success "Prerequisites installed successfully."
}

# Function to install prerequisites on WSL
install_wsl_prerequisites() {
    display_section "Installing Prerequisites for Windows Subsystem for Linux"
    
    # For WSL, we use the same approach as Debian/Ubuntu
    install_debian_prerequisites
}

# Function to install prerequisites
install_prerequisites() {
    local os="${SYSTEM_INFO["os"]}"
    
    case "${os}" in
        ubuntu|debian|linuxmint|pop)
            install_debian_prerequisites
            ;;
        centos|redhat|fedora|rocky|almalinux)
            install_redhat_prerequisites
            ;;
        macos|darwin)
            install_macos_prerequisites
            ;;
        *)
            if grep -q Microsoft /proc/version; then
                install_wsl_prerequisites
            else
                display_error "Unsupported operating system: ${os}"
                display_message "You'll need to install the prerequisites manually."
                display_message "Please check the WRF documentation at https://github.com/wrf-model/WRF for details."
                return 1
            fi
            ;;
    esac
}

# Function to setup environment variables
setup_environment_variables() {
    display_section "Setting up Environment Variables"
    
    local env_file="${INSTALL_DIR}/wrf_env.sh"
    
    # Find NetCDF and other library paths
    local netcdf_path=""
    local netcdf_fortran_path=""
    local hdf5_path=""
    local jasper_include=""
    local jasper_lib=""
    
    # Find NetCDF
    if command_exists nc-config; then
        netcdf_path=$(nc-config --prefix)
    elif [ -d "/usr/local/netcdf" ]; then
        netcdf_path="/usr/local/netcdf"
    elif [ -d "/usr/local/opt/netcdf" ]; then  # Homebrew
        netcdf_path="/usr/local/opt/netcdf"
    elif [ -d "/opt/netcdf" ]; then
        netcdf_path="/opt/netcdf"
    fi
    
    # Find NetCDF-Fortran
    if command_exists nf-config; then
        netcdf_fortran_path=$(nf-config --prefix)
    elif [ -d "/usr/local/netcdf-fortran" ]; then
        netcdf_fortran_path="/usr/local/netcdf-fortran"
    elif [ -d "/usr/local/opt/netcdf-fortran" ]; then  # Homebrew
        netcdf_fortran_path="/usr/local/opt/netcdf-fortran"
    elif [ -d "/opt/netcdf-fortran" ]; then
        netcdf_fortran_path="/opt/netcdf-fortran"
    fi
    
    # Find HDF5
    if command_exists h5cc; then
        hdf5_path=$(h5cc -showconfig | grep "Installation point" | awk '{print $NF}')
    elif [ -d "/usr/local/hdf5" ]; then
        hdf5_path="/usr/local/hdf5"
    elif [ -d "/usr/local/opt/hdf5" ]; then  # Homebrew
        hdf5_path="/usr/local/opt/hdf5"
    elif [ -d "/opt/hdf5" ]; then
        hdf5_path="/opt/hdf5"
    fi
    
    # Find Jasper
    if [ -d "/usr/include/jasper" ]; then
        jasper_include="/usr/include/jasper"
        if [ -f "/usr/lib/libjasper.so" ] || [ -f "/usr/lib/libjasper.dylib" ]; then
            jasper_lib="/usr/lib"
        elif [ -f "/usr/lib64/libjasper.so" ]; then
            jasper_lib="/usr/lib64"
        fi
    elif [ -d "/usr/local/include/jasper" ]; then
        jasper_include="/usr/local/include/jasper"
        if [ -f "/usr/local/lib/libjasper.so" ] || [ -f "/usr/local/lib/libjasper.dylib" ]; then
            jasper_lib="/usr/local/lib"
        elif [ -f "/usr/local/lib64/libjasper.so" ]; then
            jasper_lib="/usr/local/lib64"
        fi
    elif [ -d "/usr/local/opt/jasper/include" ]; then  # Homebrew
        jasper_include="/usr/local/opt/jasper/include"
        jasper_lib="/usr/local/opt/jasper/lib"
    fi
    
    # Create environment file
    display_message "Creating environment setup file: ${env_file}"
    
    cat > "${env_file}" << EOF
#!/bin/bash
# WRF Environment Variables

# Set path for NetCDF
export NETCDF="${netcdf_path}"
export NETCDF_FORTRAN="${netcdf_fortran_path}"

# Set path for HDF5
export HDF5="${hdf5_path}"

# Set paths for Jasper (required for GRIB2 I/O)
export JASPERINC="${jasper_include}"
export JASPERLIB="${jasper_lib}"

# Add WRF to PATH
export PATH="${INSTALL_DIR}/WRF/main:\$PATH"

# Set WRF directory
export WRF_DIR="${INSTALL_DIR}/WRF"

# Set number of processors for compilation
export J="${NCORES}"

# Additional settings
export WRFIO_NCD_LARGE_FILE_SUPPORT=1

echo "WRF environment variables set."
EOF
    
    chmod +x "${env_file}"
    
    display_message "Environment variables configured in: ${env_file}"
    display_message "Please run 'source ${env_file}' before proceeding with WRF compilation."
    
    # Source the environment file
    source "${env_file}"
    check_status $? "Failed to source environment variables file"
    
    display_success "Environment variables set up successfully."
}

# ======= WRF Installation Module =======

# Function to download and extract WRF
download_wrf() {
    display_section "Downloading WRF"
    
    # Create directory if it doesn't exist
    mkdir -p "${INSTALL_DIR}"
    
    local wrf_tarball="${INSTALL_DIR}/wrf-${WRF_VERSION}.tar.gz"
    
    # Download WRF
    display_message "Downloading WRF v${WRF_VERSION}..."
    
    if command_exists wget; then
        wget -q --show-progress -O "${wrf_tarball}" "${WRF_URL}"
    elif command_exists curl; then
        curl -L --progress-bar -o "${wrf_tarball}" "${WRF_URL}"
    else
        display_error "Neither wget nor curl is installed. Cannot download files."
        return 1
    fi
    
    check_status $? "Failed to download WRF"
    
    # Extract WRF
    display_message "Extracting WRF..."
    tar -xf "${wrf_tarball}" -C "${INSTALL_DIR}"
    check_status $? "Failed to extract WRF"
    
    # Rename directory
    mv "${INSTALL_DIR}/WRF-${WRF_VERSION}" "${INSTALL_DIR}/WRF"
    check_status $? "Failed to rename WRF directory"
    
    display_success "WRF downloaded and extracted successfully."
}

# Function to download and extract WPS
download_wps() {
    display_section "Downloading WPS"
    
    local wps_tarball="${INSTALL_DIR}/wps-${WRF_VERSION}.tar.gz"
    
    # Download WPS
    display_message "Downloading WPS v${WRF_VERSION}..."
    
    if command_exists wget; then
        wget -q --show-progress -O "${wps_tarball}" "${WPS_URL}"
    elif command_exists curl; then
        curl -L --progress-bar -o "${wps_tarball}" "${WPS_URL}"
    else
        display_error "Neither wget nor curl is installed. Cannot download files."
        return 1
    fi
    
    check_status $? "Failed to download WPS"
    
    # Extract WPS
    display_message "Extracting WPS..."
    tar -xf "${wps_tarball}" -C "${INSTALL_DIR}"
    check_status $? "Failed to extract WPS"
    
    # Rename directory
    mv "${INSTALL_DIR}/WPS-${WRF_VERSION}" "${INSTALL_DIR}/WPS"
    check_status $? "Failed to rename WPS directory"
    
    display_success "WPS downloaded and extracted successfully."
}

# Function to configure WRF
configure_wrf() {
    display_section "Configuring WRF"
    
    cd "${INSTALL_DIR}/WRF" || {
        display_error "Failed to change to WRF directory"
        return 1
    }
    
    # Determine compiler and parallel options
    local compiler_choice="1"  # Default: GNU (serial)
    
    display_message "Available compiler options:"
    ./configure -h | grep -E "^[0-9]+" || {
        display_error "Failed to get compiler options. WRF configure script may be broken."
        return 1
    }
    
    # Ask user for compiler choice
    echo -n "Please select compiler option [${compiler_choice}]: "
    read -r user_choice
    [ -n "${user_choice}" ] && compiler_choice="${user_choice}"
    
    display_message "Selected compiler option: ${compiler_choice}"
    
    # Nesting options
    local nesting_choice="1"  # Default: Basic
    
    display_message "Nesting options:"
    display_message "1. Basic (no nesting)"
    display_message "2. Preset moves"
    display_message "3. Vortex following"
    
    echo -n "Please select nesting option [${nesting_choice}]: "
    read -r user_nesting
    [ -n "${user_nesting}" ] && nesting_choice="${user_nesting}"
    
    display_message "Selected nesting option: ${nesting_choice}"
    
    # Run configure script with expect if available, otherwise manual
    if command_exists expect; then
        display_message "Using expect to automate configuration..."
        
        cat > configure_wrf.exp << EOF
#!/usr/bin/expect
spawn ./configure
expect "Enter selection"
send "${compiler_choice}\r"
expect "Compile for nesting"
send "${nesting_choice}\r"
expect eof
EOF
        chmod +x configure_wrf.exp
        ./configure_wrf.exp
        rm configure_wrf.exp
    else
        display_message "Running configuration manually. Please enter options when prompted."
        ./configure
    fi
    
    # Check if configuration was successful
    if [ ! -f "configure.wrf" ]; then
        display_error "WRF configuration failed. Check the output above for errors."
        return 1
    fi
    
    display_success "WRF configured successfully."
}

# Function to compile WRF
compile_wrf() {
    display_section "Compiling WRF"
    
    cd "${INSTALL_DIR}/WRF" || {
        display_error "Failed to change to WRF directory"
        return 1
    }
    
    # Clean any previous build
    if [ -f "main/wrf.exe" ]; then
        display_message "Cleaning previous build..."
        ./clean -a
    fi
    
    # Compile WRF
    display_message "Compiling WRF (this may take a while)..."
    display_message "Using ${NCORES} CPU cores for compilation."
    ./compile em_real -j ${NCORES} > compile.log 2>&1
    
    # Check if compilation was successful
    if [ ! -f "main/wrf.exe" ] || [ ! -f "main/real.exe" ]; then
        display_error "WRF compilation failed. Checking compile.log for errors..."
        
        # Extract common errors for better diagnostics
        if grep -q "netcdf.h" compile.log; then
            display_error "NetCDF library issue detected. Check if NetCDF is properly installed."
        elif grep -q "mpi.h" compile.log; then
            display_error "MPI library issue detected. Check if MPI is properly installed."
        elif grep -q "Error copying" compile.log; then
            display_error "File copying error. Check disk space and permissions."
        elif grep -q "make: \*\*\* " compile.log; then
            grep -A 5 "make: \*\*\* " compile.log
        fi
        
        display_message "Last 20 lines of compile.log:"
        tail -n 20 compile.log
        return 1
    fi
    
    display_success "WRF compiled successfully!"
    display_message "Executables created: wrf.exe, real.exe, ndown.exe, tc.exe"
}

# Function to configure and compile WPS
configure_and_compile_wps() {
    display_section "Configuring and Compiling WPS"
    
    cd "${INSTALL_DIR}/WPS" || {
        display_error "Failed to change to WPS directory"
        return 1
    }
    
    # Run configure script
    display_message "Configuring WPS..."
    if command_exists expect; then
        cat > configure_wps.exp << EOF
#!/usr/bin/expect
spawn ./configure
expect "Enter selection"
send "1\r"
expect eof
EOF
        chmod +x configure_wps.exp
        ./configure_wps.exp
        rm configure_wps.exp
    else
        display_message "Running configuration manually. Select the option that matches your WRF configuration."
        ./configure
    fi
    
    # Check if configuration was successful
    if [ ! -f "configure.wps" ]; then
        display_error "WPS configuration failed. Check the output above for errors."
        return 1
    fi
    
    # Compile WPS
    display_message "Compiling WPS (this may take a while)..."
    ./compile > compile.log 2>&1
    
    # Check if compilation was successful
    if [ ! -f "geogrid.exe" ] || [ ! -f "metgrid.exe" ] || [ ! -f "ungrib.exe" ]; then
        display_error "WPS compilation failed. Checking compile.log for errors..."
        tail -n 20 compile.log
        return 1
    fi
    
    display_success "WPS compiled successfully!"
    display_message "Executables created: geogrid.exe, metgrid.exe, ungrib.exe"
}

# Function to verify installation
verify_installation() {
    display_section "Verifying Installation"
    
    local errors=0
    
    # Check WRF executables
    display_message "Checking WRF executables..."
    
    cd "${INSTALL_DIR}/WRF" || {
        display_error "Failed to change to WRF directory"
        return 1
    }
    
    for exe in main/wrf.exe main/real.exe main/ndown.exe main/tc.exe; do
        if [ -f "${exe}" ]; then
            display_message "Found ${exe}" "OK" "${GREEN}"
        else
            display_error "Missing ${exe}"
            errors=$((errors + 1))
        fi
    done
    
    # Check WPS executables if installed
    if [ -d "${INSTALL_DIR}/WPS" ]; then
        display_message "Checking WPS executables..."
        
        cd "${INSTALL_DIR}/WPS" || {
            display_error "Failed to change to WPS directory"
            return 1
        }
        
        for exe in geogrid.exe metgrid.exe ungrib.exe; do
            if [ -f "${exe}" ]; then
                display_message "Found ${exe}" "OK" "${GREEN}"
            else
                display_error "Missing ${exe}"
                errors=$((errors + 1))
            fi
        done
    fi
    
    if [ ${errors} -eq 0 ]; then
        display_success "All expected executables found. Installation verified!"
        return 0
    else
        display_error "Installation verification failed. ${errors} executables missing."
        return 1
    fi
}

# ======= Error Handling & Troubleshooting =======

# Function to diagnose common errors
diagnose_error() {
    local error_log="$1"
    
    display_section "Error Diagnosis"
    
    if grep -q "netcdf.h" "${error_log}"; then
        display_message "NetCDF-related error detected:" "DIAGNOSIS" "${YELLOW}"
        display_message "1. Check if NetCDF is installed: 'nc-config --version'" "FIX" "${BLUE}"
        display_message "2. Verify NETCDF environment variable: 'echo \$NETCDF'" "FIX" "${BLUE}"
        display_message "3. Try reinstalling NetCDF libraries" "FIX" "${BLUE}"
    elif grep -q "mpi" "${error_log}"; then
        display_message "MPI-related error detected:" "DIAGNOSIS" "${YELLOW}"
        display_message "1. Check if MPI is installed: 'mpirun --version'" "FIX" "${BLUE}"
        display_message "2. Try reinstalling your MPI implementation" "FIX" "${BLUE}"
    elif grep -q "configure.wrf" "${error_log}"; then
        display_message "Configuration file error detected:" "DIAGNOSIS" "${YELLOW}"
        display_message "1. Check WRF configuration options" "FIX" "${BLUE}"
        display_message "2. Verify environment variables are set correctly" "FIX" "${BLUE}"
    elif grep -q "No such file or directory" "${error_log}"; then
        display_message "Missing file error detected:" "DIAGNOSIS" "${YELLOW}"
        display_message "1. Check if all required libraries and dependencies are installed" "FIX" "${BLUE}"
        display_message "2. Verify paths in environment variables" "FIX" "${BLUE}"
    elif grep -q "permission denied" "${error_log}"; then
        display_message "Permission error detected:" "DIAGNOSIS" "${YELLOW}"
        display_message "1. Check file permissions in the installation directory" "FIX" "${BLUE}"
        display_message "2. Try running the script with sudo if needed" "FIX" "${BLUE}"
    else
        display_message "Unknown error detected. Please check the full error log:" "DIAGNOSIS" "${YELLOW}"
        display_message "Error log: ${error_log}" "INFO" "${BLUE}"
    fi
    
    display_message "For detailed troubleshooting, please visit:" "HELP" "${GREEN}"
    display_message "WRF Users Guide: https://www2.mmm.ucar.edu/wrf/users/docs/user_guide_v4/v4.4/contents.html" "LINK" "${BLUE}"
    display_message "WRF Forum: https://forum.mmm.ucar.edu/phpBB3/" "LINK" "${BLUE}"
}

# Function to offer troubleshooting options
offer_troubleshooting() {
    display_section "Troubleshooting Options"
    
    display_message "1. Show detailed error log"
    display_message "2. Try to fix NetCDF environment variables"
    display_message "3. Try to reinstall prerequisites"
    display_message "4. Exit and fix manually"
    
    echo -n "Please select an option [4]: "
    read -r option
    
    [ -z "${option}" ] && option="4"
    
    case "${option}" in
        1)
            display_section "Detailed Error Log"
            cat "${ERROR_LOG_FILE}"
            display_message "Press Enter to continue..."
            read
            offer_troubleshooting
            ;;
        2)
            display_section "Fixing NetCDF Environment Variables"
            setup_environment_variables
            ;;
        3)
            display_section "Reinstalling Prerequisites"
            install_prerequisites
            ;;
        4)
            display_message "Exiting troubleshooter. You can review the logs at:"
            display_message "Log file: ${LOG_FILE}"
            display_message "Error log: ${ERROR_LOG_FILE}"
            ;;
        *)
            display_error "Invalid option. Please enter a number between 1 and 4."
            offer_troubleshooting
            ;;
    esac
}

# ======= Main Installation Function =======

# Function to display welcome message
display_welcome_message() {
    clear
    cat << EOF
${BLUE}========================================================${NC}
${GREEN}            WRF Automated Installation Script            ${NC}
${BLUE}========================================================${NC}

This script will help you install and compile the Weather 
Research and Forecasting (WRF) model version ${WRF_VERSION}.

${YELLOW}What this script will do:${NC}
1. Detect your system environment
2. Install required prerequisites
3. Download and extract WRF source code
4. Configure and compile WRF
5. Install WPS (optional)
6. Verify the installation

${YELLOW}Requirements:${NC}
- Administrator/sudo privileges (for installing dependencies)
- Internet connection
- At least 2GB of free disk space
- At least 4GB of RAM

The installation process may take 1-2 hours depending on your
system specifications.

${BLUE}========================================================${NC}
EOF
}

# Function to get installation directory
get_installation_directory() {
    local default_dir="${HOME}/WRF"
    
    display_section "Installation Directory"
    
    display_message "Please specify where to install WRF."
    display_message "Default location: ${default_dir}"
    
    echo -n "Installation directory [${default_dir}]: "
    read -r user_dir
    
    [ -z "${user_dir}" ] && user_dir="${default_dir}"
    
    # Expand ~/ if present
    user_dir="${user_dir/#\~/$HOME}"
    
    # Check if directory exists and is not empty
    if [ -d "${user_dir}" ] && [ "$(ls -A "${user_dir}" 2>/dev/null)" ]; then
        if ask_user "Directory exists and is not empty. Files may be overwritten. Continue?"; then
            INSTALL_DIR="${user_dir}"
        else
            get_installation_directory
            return
        fi
    else
        INSTALL_DIR="${user_dir}"
        mkdir -p "${INSTALL_DIR}"
    fi
    
    display_message "Will install WRF in: ${INSTALL_DIR}"
}

# Function to display final success message
display_success_message() {
    display_section "Installation Complete"
    
    cat << EOF
${GREEN}WRF has been successfully installed!${NC}

Installation location: ${INSTALL_DIR}
WRF version: ${WRF_VERSION}

${YELLOW}Executables:${NC}
- WRF: ${INSTALL_DIR}/WRF/main/wrf.exe
- Real: ${INSTALL_DIR}/WRF/main/real.exe

${YELLOW}Environment Setup:${NC}
Before using WRF, you need to set up the environment:
  source ${INSTALL_DIR}/wrf_env.sh

${YELLOW}Next Steps:${NC}
1. Read the WRF User's Guide: https://www2.mmm.ucar.edu/wrf/users/docs/user_guide_v4/v4.4/contents.html
2. Download test cases from: https://www2.mmm.ucar.edu/wrf/users/download/test_cases.html
3. Join the WRF community: https://forum.mmm.ucar.edu/phpBB3/

${BLUE}Thank you for using the WRF Automated Installation Script!${NC}
EOF
}

# Main installation function
main() {
    # Initialize logging
    > "${LOG_FILE}"
    > "${ERROR_LOG_FILE}"
    log "=== WRF Installation Script Started ==="
    log "Script version: ${SCRIPT_VERSION}"
    log "WRF version: ${WRF_VERSION}"
    
    # Display welcome message
    display_welcome_message
    
    # Ask user to continue
    if ! ask_user "Do you want to continue with the installation?"; then
        display_message "Installation cancelled by user."
        exit 0
    fi
    
    # Get installation directory
    get_installation_directory
    
    # Detect system environment
    detect_system_environment
    
    # Install prerequisites
    if ! install_prerequisites; then
        display_error "Failed to install prerequisites."
        diagnose_error "${ERROR_LOG_FILE}"
        offer_troubleshooting
        exit 1
    fi
    
    # Setup environment variables
    if ! setup_environment_variables; then
        display_error "Failed to setup environment variables."
        diagnose_error "${ERROR_LOG_FILE}"
        offer_troubleshooting
        exit 1
    fi
    
    # Download WRF
    if ! download_wrf; then
        display_error "Failed to download WRF."
        diagnose_error "${ERROR_LOG_FILE}"
        offer_troubleshooting
        exit 1
    fi
    
    # Configure WRF
    if ! configure_wrf; then
        display_error "Failed to configure WRF."
        diagnose_error "${ERROR_LOG_FILE}"
        offer_troubleshooting
        exit 1
    fi
    
    # Compile WRF
    if ! compile_wrf; then
        display_error "Failed to compile WRF."
        diagnose_error "${ERROR_LOG_FILE}"
        offer_troubleshooting
        exit 1
    fi
    
    # Ask if user wants to install WPS
    if ask_user "Do you want to install WPS (WRF Preprocessing System) as well?"; then
        if ! download_wps; then
            display_error "Failed to download WPS."
            diagnose_error "${ERROR_LOG_FILE}"
        else
            if ! configure_and_compile_wps; then
                display_error "Failed to configure and compile WPS."
                diagnose_error "${ERROR_LOG_FILE}"
            fi
        fi
    fi
    
    # Verify installation
    if ! verify_installation; then
        display_error "Installation verification failed."
        diagnose_error "${ERROR_LOG_FILE}"
        offer_troubleshooting
        exit 1
    fi
    
    # Display success message
    display_success_message
    
    log "=== WRF Installation Script Completed Successfully ==="
    exit 0
}

# Run the main function
main "$@"