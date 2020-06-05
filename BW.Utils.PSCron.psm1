using namespace System.Management.Automation
using namespace System.Collections

$__ScriptPath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition -Parent

Add-Type -Path "$__ScriptPath\lib\Cronos-0.7.0\netstandard2.0\Cronos.dll"

# .ExternalHelp BW.Utils.PSCron-help.xml
function Get-PSCronTimestamp {

    [OutputType( [datetime] )]
    param(
    
        [Parameter(Position=1)]
        [datetime]
        $Date = ( [datetime]::UtcNow ),
        
        [Parameter(Position=2)]
        [ValidateSet( 'Second', 'Minute', 'Hour', 'Day' )]
        [string]
        $Resolution = 'Minute'
        
    )

    if ( $Date.Kind -ne 'Utc' ) {
    
        $Date = $Date.ToUniversalTime()
        
    }

    $Ticks = switch ( $Resolution ) {
        
        'Second' { [timespan]::TicksPerSecond }
        'Minute' { [timespan]::TicksPerMinute }
        'Hour'   { [timespan]::TicksPerHour   }
        'Day'    { [timespan]::TicksPerDay    }
    
    }

    return [datetime]::new( $Date.Ticks - ( $Date.Ticks % $Ticks ), $Date.Kind )

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Test-PSCronShouldRun {

    [OutputType( [bool] )]
    param(

        [Parameter( Mandatory, Position=1 )]
        [string]
        $Schedule,

        [Parameter( Position=2 )]
        [datetime]
        $ReferenceDate = ( Get-PSCronTimestamp ),

        [Parameter( ValueFromRemainingArguments, DontShow )]
        $IgnoredArguments

    )

    return ( Get-PSCronNextRun @PSBoundParameters ) -eq $ReferenceDate

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Get-PSCronNextRun {

    [OutputType( [datetime] )]
    [CmdletBinding()]
    param(

        [Parameter(Mandatory, Position=1)]
        [string]
        $Schedule,

        [Parameter( Position=2 )]
        [datetime]
        $ReferenceDate = ( Get-PSCronTimestamp ),

        [Parameter( ValueFromRemainingArguments, DontShow )]
        $IgnoredArguments

    )

    if ( $ReferenceDate.Kind -ne 'Utc' ) {

        $ReferenceDate = $ReferenceDate.ToUniversalTime()

    }

    $CronSchedule = [Cronos.CronExpression]::Parse( $Schedule )
    
    $NextRun = $CronSchedule.GetNextOccurrence( $ReferenceDate, [System.TimeZoneInfo]::Local, $true )

    Write-Verbose ( 'DateTime objects are in UTC. The next run in local time: ' + $NextRun.ToLocalTime() )

    return $NextRun

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Get-PSCronSchedule {

    [OutputType( [datetime[]] )]
    param(

        [Parameter(Mandatory, Position=1)]
        [string]
        $Schedule,

        [Parameter(Position=2)]
        [datetime]
        $Start = ( Get-PSCronTimestamp -Resolution Day ),

        [Parameter(Position=3)]
        [datetime]
        $End = ( Get-PSCronTimestamp -Resolution Day ).AddDays( 1 ),

        [Parameter( ValueFromRemainingArguments, DontShow )]
        $IgnoredArguments

    )

    if ( $Start.Kind -ne 'Utc' ) {

        $Start = $Start.ToUniversalTime()

    }

    if ( $End.Kind -ne 'Utc' ) {

        $End = $End.ToUniversalTime()

    }

    $CronSchedule = [Cronos.CronExpression]::Parse( $Schedule )
    
    return $CronSchedule.GetOccurrences( $Start, $End )

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
        $File,

        [string]
        $LogPath,

        [switch]
        $Append,

        [int]
        $TimeOut = 60,

        [datetime]
        $ReferenceDate = ( Get-PSCronTimestamp ),

        [switch]
        $PassThru
    
    )

    if ( $ReferenceDate.Kind -ne 'Utc' ) {

        $ReferenceDate = $ReferenceDate.ToUniversalTime()

    }

    if ( -not( Test-PSCronShouldRun @PSBoundParameters ) ) {

        Write-Verbose ( 'SKIPPING: ' + $Name )
        return

    }

    # variable to hold log
    [ArrayList]$JobLog = @()

    # start timestamp
    $StartTime = (Get-Date).ToUniversalTime()

    # write status to the screen in case job is run interactively
    ''.PadRight( 80, '-' ),
    ( 'Name:           ' + $Name ),
    ( 'Schedule:       ' + $Schedule ),
    ( 'Reference Date: ' + $ReferenceDate.ToLocalTime() ),
    ( 'Started:        ' + $StartTime.ToLocalTime() ) |
    ForEach-Object { Write-Information $_; $JobLog.Add( $_ ) > $null }

    # create a powershell runspace
    $PowerShell = [PowerShell]::Create( [RunspaceMode]::NewRunspace )

    # create events for logging
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
    
    # add an init script for default output settings
    [scriptblock]$InitScript = {
        $ProgressPreference     = 'SilentlyContinue'
        $InformationPreference  = 'Continue'
        $WarningPreference      = 'Continue'
        $ErrorActionPreference  = 'Stop'
    }
    $PowerShell.AddScript( $InitScript, $true ) > $null

    # if a file is provided we extract the code
    if ( $File ) {

        $File = Resolve-Path $File | Select-Object -ExpandProperty Path
        
        $Definition = [scriptblock]::Create( ( Get-Content $File | Out-String ) )

    }
    
    # add the script
    $PowerShell.AddScript( $Definition, $true ) > $null

    # container for output
    $Output = New-Object 'System.Management.Automation.PSDataCollection[psobject]'

    # run the script
    $Handle = $PowerShell.BeginInvoke( $Output, $Output )

    # wait for completion
    while ( -not $Handle.IsCompleted ) {

        # kill the job?
        if ( ( (Get-Date).ToUniversalTime() - $StartTime ).TotalSeconds -gt $TimeOut ) {

            Write-Warning ( '{0} has timed out, the job was stopped after {1} seconds' -f $Name, $TimeOut ) -WarningAction Continue
            $PowerShell.Stop() > $null

        }
        
        Start-Sleep -Milliseconds 100
    
    }

    # end timestamp
    $EndTime = (Get-Date).ToUniversalTime()

    # calculate the job runtime
    [timespan]$RunTime = $EndTime - $StartTime

    # more logging
    ( 'Finished:       ' + $StartTime.ToLocalTime() ),
    ( 'Elapsed:        {0} seconds' -f $RunTime.TotalSeconds ),
    ( 'Result:         ' + $PowerShell.InvocationStateInfo.State ),
    ( 'Errors:         ' + $PowerShell.HadErrors ),
    ''.PadRight( 80, '-' ) |
    ForEach-Object { Write-Information $_; $JobLog.Add( $_ ) > $null }

    # dump the job information streams
    Get-Event -SourceIdentifier 'PSCronLog:*' |
        ForEach-Object { '[{0:HH:mm:ss}] {1,-7} {2}' -f $_.TimeGenerated, $_.SourceIdentifier.Split(':')[1].ToUpper(), $_.MessageData } |
        ForEach-Object { $JobLog.Add( $_ ) > $null }

    # if there is a -LogPath specified we output a log
    if ( $LogPath ) {

        # resolve the log path to a complete path
        $LogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath( $LogPath )

        # dump the log header
        $JobLog | Out-File -FilePath $LogPath -Append:$Append

    }

    # clean up events
    Get-Event -SourceIdentifier 'PSCronLog:*' | Remove-Event

    if ( $PassThru ) {

        # pass through the results
        [PSCustomObject][ordered]@{
            Name            = $Name
            Source          = $PSCmdlet.ParameterSetName
            Definition      = $Definition.ToString()
            ReferenceDate   = $ReferenceDate
            StartTime       = $StartTime
            EndTime         = $EndTime
            RunTime         = $RunTime
            State           = $PowerShell.InvocationStateInfo.State
            Log             = $JobLog | Out-String
            Output          = $Output
            Errors          = [object[]]( $PowerShell.Streams.Error | ConvertTo-Json | ConvertFrom-Json )
            HadErrors       = $PowerShell.HadErrors
        }

    }

    # clean up the runspace
    $PowerShell.Dispose()

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Send-PSCronNotification {

    param(

        [Parameter( Mandatory, ValueFromPipeline )]
        [object]
        $CronResult,

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

    $MessageSplat = @{
        Subject     = $Subject -f $CronResult.Name
        Body        = '<pre>{0}</pre>' -f ( $CronResult.Log  )
        BodyAsHtml  = $true
    }

    'To', 'Cc', 'Bcc', 'From', 'SmtpServer', 'Priority', 'DeliveryNotificationOption', 'Credential', 'Port' |
        Where-Object { $_ -in $PSBoundParameters.Keys } |
        ForEach-Object { $MessageSplat.$_ = $PSBoundParameters.$_ }

    Send-MailMessage @MessageSplat

    if ( $PassThru ) { $CronResult }
    
}
