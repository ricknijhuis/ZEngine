param($installPath = "C:\Program Files\zig")

$path = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
$latestVersionData = Invoke-WebRequest -Uri "https://ziglang.org/download/index.json" | ConvertFrom-Json | Select-Object -ExpandProperty master
$latestVersion = $latestVersionData.version
$currentVersion = $null
$finalPath = $null
Write-Host "Latest version available is:" $latestVersion

if (Get-Command "zig" -ErrorAction SilentlyContinue) {
    $currentVersion = zig version
}

if($null -ne $currentVersion) 
{
    Write-Host "Current installed version is:" $currentVersion
} else 
{
    Write-Host "No zig version found, doing clean install"
}

if($currentVersion -ne $latestVersion) {
    $latestBuildUrl = $latestVersionData.'x86_64-windows'.tarball
    $archiveName = $latestBuildUrl.Split("/")[-1]
    $outputPath = "$env:TEMP\$archiveName"

    Write-Host "Downloading zig to: $outputPath"
    Invoke-WebRequest -Uri $latestBuildUrl -OutFile $outputPath

    $finalPath = Join-Path -Path $installPath -ChildPath (Get-Item $outputPath).BaseName

    Write-Host $finalPath
    Write-Host "Extracting zig to: $installPath"
    Expand-Archive -Path $outputPath -DestinationPath $installPath -Force
}

if($null -ne $finalPath) {

    # remove old version from PATH
    $path = $path.TrimEnd(';')
    $path = ($path.Split(';') | Where-Object { $_ -notlike "*zig*$currentVersion"}) + $finalPath
    $path = $path -join ';'

    # add new version to PATH
    [System.Environment]::SetEnvironmentVariable('Path', $path, [System.EnvironmentVariableTarget]::Machine)

    # update current process as well
    $env:Path += ";$finalPath"

    Write-Host "Set path to: $finalPath"
}

if(Get-Command "zig" -ErrorAction SilentlyContinue)
{
    $zigVersion = zig version
    Write-Host "Zig version: $zigVersion"
} else 
{
    Write-Error "Failed to either install zig or set the correct path"
}

return $finalPath
