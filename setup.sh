#!/usr/bin/env bash

# Base URL for the git repository containing the tech packs
base_url="https://git.codelinaro.org/clo"
# Directory where downloaded XML files will be stored
download_dir="clo"

# Check if necessary commands are installed
for cmd in wget xmlstarlet; do
    command -v "$cmd" &> /dev/null || {
        echo "Error: $cmd is not installed. Please install and retry." >&2
        exit 1
    }
done

# Re-gerenate the download directory
rm -rf "$download_dir"
mkdir -p "$download_dir"

# Declaration of versions using associative arrays
declare -A versions=(
    [camera]="AU_TECHPACK_CAMERA.LA.2.0.R1.00.00.00.000.118"
    [display]="AU_TECHPACK_DISPLAY.LA.2.0.R1.00.00.00.000.130"
    [kernelplatform]="AU_LINUX_KERNEL.PLATFORM.1.0.R1.00.00.00.000.177"
    [qssi_system]="AU_LINUX_ANDROID_LA.QSSI.14.0.R1.14.00.00.1001.149.00"
    [system]="AU_LINUX_ANDROID_LA.QSSI.12.0.R1.11.00.00.782.140.00"
    [vendor]="AU_LINUX_ANDROID_LA.VENDOR.1.0.R1.11.00.00.816.255"
    [le]="LE.UM.5.3.1.r1-20300-genericarmv8-64.0"
    [video]="AU_TECHPACK_VIDEO.LA.2.0.R1.00.00.00.000.102"
    [def_system]="default_LA.QSSI.12.0.r1-14000-qssi.0"
)

# Loop through each tech pack and process accordingly
for key in "${!versions[@]}"; do
    filename="${versions[$key]}.xml"
    file_path="$download_dir/${key}.xml"

    # Determine the correct URL based on the key
    case $key in
        camera | display | video)
            url="$base_url/la/techpack/$key/manifest/-/raw/release/$filename"
            ;;
        kernelplatform)
            url="$base_url/la/$key/manifest/-/raw/release/$filename"
            ;;
        qssi_system)
            url="$base_url/la/la/system/manifest/-/raw/release/$filename"
            ;;
        system | vendor)
            url="$base_url/la/la/$key/manifest/-/raw/release/$filename"
            ;;
        le)
            url="$base_url/le/le/manifest/-/raw/release/$filename"
            ;;
        def_system)
            url="$base_url/la/la/system/manifest/-/raw/release/$filename"
            ;;
    esac

    # Download the file if it does not already exist
    if [ ! -f "$file_path" ]; then
        echo "Downloading $file_path from $url"
        wget -q -O "$file_path" "$url" || {
            echo "Failed to download $filename from $url" >&2
            continue
        }
    fi

    # Remove unnecessary elements from the downloaded XML files
    xmlstarlet ed -L -d "//remote | //default | //refs" "$file_path"

    # Apply XML modifications only for kernelplatform
    if [ "$key" == "kernelplatform" ]; then
        xmlstarlet ed -L \
            -d "/manifest/project[contains(@name, 'prebuilts')]/@revision" \
            -r "/manifest/project[contains(@name, 'prebuilts')]/@upstream" -v "revision" \
            "$file_path"

        xmlstarlet ed -L \
            -i "/manifest/project[contains(@name, 'prebuilts')]" -t attr -n "clone-depth" -v "1" \
            "$file_path"
    fi

    # Apply XML modifications only for system
    if [ "$key" == "def_system" ]; then
        project_names=$(xmlstarlet sel -t -m "//project[@clone-depth='1']" -v "@name" -n "$file_path")

        for name in $project_names; do
            xmlstarlet ed -L \
                -d "/manifest/project[@name='$name']/@revision" \
                -r "/manifest/project[@name='$name']/@upstream" -v "revision" \
                "$download_dir/system.xml"

            xmlstarlet ed -L \
                -s "/manifest/project[@name='$name']" -t attr -n "clone-depth" -v "1" \
                "$download_dir/system.xml"
        done

        rm -rf "$file_path"
    fi
done

echo "Setting up manifest completed successfully."
