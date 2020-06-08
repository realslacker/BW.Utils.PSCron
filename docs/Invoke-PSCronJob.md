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
Invoke-PSCronJob [-Schedule] <String> -Name <String> [-Definition] <ScriptBlock> [-LogPath <String>] [-Append]
 [-Timeout <Int32>] [-JobInformationPreference <ActionPreference>] [-JobDebugPreference <ActionPreference>]
 [-JobWarningPreference <ActionPreference>] [-JobErrorPreference <ActionPreference>]
 [-ReferenceDate <PSCronDateTime>] [-PassThru] [<CommonParameters>]
```

### File
```
Invoke-PSCronJob [-Schedule] <String> -Name <String> -File <String> [-LogPath <String>] [-Append]
 [-TimeOut <Int32>] [-JobInformationPreference <ActionPreference>] [-JobDebugPreference <ActionPreference>]
 [-JobWarningPreference <ActionPreference>] [-JobErrorPreference <ActionPreference>]
 [-ReferenceDate <PSCronDateTime>] [-PassThru] [<CommonParameters>]
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
PS C:\> Invoke-PSCronJob '* * * * *' { return $true } -JobName 'Test Job' -PassThru
```

Runs a job called 'Test Job' that returns $true every minute, then puts the job result on the pipeline.

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

### -Name
The name of the job. Used for logging.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
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

### -File
A file containing the job code to execute.

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
Path where the log should be saved.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Append
Append to an existing log.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeOut
The number of seconds before the job is terminated.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReferenceDate
A reference date to use when executing the job.
By default uses the current time.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: ( Get-PSCronDate )
Accept pipeline input: False
Accept wildcard characters: False
```

### -JobDebugPreference
Sets the $DebugPreference in the job environment.

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -JobErrorActionPreference
Sets the $ErrorActionPreference in the job environment.

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -JobInformationPreference
Sets the $InformationPreference in the job environment.

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -JobWarningPreference
Sets the $WarningPreference in the job environment.

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description
A description to include in the job log and pass 
down the pipeline.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Pass through the CronResult object.

```yaml
Type: SwitchParameter
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
