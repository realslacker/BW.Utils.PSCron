---
external help file: BW.Utils.PSCron-help.xml
Module Name: BW.Utils.PSCron
online version:
schema: 2.0.0
---

# Invoke-PSCronJob

## SYNOPSIS
Runs a cron job.

## SYNTAX

### ScriptBlock (Default)
```
Invoke-PSCronJob [-Schedule] <String> [-Definition] <ScriptBlock> [[-ReferenceDate] <DateTime>]
 [-JobName <String>] [-TranscriptPath <String>] [-CallBack <String[]>] [<CommonParameters>]
```

### File
```
Invoke-PSCronJob [-Schedule] <String> [-Path] <FileInfo> [[-ReferenceDate] <DateTime>] [-JobName <String>]
 [-TranscriptPath <String>] [-CallBack <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Runs a cron job based on the defined schedule.

## EXAMPLES

### Example 1
```powershell
PS C:\> Invoke-PSCronJob '* * * * *' { return $true } -JobName 'Test Job'
```

Runs a job called 'Test Job' that returns $true every minute.

### Example 2
```powershell
PS C:\> Invoke-PSCronJob '* * * * *' { return $true } -JobName 'Test Job' -CallBack '__SendEmail'
```

Runs a job called 'Test Job' that returns $true every minute, then executes a function named '__SendEmail' with the job details.

## PARAMETERS

### -Schedule
The cron schedule to parse.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Definition
A ScriptBlock containing the job code to execute.

```yaml
Type: ScriptBlock
Parameter Sets: ScriptBlock
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
A file containing the job code to execute.

```yaml
Type: FileInfo
Parameter Sets: File
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReferenceDate
A reference date to use when executing the job. By default uses the current time.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: ( Get-PSCronTimestamp )
Accept pipeline input: False
Accept wildcard characters: False
```

### -JobName
The name of the job. Used for logging.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 'UNDEFINED'
Accept pipeline input: False
Accept wildcard characters: False
```

### -TranscriptPath
Where the transcript should go. Defaults to a temporary file. Note that job transcripts could contain sensitive information and are not automatically cleaned up.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: ( New-TemporaryFile )
Accept pipeline input: False
Accept wildcard characters: False
```

### -CallBack
A call back function or functions to execute after the job has completed.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
