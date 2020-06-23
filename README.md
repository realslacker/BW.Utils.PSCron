# BW.Utils.PSCron
Run PowerShell scripts as scheduled jobs.

This module allows you to create a cron script that runs every minute.
Individual jobs will only run if the schedule matches the current referece
date.

## Example Cron Script
This example script is intended to showcase some of the features of PSCron.
Your cron script might be signed and run as a scheduled task. Cron scripts
are intended to run every minute, and the individual jobs will only run if
the schedule matches.

```powershell
# We require the BW.Utils.PSCron module in the beginning of the script to
# make sure it's loaded.
#Requires -Modules BW.Utils.PSCron

# We generate a reference date in case the cron script runs longer than a
# minute. This allows all of the schedules to be evaluated against the same
# datetime object.
$ReferenceDate = Get-PSCronDate

# PSCronDateTime objects include both a local and utc timestamp, but you can
# use either as a regular datetime object. For example we can use the local
# time to generate a log file name.
$LogFileTimestamp = $ReferenceDate.Local.ToString('yyyy-MM-dd-HHmm')

# if you put your cron file in source control it's a good idea to put a
# .gitignore file in the logs folder
$LogFileName = "$PSScriptRoot\logs\cron-$LogFileTimestamp.log"

# Here we use splatting to combine common cron options
$CronSplat = @{
    ReferenceDate = $ReferenceDate
    LogPath       = $LogFileName
    Append        = $true
    TimeOut       = 600
}

# Here is an example job that exports a list of running processes to CSV
# every hour. See crontab.guru for cron syntax.
# Note: This job will not have any output since we did not specify the -PassThru
# parameter.
Invoke-PSCronJob '0 * * * *' 'Export Processes Job' { Get-Process | Export-Csv -Path "$env:TEMP\processes.csv" } @CronSplat

# This job will throw an error, and use the included Send-PSCronNotification to
# tell you about it. You can use the source of Send-PSCronNotification to create
# cron job pipeline handlers. To see what's properties are available try manually
# running a job with the -PassThru parameter.
Invoke-PSCronJob '* * * * *' 'Test Job Failure' { throw 'A very vebose error!' } @CronSplat -PassThru |
    Where-Object { $_.HadErrors -eq $true } |
    Send-PSCronNotification -To 'youremail@mail.server' -SmtpServer smtp.gmail.com -Port 587

# Finally, let's clean up our log files older than 7 days
Get-ChildItem -Path "$PSScriptRoot\logs" -Filter *.log |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item -Confirm:$false -Force -ErrorAction SilentlyContinue

```