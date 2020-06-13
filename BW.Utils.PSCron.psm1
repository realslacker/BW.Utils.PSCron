using namespace System.Management.Automation
using namespace System.Collections
using namespace Microsoft.PowerShell

$__ScriptPath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition -Parent
[ArrayList]$__JobLog = @()

Add-Type -Path "$__ScriptPath\lib\Cronos-0.7.0\netstandard2.0\Cronos.dll"

function __AppendLog {

    param(
    
        [datetime]
        $TimeGenerated,
        
        [string]
        $OutputStream,
        
        [string[]]
        $MessageData
        
    )

    $MessageData |
        ForEach-Object { $_  -split '[\r\n]+' } |
        ForEach-Object { '[{0:HH:mm:ss}] {1,-7} {2}' -f $TimeGenerated, $OutputStream, $_ } |
        ForEach-Object { $Script:__JobLog.Add( $_ ) > $null }

}

function __SignatureRequired {

    param(

        [string]
        $Path,

        [ExecutionPolicy]
        $ExecutionPolicy = ( Get-ExecutionPolicy )

    )

    switch ( $ExecutionPolicy ) {
    
        # Requires that all scripts and configuration files be signed by a trusted publisher, including scripts that you write on the local computer.
        'AllSigned' { $true }

        # Nothing is blocked and there are no warnings or prompts.
        'Bypass' { $false }

        'Default' {
        
            [bool]$ServerOS = Get-WmiObject -Query 'SELECT ProductType FROM Win32_OperatingSystem WHERE ProductType > 1'

            return __SignatureRequired $Path ( 'Restricted', 'RemoteSigned' )[ $ServerOS ]
        
        }

        'RemoteSigned' {
        
            # if the file is downloaded then we will require a signature
            if ( [bool]( Get-Item $Path -Stream * | Where-Object { $_.Stream -eq 'Zone.Identifier' } ) ) { return $true }

            # otherwise we check if the file is on a UNC path
            $Uri = $null
            if ( [System.Uri]::TryCreate( $Path, [System.UriKind]::Absolute, ( [ref]$Uri ) ) -and $Uri.IsUnc ) { return $true }

            # in other cases return false
            return $false
        
        }

        'Restricted' {

            throw 'Scripts are not allowed when execution policy is Restricted'

        }

        'Undefined' {

            throw 'Scripts are not allowed when execution policy is Undefined'

        }

        'Unrestricted' { $false }

        default { $true }
    
    }

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Get-PSCronDate {

    [OutputType( [PSCronDateTime] )]
    param(
    
        [Parameter(Position=1)]
        [datetime]
        $Date = ( Get-Date ),
        
        [Parameter(Position=2)]
        [PSCronTicks]
        $Resolution = [PSCronTicks]::Minute
        
    )

    return [PSCronDateTime]::new( $Date, $Resolution )

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Test-PSCronShouldRun {

    [OutputType( [bool] )]
    [CmdletBinding()]
    param(

        [Parameter( Mandatory, Position=1 )]
        [string]
        $Schedule,

        [Parameter( Position=2 )]
        [PSCronDateTime]
        $ReferenceDate = ( Get-PSCronDate ),

        [Parameter( ValueFromRemainingArguments, DontShow )]
        $IgnoredArguments

    )

    $ThisRun = Get-PSCronNextRun -Schedule $Schedule -ReferenceDate $ReferenceDate -Inclusive

    return $ThisRun -eq $ReferenceDate

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Get-PSCronNextRun {

    [OutputType( [PSCronDateTime] )]
    [CmdletBinding()]
    param(

        [Parameter(Mandatory, Position=1)]
        [string]
        $Schedule,

        [Parameter( Position=2 )]
        [PSCronDateTime]
        $ReferenceDate = ( Get-PSCronDate ),

        [switch]
        $Inclusive,

        [Parameter( ValueFromRemainingArguments, DontShow )]
        $IgnoredArguments

    )

    $Offset = $ReferenceDate.Local - $ReferenceDate.Utc

    $ReferenceDate = $ReferenceDate + $Offset

    $CronSchedule = [Cronos.CronExpression]::Parse( $Schedule )
    
    [PSCronDateTime]$NextRun = $CronSchedule.GetNextOccurrence( $ReferenceDate.Utc, [System.TimeZoneInfo]::Utc, $Inclusive )

    return ( $NextRun - $Offset )

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Get-PSCronSchedule {

    [OutputType( [PSCronDateTime[]] )]
    param(

        [Parameter(Mandatory, Position=1)]
        [string]
        $Schedule,

        [Parameter(Position=2)]
        [PSCronDateTime]
        $Start = ( Get-PSCronDate -Resolution Day ),

        [Parameter(Position=3)]
        [PSCronDateTime]
        $End = ( Get-PSCronDate -Date (Get-Date).AddDays( 1 ) -Resolution Day ),

        [switch]
        $IncludeStart,

        [switch]
        $IncludeEnd,

        [Parameter( ValueFromRemainingArguments, DontShow )]
        $IgnoredArguments

    )

    $CronSchedule = [Cronos.CronExpression]::Parse( $Schedule )
    
    return [PSCronDateTime[]]$CronSchedule.GetOccurrences( $Start.Utc, $End.Utc, $IncludeStart, $IncludeEnd )

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Invoke-PSCronJob {
    
    [CmdletBinding( DefaultParameterSetName='ScriptBlock' )]
    param(
    
        [Parameter( Mandatory, Position=1 )]
        [string]
        $Schedule,

        [Parameter( Mandatory, Position=2 )]
        [string]
        $Name,

        [Parameter( Mandatory, Position=3, ParameterSetName='ScriptBlock' )]
        [scriptblock]
        $Definition,

        [Parameter( Mandatory, ParameterSetName='File' )]
        [string]
        $FilePath,

        [string]
        $Description,

        [string]
        $WorkingDirectory,

        [string]
        $LogPath,

        [switch]
        $Append,

        [int]
        $TimeOut,

        [ActionPreference]
        $JobInformationPreference,

        [ActionPreference]
        $JobDebugPreference,

        [ActionPreference]
        $JobWarningPreference,

        [ActionPreference]
        $JobErrorActionPreference,

        [PSCronDateTime]
        $ReferenceDate,

        [switch]
        $PassThru
    
    )

    if ( -not( Test-PSCronShouldRun @PSBoundParameters ) ) {

        Write-Verbose ( 'SKIPPING: ' + $Name )
        return

    }

    # resolve -FilePath to a full path
    if ( $PSBoundParameters.ContainsKey( 'FilePath' ) ) {

        $PSBoundParameters['FilePath'] = $FilePath = Resolve-Path $FilePath -ErrorAction Stop |
            Select-Object -ExpandProperty Path

    }

    # resolve -WorkingDirectory to a full path
    if ( $PSBoundParameters.ContainsKey( 'WorkingDirectory' ) ) {

        $PSBoundParameters['WorkingDirectory'] = $WorkingDirectory = Resolve-Path $WorkingDirectory -ErrorAction Stop |
            Select-Object -ExpandProperty Path

    }

    # resolve -LogPath to a full path
    if ( $PSBoundParameters.ContainsKey( 'LogPath' ) ) {

        $LogFile      = Split-Path $LogPath -Leaf
        $LogDirectory = Split-Path $LogPath -Parent

        $PSBoundParameters['LogPath'] = $LogPath = Resolve-Path $LogDirectory -ErrorAction Stop |
            Select-Object -ExpandProperty Path |
            ForEach-Object {
                
                $LogDirectory = $_
                Join-Path $LogDirectory $LogFile
            
            }

    }
    
    # initialize a cron result object
    $CronJob = [PSCronJobObject]::new( $PSBoundParameters )
    $CronJob.Source = $PSCmdlet.ParameterSetName

    # create a powershell runspace
    $PowerShell = [PowerShell]::Create( [RunspaceMode]::NewRunspace )

    # create events for logging streams
    Register-ObjectEvent -InputObject $PowerShell.Streams.Information -EventName DataAdded -Action {
    
        New-Event -SourceIdentifier 'PSCronLog:Info' -MessageData $Event.Sender[-1].MessageData
    
    } > $null

    Register-ObjectEvent -InputObject $PowerShell.Streams.Verbose -EventName DataAdded -Action {
    
        New-Event -SourceIdentifier 'PSCronLog:Verbose' -MessageData $Event.Sender[-1].Message
    
    } > $null
    
    Register-ObjectEvent -InputObject $PowerShell.Streams.Debug -EventName DataAdded -Action {
    
        New-Event -SourceIdentifier 'PSCronLog:Debug' -MessageData $Event.Sender[-1].Message
    
    } > $null
    
    Register-ObjectEvent -InputObject $PowerShell.Streams.Warning -EventName DataAdded -Action {
    
        New-Event -SourceIdentifier 'PSCronLog:Warning' -MessageData $Event.Sender[-1].Message
    
    } > $null
    
    Register-ObjectEvent -InputObject $PowerShell.Streams.Error -EventName DataAdded -Action {
    
        New-Event -SourceIdentifier 'PSCronLog:Error' -MessageData ( '{0}: {1}' -f $Event.Sender[-1].FullyQualifiedErrorId, $Event.Sender[-1].Exception.Message )
        
    } > $null
    
    # create an init script for default output settings
    [ArrayList]$StreamPreferences = @(
        "`$Global:ProgressPreference     = 'SilentlyContinue'"
        "`$Global:InformationPreference  = '$($CronJob.JobInformationPreference)'"
        "`$Global:DebugPreference        = '$($CronJob.JobDebugPreference)'"
        "`$Global:WarningPreference      = '$($CronJob.JobWarningPreference)'"
        "`$Global:ErrorActionPreference  = '$($CronJob.JobErrorActionPreference)'"
    )

    # if a working directory is provided we switch to that location in the init script
    if ( $CronJob.WorkingDirectory ) {

        $StreamPreferences.Add( "Set-Location -Path '$($CronJob.WorkingDirectory)' -ErrorAction Stop" ) > $null
        
    }

    # we add a variable to the $StreamPreferences with the $File name
    if ( $CronJob.FilePath ) {

        $StreamPreferences.Add( "`$Global:PSCronFile = '$($CronJob.FilePath)'" ) > $null

    }

    # add the init script
    $InitScript = [scriptblock]::Create( ( $StreamPreferences | Out-String ) )
    $PowerShell.AddScript( $InitScript, $true ) > $null
    
    # add the script
    $PowerShell.AddScript( $CronJob.Definition, $true ) > $null

    # collection for output
    # note: input cannot be assigned directly to the PSCronJobObject.Output property
    # because of the variable reference scope
    $Output = New-Object 'System.Management.Automation.PSDataCollection[psobject]'

    # run the script
    $Handle = $PowerShell.BeginInvoke( $Output, $Output )

    # wait for completion
    while ( -not $Handle.IsCompleted ) {

        Start-Sleep -Milliseconds 500

        # kill the job?
        if ( ( (Get-Date) - ([datetime]$CronJob.StartDate) ).TotalSeconds -gt $CronJob.TimeOut ) {

            Write-Warning ( '{0} has timed out, the job was stopped after {1} seconds' -f $CronJob.Name, $CronJob.TimeOut )
            $PowerShell.RunSpace.Dispose() > $null
            $PowerShell.Stop() > $null

        }
    
    }

    # record the results
    $CronJob.Output = $Output
    $CronJob.State = $PowerShell.InvocationStateInfo.State
    $CronJob.HadErrors = $PowerShell.HadErrors

    # end timestamp
    $CronJob.EndDate = Get-PSCronDate -Resolution Millisecond

    # calculate the job runtime
    $CronJob.RunTime = $CronJob.EndDate - $CronJob.StartDate

    # write status to the screen in case job is run interactively
    ''.PadRight( 80, '-' ),
    ( 'Name:           ' + $CronJob.Name ),
    ( 'Description:    ' + $CronJob.Description ),
    ( 'Schedule:       ' + $CronJob.Schedule ),
    ( 'Reference Date: ' + $CronJob.ReferenceDate ),
    ( 'Started:        ' + $CronJob.StartDate ),
    ( 'Finished:       ' + $CronJob.EndDate ),
    ( 'Elapsed:        {0} seconds' -f $CronJob.RunTime.TotalSeconds ),
    ( 'Result:         ' + $PowerShell.InvocationStateInfo.State ),
    ( 'Errors:         ' + $PowerShell.HadErrors ),
    ''.PadRight( 80, '-' ) |
    ForEach-Object { $CronJob.LogRaw( $_ ) }

    # dump the job information streams collected by the events above
    $InfoStreamIndex = 0
    Get-Event -SourceIdentifier 'PSCronLog:*' |
        Select-Object TimeGenerated, @{N='OutputStream';E={$_.SourceIdentifier.Split(':')[1].ToUpper()}}, MessageData |
        ForEach-Object {
            
            # do some hacky shit since the info events contain all the output
            # for some reason
            if ( $_.OutputStream -eq 'INFO' ) {

                # get the corresponding info object from the RunSpace
                $RunSpaceInfo = $PowerShell.Streams.Information[ $InfoStreamIndex ]

                # replace the MessageData
                $_.MessageData = $RunSpaceInfo.MessageData

                # if the $RunSpaceInfo has the 'PSHOST' tag it's from Write-Host,
                # change the OutputStream to 'HOST'
                if ( $RunSpaceInfo.Tags -contains 'PSHOST' ) {

                    $_.OutputStream = 'HOST'

                }

                # increment the counter
                $InfoStreamIndex ++

            }
        
            # send to JobLog
            $CronJob.LogMessage( $_.TimeGenerated, $_.OutputStream, $_.MessageData )
        
        }

    # if there are non-terminating errors attach them
    if ( $PowerShell.Streams.Error.Count -gt 0 ) {

        $CronJob.Errors = $PowerShell.Streams.Error |
            ForEach-Object { $_ }

    }

    # if there is a TerminatingError attach to the log file
    if ( $PowerShell.InvocationStateInfo.Reason -is [Exception] ) {

        $CronJob.LogMessage( $CronJob.EndDate, 'ERROR', $PowerShell.InvocationStateInfo.Reason.ToString() )

        $CronJob.TerminatingError = $PowerShell.InvocationStateInfo.Reason
        
    }

    # clean up events
    Get-Event -SourceIdentifier 'PSCronLog:*' | Remove-Event

    # clean up the runspace
    $PowerShell.RunSpace.Dispose() > $null
    $PowerShell.Dispose() > $null

    # pass through the job?
    if ( $PassThru ) { $CronJob }

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Send-PSCronNotification {

    param(

        [Parameter( Mandatory, ValueFromPipeline )]
        [PSCronJobObject[]]
        $CronJob,

        [Parameter( Mandatory )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $To,

        [ValidateNotNullOrEmpty()]
        [string[]]
        $Cc,

        [ValidateNotNullOrEmpty()]
        [string[]]
        $Bcc,

        [Parameter( Mandatory )]
        [ValidateNotNullOrEmpty()]
        [string]
        $From,

        [Alias( 'ComputerName' )]
        [ValidateNotNullOrEmpty()]
        [string]
        $SmtpServer,

        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.MailPriority]
        $Priority,

        [Alias( 'DNO' )]
        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.DeliveryNotificationOptions]
        $DeliveryNotificationOption,

        [Alias('sub')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Subject = '[CRON] {0}',

        [ValidateNotNullOrEmpty()]
        [pscredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [switch]
        $UseSsl,

        [ValidateRange(0, 2147483647)]
        [int]
        $Port,

        [switch]
        $PassThru
        
    )

    begin {

        $SendOptions = @{
            BodyAsHtml = $true
        }
        'To', 'Cc', 'Bcc', 'From', 'SmtpServer', 'Priority', 'DeliveryNotificationOption', 'Credential', 'Port' |
            Where-Object { $_ -in $PSBoundParameters.Keys } |
            ForEach-Object { $SendOptions.$_ = $PSBoundParameters.$_ }

    }

    process {

        $CronJob | ForEach-Object {

            $_.LogMessage( (Get-Date), 'INFO', 'Send-PSCronNotification - Sending notifications...' )

            Send-MailMessage `
                -Subject ( $Subject -f $_.Name ) `
                -Body ( '<pre>{0}</pre>' -f ( $_.Log  ) ) `
                @SendOptions

            if ( $PassThru ) { $_ }

        }

    }
    
}
