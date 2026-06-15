function Get-SchemaFields {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$SchemaDir = $PSScriptRoot
    )
    $path = Join-Path $SchemaDir "$Name.json"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "schema file not found: $path"
    }
    $schema = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    return @($schema.fields)
}

Export-ModuleMember -Function Get-SchemaFields
