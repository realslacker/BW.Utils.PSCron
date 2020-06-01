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

        [Parameter( Mandatory, Position=2, ParameterSetName='ScriptBlock' )]
        [scriptblock]
        $Definition,

        [Parameter( Mandatory, Position=2, ParameterSetName='File' )]
        [System.IO.FileInfo]
        $Path,

        [datetime]
        $ReferenceDate = ( Get-PSCronTimestamp ),

        [string]
        $JobName = 'UNDEFINED',

        [string]
        $TranscriptPath = ( New-TemporaryFile ),

        [string[]]
        $CallBack
    
    )

    if ( -not( Test-PSCronShouldRun @PSBoundParameters ) ) {

        Write-Verbose ( 'SKIPPING: ' + $JobName )
        return

    }

    $StartTime = (Get-Date).ToUniversalTime()

    ''.PadRight( 80, '-' ),
    ( 'RUNNING: ' + $JobName ),
    ( 'Job started at {0}' -f $StartTime.ToLocalTime() ),
    ( 'Schedule reference date is {0}' -f $ReferenceDate.ToLocalTime() ),
    ''.PadRight( 80, '-' ),
    '' |
        Tee-Object -FilePath $TranscriptPath |
        ForEach-Object { Write-Verbose $_ }

    if ( $PSCmdlet.ParameterSetName -eq 'File' ) {

        if ( -not( $Code = Get-Content -Path $Path -ErrorAction SilentlyContinue ) ) {

            Write-Warning ( 'Failed to load job definition from file: {0}' -f $Path )
            return

        }

        $Definition = [scriptblock]::Create( $Code )

    }

    $Init = [scriptblock]::Create((
        '$ProgressPreference="SilentlyContinue"',
        '$InformationPreference="Continue"',
        '$WarningPreference="Continue"',
        '$VerbosePreference="Continue"',
        "Start-Transcript -Path '$TranscriptPath' -Append -Force;" -join ';'
    ))

    $Result = Start-Job -ScriptBlock $Definition -InitializationScript $Init |
        Receive-Job -AutoRemoveJob -Wait *>&1

    $CallBack |
        ForEach-Object {

            & $_ $JobName $ReferenceDate $StartTime $PSCmdlet.ParameterSetName $Definition.ToString() $Result $TranscriptPath

        }

    Write-Verbose ''
    Write-Verbose ''

}

