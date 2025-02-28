# WRF Automated Installation Script

![WRF Model](https://raw.githubusercontent.com/wrf-model/WRF/master/var/graphics/wrf_logo.png)

A comprehensive automated script for detecting, installing, and compiling the Weather Research and Forecasting (WRF) model across various operating systems.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Supported Operating Systems](#supported-operating-systems)
- [Installation](#installation)
- [Usage](#usage)
- [Directory Structure](#directory-structure)
- [Environment Setup](#environment-setup)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Overview

The Weather Research and Forecasting (WRF) model is a next-generation mesoscale numerical weather prediction system designed for both atmospheric research and operational forecasting applications. Installing WRF can be challenging due to its many dependencies and compilation requirements.

This script automates the entire process, from installing prerequisites to compiling the model, with robust error handling and user-friendly guidance at each step.

## Features

- **System Detection**: Automatically identifies your operating system, architecture, and available compilers
- **Prerequisites Installation**: Installs all required dependencies based on your OS
- **Environment Configuration**: Sets up all necessary environment variables for successful compilation
- **Interactive Installation**: Guides users through configuration options with clear explanations
- **Error Detection**: Robust error checking with detailed diagnostics and troubleshooting suggestions
- **Parallel Compilation**: Uses multi-threading to speed up the compilation process
- **WPS Support**: Optional installation of the WRF Preprocessing System (WPS)
- **Verification**: Confirms successful installation by checking for required executables
- **Comprehensive Logging**: Maintains detailed logs for debugging and reference

## Requirements

- **Hardware**:
  - CPU: Multi-core processor recommended
  - RAM: Minimum 4GB (8GB+ recommended)
  - Disk Space: At least 2GB free space

- **Software**:
  - Bash shell environment
  - Internet connection
  - Admin/sudo privileges (for installing dependencies)

## Supported Operating Systems

- Ubuntu/Debian-based systems
- CentOS/RHEL/Fedora
- macOS (with Homebrew)
- Windows (via Windows Subsystem for Linux)

## Installation

1. Download the installation script:

```bash
wget https://raw.githubusercontent.com/yourusername/wrf-installer/main/wrf_install.sh
```

2. Make it executable:

```bash
chmod +x wrf_install.sh
```

3. Run the script:

```bash
./wrf_install.sh
```

## Usage

The script will guide you through the installation process with interactive prompts:

1. Select installation directory (defaults to ~/WRF)
2. The script will detect your system environment
3. Required prerequisites will be installed
4. WRF source code will be downloaded and extracted
5. You'll be prompted to select compilation options
6. The script will compile WRF (and optionally WPS)
7. Installation will be verified

Example output:

```
=== Detecting System Environment ===
[INFO] Operating System: ubuntu
[INFO] Architecture: x86_64
[INFO] Available Compilers: gnu
[INFO] Available MPI: openmpi
[INFO] Available Libraries: netcdf hdf5 jasper
[INFO] Available Disk Space: 58G
[INFO] Available Memory: 16G
```

## Directory Structure

After installation, your directory structure will look like:

```
$INSTALL_DIR/
├── WRF/                  # Main WRF directory
│   ├── main/             # Contains compiled executables
│   │   ├── wrf.exe       # Main WRF executable
│   │   └── real.exe      # Real data initialization executable
│   └── ...
├── WPS/                  # WRF Preprocessing System (if installed)
│   ├── geogrid.exe
│   ├── metgrid.exe
│   └── ungrib.exe
└── wrf_env.sh            # Environment setup script
```

## Environment Setup

Before using WRF, you need to set up the environment:

```bash
source $INSTALL_DIR/wrf_env.sh
```

This script sets all necessary environment variables for WRF to function properly.

## Troubleshooting

The script includes an automated troubleshooting system that:

1. Detects common installation errors
2. Provides specific guidance for resolving issues
3. Offers solutions for fixing environment variables
4. Maintains detailed logs for debugging

If you encounter issues:

- Check the log files: `wrf_install.log` and `wrf_error.log` in the script directory
- Use the troubleshooting menu options when presented
- For persistent problems, visit the [WRF Users Forum](https://forum.mmm.ucar.edu/phpBB3/)

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| NetCDF not found | Verify NetCDF is installed and NETCDF variable is properly set |
| Compilation errors | Check compiler compatibility and ensure all prerequisites are installed |
| Missing executables | Review compilation log for errors and ensure environment is properly set up |

## Contributing

Contributions to improve this installer are welcome! Please feel free to:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

Please ensure your code follows best practices for Bash scripting and includes appropriate error handling.

## License

This script is released under the MIT License. See the LICENSE file for details.

## Acknowledgments

- The [WRF Model](https://github.com/wrf-model/WRF) development team
- UCAR/NCAR for developing and maintaining WRF
- All contributors to this installation script

---

*Note: This script is not officially affiliated with or endorsed by the WRF development team or NCAR.*
