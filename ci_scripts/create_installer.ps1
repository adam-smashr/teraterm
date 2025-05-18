# Before use this PowerShell script, install the SignPath module
# > Install-Module -Name SignPath

# Replace $API_TOKEN to your token.
#   string "Bearer " is unnecessary.
$API_TOKEN = "YOUR_API_TOKEN"
$ORGANIZATION_ID = "78e41f48-55fc-4f33-8ea5-08ac32f65ac8"
$PROJECT_SLUG = "teraterm"
$SIGNING_POLICY_SLUG = "test-signing"
$ARTIFACT_CONFIGURATION_SLUG = "installer"

$version = "TT_VERSION"

# filenames
$zipFilename = Join-Path $PSScriptRoot "teraterm-${version}.zip"
$zipPdbFilename = Join-Path $PSScriptRoot "teraterm-${version}_pdb.zip"
$zipExtractDir = Join-Path $PSScriptRoot "teraterm-${version}" # folder to extract to
$baseIssFilename = Join-Path $PSScriptRoot "teraterm.iss"
$issFilename = Join-Path $PSScriptRoot "teraterm-${version}.iss"
$installerFilename = Join-Path $PSScriptRoot "teraterm-${version}.exe"
$signedInstallerFilename = Join-Path $PSScriptRoot "teraterm-${version}_signed.exe"
$unsignedInstallerFilename = Join-Path $PSScriptRoot "teraterm-${version}_unsigned.exe"
$sha256sumFilename = Join-Path $PSScriptRoot "teraterm-${version}.sha256sum"
$sha512sumFilename = Join-Path $PSScriptRoot "teraterm-${version}.sha512sum"

# cleanup
if (Test-Path $zipExtractDir) {
    Remove-Item $zipExtractDir -Recurse
}
if (Test-Path $issFilename) {
    Remove-Item $issFilename
}
if (Test-Path $installerFilename) {
    Remove-Item $installerFilename
}
if (Test-Path $signedInstallerFilename) {
    Remove-Item $signedInstallerFilename
}
if (Test-Path $unsignedInstallerFilename) {
    Remove-Item $unsignedInstallerFilename
}

# extract zip file
Expand-Archive -Path $zipFilename -DestinationPath $PSScriptRoot

# rewrite iss
(Get-Content $baseIssFilename) `
    -replace 'LicenseFile=release\\license.txt', "LicenseFile=teraterm-${version}\license.txt" `
    -replace 'Source: \.\.\\teraterm\\release', "Source: teraterm-${version}" `
    -replace 'Source: release', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\doc\\en', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\doc\\ja', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\ttssh2\\ttxssh\\Release', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\cygwin\\cygterm\\cygterm\+-x86_64', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\cygwin\\cygterm', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\cygwin\\Release', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\ttpmenu\\Release', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\ttpmenu\\readme.txt', "Source: teraterm-${version}\ttmenu_readme-j.txt" `
    -replace 'Source: \.\.\\TTProxy\\Release', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\TTXKanjiMenu\\release', "Source: teraterm-${version}" `
    -replace 'Source: \.\.\\TTXSamples\\release', "Source: teraterm-${version}" `
| Set-Content $issFilename

# create installer
Start-Process -Wait `
              -FilePath "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" `
              -ArgumentList "`"$issFilename`" /DAppVer=${version} /O`"$PSScriptRoot`""

# request to SignPath
# https://about.signpath.io/documentation/powershell/Submit-SigningRequest
Submit-SigningRequest `
    -InputArtifactPath $installerFilename `
    -ProjectSlug $PROJECT_SLUG `
    -SigningPolicySlug $SIGNING_POLICY_SLUG `
    -ArtifactConfigurationSlug $ARTIFACT_CONFIGURATION_SLUG `
    -OutputArtifactPath $signedInstallerFilename `
    -WaitForCompletion `
    -OrganizationId $ORGANIZATION_ID `
    -ApiToken $API_TOKEN

# rename
Rename-Item $installerFilename $unsignedInstallerFilename
Rename-Item $signedInstallerFilename $installerFilename

# create checksum files
$files = @(
    $zipFilename,
    $zipPdbFilename,
    $installerFilename
)
$lines = foreach ($file in $files) {
    if (Test-Path $file) {
        $hash = Get-FileHash -Path "$file" -Algorithm SHA256
                             "{0}  {1}" -f $hash.Hash.ToLower(), (Split-Path $file -Leaf)
    }
}
$lines | Set-Content $sha256sumFilename
$lines = foreach ($file in $files) {
    if (Test-Path $file) {
        $hash = Get-FileHash -Path "$file" -Algorithm SHA512
                             "{0}  {1}" -f $hash.Hash.ToLower(), (Split-Path $file -Leaf)
    }
}
$lines | Set-Content $sha512sumFilename
