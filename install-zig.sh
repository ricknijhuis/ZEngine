#!/bin/bash

# Default installation path
installPath="${1:-/opt/zig}"

# Function to check if Zig is in PATH
function isZigInPath() {
    type zig &>/dev/null
}

# Fetch the latest version of Zig
latestVersionData=$(curl -s https://ziglang.org/download/index.json | jq -r '.master')
latestVersion=$(echo "$latestVersionData" | jq -r '.version')
echo "Latest version available is: $latestVersion"

# Check the current installed version of Zig
currentVersion=""
if isZigInPath; then
    currentVersion=$(zig version)
fi

if [ -n "$currentVersion" ]; then
    echo "Current installed version is: $currentVersion"
else
    echo "No zig version found, doing clean install"
fi

# Install or update Zig if versions are different
if [ "$currentVersion" != "$latestVersion" ]; then
    latestBuildUrl=$(echo "$latestVersionData" | jq -r '."x86_64-linux".tarball')
    archiveName=$(basename "$latestBuildUrl")
    outputPath="/tmp/$archiveName"

    echo "Downloading Zig to: $outputPath"
    curl -L $latestBuildUrl -o "$outputPath"

    finalPath="$installPath/$(tar tf $outputPath | head -1 | cut -d/ -f1)"

    echo "Extracting Zig to: $installPath"
    mkdir -p "$installPath"
    tar -xf "$outputPath" -C "$installPath"
fi

# Update PATH if a new version was installed
if [ -n "$finalPath" ]; then
    # Remove old Zig path from PATH
    export PATH=$(echo "$PATH" | sed -e "s|:$installPath/[^:]*||g")

    # Add new Zig path to PATH
    export PATH="$PATH:$finalPath"
    echo "Set PATH to: $finalPath"
fi

# Verify Zig installation
if isZigInPath; then
    zigVersion=$(zig version)
    echo "Zig version: $zigVersion"
else
    echo "Failed to install Zig."
fi

echo $finalPath