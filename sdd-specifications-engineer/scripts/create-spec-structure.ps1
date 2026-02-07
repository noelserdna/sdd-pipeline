# create-spec-structure.ps1
# Creates the standard specification folder structure for a project
# Usage: .\create-spec-structure.ps1 -BasePath "path/to/project"

param(
    [Parameter(Mandatory=$true)]
    [string]$BasePath
)

$specsRoot = Join-Path $BasePath "specs"

$folders = @(
    "$specsRoot",
    "$specsRoot\SRS",
    "$specsRoot\functional",
    "$specsRoot\nonfunctional",
    "$specsRoot\interfaces",
    "$specsRoot\interfaces\api",
    "$specsRoot\interfaces\ui",
    "$specsRoot\interfaces\external-systems",
    "$specsRoot\data",
    "$specsRoot\constraints",
    "$specsRoot\modifications"
)

foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Host "Created: $folder"
    } else {
        Write-Host "Exists:  $folder"
    }
}

Write-Host "`nSpecification folder structure created at: $specsRoot"
