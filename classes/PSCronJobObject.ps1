using namespace System.IO
using namespace System.Collections
using namespace System.Management.Automation
using namespace Microsoft.PowerShell

class PSCronJobObject {

    [ValidatePattern('^(?:\S+\s?){5}(?<!\s)$')][string]$Schedule
    [string]$Name
    [string]$Description
    [string]$Source
    hidden [System.IO.FileInfo]$__FilePath
    hidden [ExecutionPolicy]$__ExecutionPolicy = ( Get-ExecutionPolicy )
    [scriptblock]$Definition
    [System.IO.DirectoryInfo]$WorkingDirectory = ( [Environment]::SystemDirectory )
    [PSCronDateTime]$ReferenceDate = ( Get-PSCronDate )
    [PSCronDateTime]$StartDate = ( Get-PSCronDate -Resolution Millisecond )
    [PSCronDateTIme]$EndDate
    [nullable[timespan]]$RunTime
    [PSInvocationState]$State
    hidden [ArrayList]$__Log = @()
    [FileInfo]$LogPath
    hidden [bool]$__Append = $false
    [int]$TimeOut = 60
    [PSDataCollection[pscustomobject]]$Output
    [PSDataCollection[ErrorRecord]]$Errors
    [Exception]$TerminatingError
    [bool]$HadErrors
    [ActionPreference]$JobInformationPreference = 'Continue'
    [ActionPreference]$JobDebugPreference = 'SilentlyContinue'
    [ActionPreference]$JobWarningPreference = 'Continue'
    [ActionPreference]$JobErrorActionPreference = 'Stop'

    PSCronJobObject( [hashtable]$Hashtable ) {

        $this.__Init( $Hashtable )

    }

    hidden [void] __Init( [hashtable]$Hashtable ) {

        # get all object properties
        [string[]]$MyProperties = $this |
            Get-Member -MemberType Property -Force |
            Select-Object -ExpandProperty Name

        # set initial property values and property readers for hidden
        # properties
        $MyProperties | ForEach-Object {

            $KeyName = $_ -replace '^__'
            
            # initialize property values
            if ( $KeyName -in $Hashtable.Keys ) {

                $this.$_ = $Hashtable.$KeyName

            }

            # configure read only properties, except Log which is handled
            # below
            if ( $KeyName -ne $_ ) {

                $this | Add-Member -MemberType ScriptProperty -Name $KeyName -Value ( [scriptblock]::Create( "`$this.$_" ) )            

            }

        }

        # configure the SigningStatus property
        $this | Add-Member -Name SigningStatus -MemberType ScriptProperty -Value {

            if ( -not $this.FilePath ) { [SignatureStatus]::NotSupportedFileFormat }

            return ( Get-AuthenticodeSignature $this.FilePath ).Status

        }

        # configure the SignatureRequired property
        $this | Add-Member -Name SignatureRequired -MemberType ScriptProperty -Value {

            return $this.__SignatureRequired( $this.FilePath, $this.ExecutionPolicy )

        }

        # override the Log property since we handle that in a special way
        $this | Add-Member -Name Log -MemberType ScriptProperty -Value {

            $this.__Log | Out-String

        } -Force

        # override the FilePath property since we handle that in a special way
        $this | Add-Member -Name FilePath -MemberType ScriptProperty -Value {

            $this.__FilePath

        } -SecondValue {

            param(

                [ValidateNotNullOrEmpty()]
                [System.IO.FileInfo]
                $FilePath

            )

            $this.__FilePath = $FilePath

            if ( -not $this.SignatureRequired -or  $this.SigningStatus -eq 'Valid' ) {

                $this.Definition = [scriptblock]::Create( ( Get-Content $this.__FilePath | Out-String ) )
    
            } else {
    
                Write-Warning 'Failed authenticode signature validation for file:'
                Write-Warning $this.__FilePath
    
                $this.Definition = {
    
                    throw [System.Management.Automation.PSSecurityException]::new( 'Invalid Authenticode Signature' )
    
                }
    
            }
        } -Force

        # rerun assignment for $FilePath to initialize properly
        if ( $Hashtable.FilePath ) { $this.FilePath = $Hashtable.FilePath }

        # setup the default display property set
        [string[]]$DefaultProperties = 'Name', 'Description', 'Schedule', 'Source', 'StartDate', 'EndDate', 'RunTime', 'Output', 'State', 'HadErrors'

        $DefaultDisplayPropertySet = [PSPropertySet]::new( 'DefaultDisplayPropertySet', $DefaultProperties )

        $PSStandardMembers = [PSMemberInfo[]]$DefaultDisplayPropertySet

        $this | Add-Member -MemberType MemberSet -Name 'PSStandardMembers' -Value $PSStandardMembers

    }

    [string] ToString() {

        return $this.Log

    }

    [void] LogRaw( [string]$MessageData ) {

        # the first time this function is called ( $this-__Log.Count -eq 0 )
        # and we are overwritting the log ( -not $this.__Append ) and the log
        # path is set we overwrite any existing log
        $Append = -not ( $this.__Log.Count -eq 0 -and -not $this.__Append -and $this.LogPath )

        $this.__Log.Add( $MessageData )

        if ( $this.LogPath ) {
            
            $MessageData | Out-File -FilePath $this.LogPath.FullName -Append:$Append -Encoding UTF8
            
        }
    
    }

    [void] LogMessage( [datetime]$TimeStamp, [string]$OutputStream, [string[]]$MessageData ) {
    
        $MessageData |
            ForEach-Object { $_  -split '[\r\n]+' } |
            ForEach-Object { '[{0:HH:mm:ss}] {1,-7} {2}' -f $TimeStamp, $OutputStream, $_ } |
            ForEach-Object { $this.LogRaw( $_ ) }

    }

    hidden [bool] __SignatureRequired( [FileInfo]$FilePath, [ExecutionPolicy]$ExecutionPolicy ) {
    
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

