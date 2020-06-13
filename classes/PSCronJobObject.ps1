using namespace System.IO
using namespace System.Collections
using namespace System.Management.Automation
using namespace Microsoft.PowerShell

class PSCronJobObject {

    [ValidatePattern('^(?:\S+\s?){5}(?<!\s)$')][string]$Schedule
    [string]$Name
    [string]$Description
    [string]$Source
    [System.IO.FileInfo]$FilePath
    [ExecutionPolicy]$ExecutionPolicy = ( Get-ExecutionPolicy )
    [scriptblock]$Definition
    [System.IO.DirectoryInfo]$WorkingDirectory = ( [Environment]::SystemDirectory )
    [PSCronDateTime]$ReferenceDate = ( Get-PSCronDate )
    [PSCronDateTime]$StartDate = ( Get-PSCronDate -Resolution Millisecond )
    [PSCronDateTIme]$EndDate
    [nullable[timespan]]$RunTime
    [PSInvocationState]$State
    hidden [ArrayList]$__Log = @()
    [FileInfo]$LogPath
    [bool]$Append = $false
    [int]$TimeOut = 60
    [PSDataCollection[pscustomobject]]$Output
    [PSDataCollection[ErrorRecord]]$Errors
    [Exception]$TerminatingError
    [bool]$HadErrors
    [ActionPreference]$JobInformationPreference = 'Continue'
    [ActionPreference]$JobDebugPreference = 'SilentlyContinue'
    [ActionPreference]$JobWarningPreference = 'Continue'
    [ActionPreference]$JobErrorActionPreference = 'Stop'

    PSCronJobObject (){

        $this.__InitLog()
        $this.__InitMemberSet()

    }

    PSCronJobObject ( [hashtable]$Hashtable ) {

        $MyProperties = $this |
            Get-Member -MemberType Property |
            Select-Object -ExpandProperty Name

        $Hashtable.Keys |
            Where-Object { $_ -in $MyProperties } |
            ForEach-Object { 

                $this.$_ = $Hashtable.$_

            }

        $this.__InitLog()
        $this.__InitMemberSet()

    }

    hidden [void] __InitLog() {

        $this | Add-Member -Name Log -MemberType ScriptProperty -Value {

            $this.__Log | Out-String

        } -Force

        if ( -not $this.Append -and $this.LogPath -and ( Test-Path $this.LogPath -PathType Leaf ) ) {

            '' | Set-Content $this.LogPath -Force -Encoding UTF8 -NoNewline

        }

    }

    hidden [void] __InitMemberSet() {

        [string[]]$DefaultProperties = 'Name', 'Description', 'Schedule', 'Source', 'StartDate', 'EndDate', 'RunTime', 'Output', 'State', 'HadErrors'

        $DefaultDisplayPropertySet = [PSPropertySet]::new( 'DefaultDisplayPropertySet', $DefaultProperties )

        $PSStandardMembers = [PSMemberInfo[]]$DefaultDisplayPropertySet

        $this | Add-Member -MemberType MemberSet -Name 'PSStandardMembers' -Value $PSStandardMembers

    }

    [string] ToString() {

        return $this.Log

    }

    [void] LogRaw( [string]$MessageData ) {

        $this.__Log.Add( $MessageData )

        if ( $this.LogPath ) {
            
            $MessageData | Out-File -FilePath $this.LogPath.FullName -Append
            
        }
    
    }

    [void] LogMessage( [datetime]$TimeStamp, [string]$OutputStream, [string[]]$MessageData ) {
    
        $MessageData |
            ForEach-Object { $_  -split '[\r\n]+' } |
            ForEach-Object { '[{0:HH:mm:ss}] {1,-7} {2}' -f $TimeStamp, $OutputStream, $_ } |
            ForEach-Object { $this.LogRaw( $_ ) }

    }

    [SignatureStatus] SigningStatus() {

        if ( -not $this.FilePath ) { [SignatureStatus]::NotSupportedFileFormat }

        return ( Get-AuthenticodeSignature $this.FilePath ).Status

    }

    [bool] SignatureRequired() {

        return $this.SignatureRequired( $this.FilePath, $this.ExecutionPolicy )

    }

    [bool] SignatureRequired( [FileInfo]$FilePath, [ExecutionPolicy]$ExecutionPolicy ) {
    
        switch ( $ExecutionPolicy ) {
        
            'Bypass' {
                
                return $false
            
            }
    
            'Unrestricted' {
                
                return $false
            
            }
    
            'Default' {
            
                [bool]$ServerOS = Get-WmiObject -Query 'SELECT ProductType FROM Win32_OperatingSystem WHERE ProductType > 1'
    
                return $this.SignatureRequired( $FilePath, ( 'Restricted', 'RemoteSigned' )[ $ServerOS ] )
            
            }
    
            'RemoteSigned' {
            
                # if the file is downloaded then we will require a signature
                if ( [bool]( Get-Item $FilePath -Stream * | Where-Object { $_.Stream -eq 'Zone.Identifier' } ) ) {
                    
                    return $true
                
                }
    
                # otherwise we check if the file is on a UNC path
                $Uri = $null
                if ( [System.Uri]::TryCreate( $FilePath.FullName, [System.UriKind]::Absolute, ( [ref]$Uri ) ) -and $Uri.IsUnc ) {
                    
                    return $true
                
                }
    
                # in other cases file is local file and we should return false
                return $false
            
            }
        
        }

        # AllSigned / Restricted / Undefined
        return $true
    
    }

}

