using namespace System.Management.Automation
using namespace System.Collections

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
        $File,

        [string]
        $LogPath,

        [switch]
        $Append,

        [int]
        $TimeOut = 60,

        [ActionPreference]
        $JobInformationPreference = 'Continue',

        [ActionPreference]
        $JobDebugPreference = 'SilentlyContinue',

        [ActionPreference]
        $JobWarningPreference = 'Continue',

        [ActionPreference]
        $JobErrorActionPreference = 'Stop',

        [PSCronDateTime]
        $ReferenceDate = ( Get-PSCronDate ),

        [string]
        $Description,

        [switch]
        $PassThru
    
    )

    if ( -not( Test-PSCronShouldRun @PSBoundParameters ) ) {

        Write-Verbose ( 'SKIPPING: ' + $Name )
        return

    }

    # variable to hold log
    [ArrayList]$Script:__JobLog = @()

    # start timestamp
    $StartTime = Get-Date

    # write status to the screen in case job is run interactively
    ''.PadRight( 80, '-' ),
    ( 'Name:           ' + $Name ),
    ( 'Description:    ' + $Description ),
    ( 'Schedule:       ' + $Schedule ),
    ( 'Reference Date: ' + $ReferenceDate ),
    ( 'Started:        ' + $StartTime ) |
    ForEach-Object { Write-Information $_; $Script:__JobLog.Add( $_ ) > $null }

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
    
    # add an init script for default output settings
    $StreamPreferences = @(
        "`$Global:ProgressPreference     = 'SilentlyContinue'"
        "`$Global:InformationPreference  = '$JobInformationPreference'"
        "`$Global:DebugPreference        = '$JobDebugPreference'"
        "`$Global:WarningPreference      = '$JobWarningPreference'"
        "`$Global:ErrorActionPreference  = '$JobErrorActionPreference'"
    ) | Out-String
    $InitScript = [scriptblock]::Create( $StreamPreferences )
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

        Start-Sleep -Milliseconds 500

        # kill the job?
        if ( ( (Get-Date) - $StartTime ).TotalSeconds -gt $TimeOut ) {

            Write-Warning ( '{0} has timed out, the job was stopped after {1} seconds' -f $Name, $TimeOut )
            $PowerShell.RunSpace.Dispose() > $null
            $PowerShell.Stop() > $null

        }
    
    }

    # end timestamp
    $EndTime = Get-Date

    # calculate the job runtime
    [timespan]$RunTime = $EndTime - $StartTime

    # more logging
    ( 'Finished:       ' + $EndTime ),
    ( 'Elapsed:        {0} seconds' -f $RunTime.TotalSeconds ),
    ( 'Result:         ' + $PowerShell.InvocationStateInfo.State ),
    ( 'Errors:         ' + $PowerShell.HadErrors ),
    ''.PadRight( 80, '-' ) |
    ForEach-Object { Write-Information $_; $Script:__JobLog.Add( $_ ) > $null }

    # dump the job information streams collected by the events above
    $InfoStreamIndex = 0
    [ArrayList]$Streams = @()
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
            __AppendLog $_.TimeGenerated $_.OutputStream $_.MessageData

            # add to output streams
            $Streams.Add( $_ ) > $null
        
        }

    # if there is a TerminatingError attach to the log file
    if ( $PowerShell.InvocationStateInfo.Reason -is [Exception] ) {

        __AppendLog $EndTime 'ERROR' $PowerShell.InvocationStateInfo.Reason.ToString()
        
    }

    # if there is a -LogPath specified we output a log
    if ( $LogPath ) {

        # resolve the log path to a complete path
        $LogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath( $LogPath )

        # dump the log header
        $Script:__JobLog | Out-File -FilePath $LogPath -Append:$Append

    }

    # clean up events
    Get-Event -SourceIdentifier 'PSCronLog:*' | Remove-Event

    if ( $PassThru ) {

        # pass through the results
        [PSCustomObject][ordered]@{
            Name                = $Name
            Description         = $Description
            Source              = $PSCmdlet.ParameterSetName
            Definition          = $Definition.ToString()
            ReferenceDate       = $ReferenceDate
            StartTime           = $StartTime
            EndTime             = $EndTime
            RunTime             = $RunTime
            State               = $PowerShell.InvocationStateInfo.State
            Log                 = $Script:__JobLog | Out-String
            Output              = $Output
            Streams             = $Streams
            Errors              = [object[]]( $PowerShell.Streams.Error | ConvertTo-Json | ConvertFrom-Json )
            TerminatingError    = $( if ( $PowerShell.InvocationStateInfo.Reason -is [Exception] ) { $PowerShell.InvocationStateInfo.Reason } )
            HadErrors           = $PowerShell.HadErrors
        }

    }

    # clean up the runspace
    $PowerShell.RunSpace.Dispose() > $null
    $PowerShell.Dispose() > $null

}


# .ExternalHelp BW.Utils.PSCron-help.xml
function Send-PSCronNotification {

    param(

        [Parameter( Mandatory, ValueFromPipeline )]
        [object[]]
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

    begin {

        $SendOptions = @{
            BodyAsHtml = $true
        }
        'To', 'Cc', 'Bcc', 'From', 'SmtpServer', 'Priority', 'DeliveryNotificationOption', 'Credential', 'Port' |
            Where-Object { $_ -in $PSBoundParameters.Keys } |
            ForEach-Object { $SendOptions.$_ = $PSBoundParameters.$_ }

    }

    process {

        $CronResult | ForEach-Object {

            Send-MailMessage `
                -Subject ( $Subject -f $_.Name ) `
                -Body ( '<pre>{0}</pre>' -f ( $_.Log  ) ) `
                @SendOptions

            if ( $PassThru ) { $_ }

        }

    }
    
}
