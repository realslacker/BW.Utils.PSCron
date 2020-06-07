[CmdletBinding(DefaultParameterSetName='DoNothing')]
param(
    
    [Parameter(ParameterSetName='Publish')]
    [switch]
    $Publish,

    [Parameter(ParameterSetName='Publish', Mandatory)]
    [string]
    $Repository,

    [Parameter(ParameterSetName='Publish', Mandatory)]
    [string]
    $NuGetApiKey
)

# files and directories to include
# {0} will be replace by the module name
$FilesToInclude = @(
    '{0}.psd1'
    '{0}.psm1'
    'lib'
    'classes'
)

# module variables
$ModulePath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition -Parent
$ModuleName = Split-Path $ModulePath -Leaf

# create build directory
$BuildNumber = Get-Date -Format y.M.d.Hmm
$BuildDirectory = New-Item -Path "$ModulePath\build\$BuildNumber\$ModuleName" -ItemType Directory -ErrorAction Stop

# copy needed files
$FilesToInclude |
    ForEach-Object { $_ -f $ModuleName } |
    ForEach-Object { Join-Path $ModulePath $_ } |
    Get-Item -ErrorAction SilentlyContinue |
    Copy-Item -Destination $BuildDirectory -Recurse

# include all help files / directories
Get-ChildItem -Path $ModulePath -Directory |
    Where-Object { Get-ChildItem -Path $_.FullName -Filter '*-help.xml' } |
    Copy-Item -Destination $BuildDirectory -Recurse

# update the build version
$ModuleManifestSplat = @{
    Path              = "$BuildDirectory\$ModuleName.psd1"
    ModuleVersion     = $BuildNumber
    FunctionsToExport = '*-*'
}
Update-ModuleManifest @ModuleManifestSplat

# check for a signing cert
$CodeSigningCert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue

# sign the build
if ( $CodeSigningCert ) {

    if ( $CodeSigningCert.Count -gt 1 ) {

        $CodeSigningCert = $CodeSigningCert | Out-GridView -Title 'Choose a Code Signing Cert' -OutputMode Single

    }

    '*.psm1', '*.ps1' |
        ForEach-Object {
            
            Get-ChildItem -Path $BuildDirectory -Filter $_ -Recurse |
                Set-AuthenticodeSignature -Certificate $CodeSigningCert -TimestampServer 'http://timestamp.comodoca.com/authenticode'
        
        }

}

switch ( $PSCmdlet.ParameterSetName ) {

    'DoNothing' {

        Write-Host ''
        Write-Host 'Build Complete!' -ForegroundColor Green
        Write-Host "Build Directory: $BuildDirectory"
        Write-Host ''
        Write-Host 'Don''t forget to update the docs!'

    }

    # publish the module after build
    'Publish' {

        Publish-Module -Path "$BuildDirectory" -Repository $Repository -NuGetApiKey $NuGetApiKey

    }

}

