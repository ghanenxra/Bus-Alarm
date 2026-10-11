# Run test suite and verifications
Write-Host "Running backend automated test suite..."
Set-Location -Path "$PSScriptRoot\..\backend"
python -m pytest -v
if ($LASTEXITCODE -ne 0) {
    Write-Error "Backend tests failed!"
    exit $LASTEXITCODE
}
Write-Host "All backend checks passed successfully."

