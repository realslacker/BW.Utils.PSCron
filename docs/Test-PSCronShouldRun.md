---
external help file: BW.Utils.PSCron-help.xml
Module Name: BW.Utils.PSCron
online version:
schema: 2.0.0
---

# Test-PSCronShouldRun

## SYNOPSIS
Checks based on the schedule and reference date if a job should run.

## SYNTAX

```
Test-PSCronShouldRun [-Schedule] <String> [[-ReferenceDate] <PSCronDateTime>] [<CommonParameters>]
```

## DESCRIPTION
Checks based on the schedule and reference date if a job should run.

## EXAMPLES

### Example 1
```powershell
PS C:\> Test-CronShouldRun '* * * * *' -ReferenceDate (Get-PSCronDate)
```

Returns $true since this job runs every minute.

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

### -ReferenceDate
A reference date to use when testing if the schedule should run.

```yaml
Type: PSCronDateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: ( Get-PSCronDate )
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Object

## OUTPUTS

### System.Boolean

## NOTES

## RELATED LINKS
