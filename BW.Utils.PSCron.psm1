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

    $CronSchedule = [Cronos.CronExpression]::Parse( $Schedule )
    
    $NextRun = $CronSchedule.GetNextOccurrence( $ReferenceDate, [System.TimeZoneInfo]::Local, $true )

    Write-Information ( 'DateTime objects are in UTC. The next run in local time: ' + $NextRun.ToLocalTime() )

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

        [Parameter( Mandatory, Position=3, ParameterSetName='File' )]
        [string]
        $Path,

        [string]
        $LogPath,

        [switch]
        $Append,

        [datetime]
        $ReferenceDate = ( Get-PSCronTimestamp ),

        [switch]
        $PassThru
    
    )

    if ( -not( Test-PSCronShouldRun @PSBoundParameters ) ) {

        Write-Verbose ( 'SKIPPING: ' + $Name )
        return

    }

    if ( $PSBoundParameters.Keys -notcontains 'InformationAction' ) { $InformationPreference = 'Continue' }

    # get the job code either from a PS1 file or as the value of the scriptblock
    if ( $PSCmdlet.ParameterSetName -eq 'File' ) {

        if ( -not( $Code = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue ) ) {

            Write-Warning ( 'Failed to load job definition from file: {0}' -f $Path )
            return

        }

    } else {

        $Code = $Definition.ToString()

    }

    $Init = ''
    $Exit = ''

    $RemoveLog = $false

    # if -PassThru is specified we capture some data
    if ( $PassThru ) {

        # if no LogPath was specified we log to a temporary file
        if ( -not $LogPath ) {

            $LogPath = New-TemporaryFile

            $RemoveLog = $true
        
        }

        # temporary files for job output
        $ErrorsTemp = New-TemporaryFile
        $OutputTemp = New-TemporaryFile

        $Init = 'Invoke-Command -ScriptBlock {',
                '$ProgressPreference="SilentlyContinue"',
                '$InformationPreference="Continue"',
                '$WarningPreference="Continue"',
                '' -join "`r`n"

        $Exit = '',
                '} -ErrorVariable "JobErrors" -OutVariable "JobOutput"',
                "`$JobErrors | ConvertTo-Json -Depth 10 | Out-File -FilePath '$($ErrorsTemp.FullName)'",
                "`$JobOutput | ConvertTo-Json -Depth 10 | Out-File -FilePath '$($OutputTemp.FullName)'",
                '' -join "`r`n"

    }

    # convert command to byte array
    $CommandBytes = [System.Text.Encoding]::Unicode.GetBytes( $Init + $Code + $Exit )

    # base64 encode the command
    $CommandBase64 = [convert]::ToBase64String( $CommandBytes )

    # start timestamp
    $StartTime = (Get-Date).ToUniversalTime()

    # some logging
    ''.PadRight( 80, '-' ),
    ( 'Name:           ' + $Name ),
    ( 'Schedule:       ' + $Schedule ),
    ( 'Reference Date: ' + $ReferenceDate.ToLocalTime() ),
    ( 'Started:        ' + $StartTime.ToLocalTime() ) |
        Tee-Object -FilePath $LogPath -Append:$Append |
        ForEach-Object { Write-Information $_ }
    
    ''.PadRight( 80, '-' ),
    '' | Out-File -FilePath $LogPath -Append 

    # run powershell.exe and output the response to the log file
    if ( $LogPath ) {

        powershell.exe -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $CommandBase64 *>&1 >> "$LogPath"

    } else {

        powershell.exe -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $CommandBase64 *>&1 >> $null

    }

    # save the exit code
    $ExitCode = $LASTEXITCODE

    # end timestamp
    $EndTime = (Get-Date).ToUniversalTime()

    # calculate the job runtime
    [timespan]$RunTime = $EndTime - $StartTime

    # more logging
    '',
    ''.PadRight( 80, '-' ) |
        Out-File -FilePath $LogPath -Append 
    
    ( 'Finished:       ' + $StartTime.ToLocalTime() ),
    ( 'Elapsed:        {0} seconds' -f $RunTime.TotalSeconds ),
    ''.PadRight( 80, '-' ),
    '' |
        Tee-Object -FilePath $LogPath -Append |
        ForEach-Object { Write-Information $_ }

    if ( $PassThru ) {

        # get the results
        $LogContent = Get-Content -Path $LogPath
        $JobErrors  = Get-Content -Path $ErrorsTemp | ConvertFrom-Json
        $JobOutput  = Get-Content -Path $OutputTemp | ConvertFrom-Json

        # remove the temporary files
        $ErrorsTemp, $OutputTemp | Remove-Item -Force -Confirm:$false

        # if the log file was just a temp file we remove that
        if ( $RemoveLog ) {

            Remove-Item -Path $LogPath -Force -Confirm:$false
    
        }

        # pass through the results
        [PSCustomObject][ordered]@{
            Name            = $Name
            Source          = $PSCmdlet.ParameterSetName
            Definition      = $Code
            ReferenceDate   = $ReferenceDate
            StartTime       = $StartTime
            EndTime         = $EndTime
            RunTime         = $RunTime
            Result          = $LogContent
            Output          = $JobOutput
            Errors          = $JobErrors
        }

    }

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
        Body        = '<pre>{0}</pre>' -f ( $CronResult.Result -join "`n" )
        BodyAsHtml  = $true
    }

    'To', 'Cc', 'Bcc', 'From', 'SmtpServer', 'Priority', 'DeliveryNotificationOption', 'Credential', 'Port' |
        Where-Object { $_ -in $PSBoundParameters.Keys } |
        ForEach-Object { $MessageSplat.$_ = $PSBoundParameters.$_ }

    Send-MailMessage @MessageSplat

    if ( $PassThru ) { $CronResult }
    
}
