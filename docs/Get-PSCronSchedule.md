---
external help file: BW.Utils.PSCron-help.xml
Module Name: BW.Utils.PSCron
online version:
schema: 2.0.0
---

# Get-PSCronSchedule

## SYNOPSIS
Parse a given cron schedule.

## SYNTAX

```
Get-PSCronSchedule [-Schedule] <String> [[-Start] <DateTime>] [[-End] <DateTime>] [<CommonParameters>]
```

## DESCRIPTION
Parse a given cron schedule. Returns all execution times in the time range. The default range is the next 24 hours.

## EXAMPLES

### Example 1
```powershell
PS C:\> Get-PSCronSchedule '*/15 1 * * *'
```

Will return 1:00, 1:15, 1:30, 1:45.

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

### -Start
A beginning datetime object.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: ( Get-PSCronTimestamp -Resolution Day )
Accept pipeline input: False
Accept wildcard characters: False
```

### -End
An ending datetime object.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: ( Get-PSCronTimestamp -Resolution Day ).AddDays( 1 )
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Object

## OUTPUTS

### System.DateTime[]

## NOTES

## RELATED LINKS
