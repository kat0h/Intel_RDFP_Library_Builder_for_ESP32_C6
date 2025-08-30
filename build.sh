#!/bin/bash

# Intel Decimal Floating-Point Math Library Builder for esp32-c6-wroom-1
# This script builds the Intel Decimal Floating-Point Math Library (RDFP)
#
# Memory Optimization Features:
# - Source code patches: static arrays → static const arrays for ROM placement
# - Const data arrays placed in ROM (.rodata) instead of RAM (.data)
# - Lookup tables stored in flash memory to save RAM
# - Compiler flags optimized for embedded systems memory usage
# - Function/data section separation for better linker optimization

set -e

# Configuration
C6_FLAGS="-Os -fdata-sections -ffunction-sections -DBID_THREAD="
BUILD_DIR="build"
OUTPUT_LIB="gcc111libdecimal_esp32_c6.a"
INTEL_LIB_VERSION="IntelRDFPMathLib20U2"

# use toolchains installed by platformio
# https://github.com/pioarduino/platform-espressif32#develop
CC=~/.platformio/tools/toolchain-riscv32-esp/bin/riscv32-esp-elf-gcc

# Check for ARM toolchain
if ! which $CC > /dev/null 2>&1; then
    echo "Error: ESP toolchain not found."
	echo "$CC"
    exit 1
fi

echo "=== Intel Decimal Floating-Point Math Library Builder for ESP32 C6 ==="
echo "Compiler: $($CC --version | head -1)"
echo "Flags: $C6_FLAGS"
echo

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Check if Intel library source exists
if [ ! -d "../$INTEL_LIB_VERSION" ]; then
    echo "Error: Intel Decimal Floating-Point Math Library source not found!"
    echo "Please extract $INTEL_LIB_VERSION.tar.gz to the project root directory."
    echo "Expected location: ../$INTEL_LIB_VERSION"
    exit 1
fi

# Copy Intel RDFP library sources
if [ ! -d "$INTEL_LIB_VERSION" ]; then
    echo "Copying Intel Decimal Floating-Point Math Library sources..."
    cp -r "../$INTEL_LIB_VERSION" .
fi

cd "$INTEL_LIB_VERSION/LIBRARY"

# Apply memory optimization patches to source code
echo "Applying memory optimization patches..."
echo "- Adding 'const' keyword to static arrays for ROM placement"

# Function to add const to static arrays
add_const_to_static_arrays() {
    local file="$1"
    if [ -f "$file" ]; then
        # Backup original file
        cp "$file" "$file.backup"
        
        # Add const to static array declarations
        sed -i 's/static \([A-Za-z_][A-Za-z0-9_]*\) \([A-Za-z_][A-Za-z0-9_]*\)\[\]/static const \1 \2[]/g' "$file"
        
        # Also handle cases with explicit array sizes
        sed -i 's/static \([A-Za-z_][A-Za-z0-9_]*\) \([A-Za-z_][A-Za-z0-9_]*\)\[\([0-9]*\)\]/static const \1 \2[\3]/g' "$file"
        
        echo "  ✓ Patched: $file"
    fi
}

# List of files that contain large static arrays that need to be placed in ROM
files_to_patch=(
    "src/bid32_sin.c"
    "src/bid32_cos.c" 
    "src/bid32_tan.c"
    "src/bid64_sin.c"
    "src/bid64_cos.c"
    "src/bid64_tan.c"
    "src/bid128_sin.c"
    "src/bid128_cos.c"
    "src/bid128_tan.c"
    "src/bid_decimal_data.c"
    "src/bid128_2_str_tables.c"
    "src/bid_convert_data.c"
)

# Apply patches to identified files
for file in "${files_to_patch[@]}"; do
    add_const_to_static_arrays "$file"
done

# Also search for any other files with large static arrays
echo "- Scanning for additional static arrays..."
find src -name "*.c" -exec grep -l "static.*\[\]" {} \; | while read file; do
    # Skip if already patched
    if [[ ! " ${files_to_patch[@]} " =~ " $file " ]]; then
        add_const_to_static_arrays "$file"
    fi
done

echo "Building Intel Decimal Floating-Point Math Library for Pi Pico 2..."
echo "This may take several minutes..."
echo

# Clean previous build
make clean > /dev/null 2>&1 || true

# Build the library with Pi Pico 2 specific settings
make -j \
  CC="$CC $C6_FLAGS" \
  CC_NAME=gcc \
  AR="~/.platformio/tools/toolchain-riscv32-esp/bin/riscv32-esp-elf-ar" \
  AR_CMD="~/.platformio/tools/toolchain-riscv32-esp/bin/riscv32-esp-elf-ar rv" \
  CALL_BY_REF=1 \
  GLOBAL_RND=1 \
  GLOBAL_FLAGS=1 \
  UNCHANGED_BINARY_FLAGS=0 \
  THREAD=0 \
  _HOST_OS=Linux \
  lib

# Check if build was successful
if [ -f "libbid.a" ]; then
    # Copy to project root with appropriate name
    cp libbid.a "../../$OUTPUT_LIB"
    echo
    echo "=== Build Successful ==="
    echo "Output library: $OUTPUT_LIB"
    echo "Size: $(ls -lh ../../$OUTPUT_LIB | awk '{print $5}')"
    echo "Architecture: $(arm-none-eabi-objdump -f ../../$OUTPUT_LIB | grep architecture | head -1)"
    echo
    echo
    echo "Library ready for use with ESP32 C6"
    echo "Link with: -L. -ldecimal or add $OUTPUT_LIB to your project"
else
    echo "Error: Build failed - libbid.a not found"
    exit 1
fi
