# Get SHA-1 hash from debug keystore
$sha1Output = keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android 2>&1
$sha1Line = $sha1Output | Select-String -Pattern "SHA1"
$sha1Hash = ($sha1Line -split ':')[1].Trim()

Write-Host "SHA-1 Hash: $sha1Hash"

# Remove colons and convert to bytes
$hexString = $sha1Hash -replace ':', ''
$bytes = @()
for ($i = 0; $i -lt $hexString.Length; $i += 2) {
    $bytes += [Convert]::ToByte($hexString.Substring($i, 2), 16)
}

# Convert to Base64 URL-safe
$base64 = [Convert]::ToBase64String($bytes)
$base64UrlSafe = $base64 -replace '\+', '-' -replace '/', '_' -replace '=', ''

Write-Host "Base64 URL-safe Signature Hash: $base64UrlSafe"
Write-Host ""
Write-Host "Use this hash in your redirect URI: msauth://com.example.khonology_app/$base64UrlSafe"

