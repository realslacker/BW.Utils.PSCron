Describe 'BW.Utils.PSCron' {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should load all functions' {
            $Commands = @( Get-Command -CommandType Function -Module BW.Utils.PSCron | Select-Object -ExpandProperty Name )
            $Commands.Count | Should -Be 6
            $Commands -contains 'Get-PSCronDate' | Should -Be $true
            $Commands -contains 'Test-PSCronShouldRun' | Should -Be $true
            $Commands -contains 'Get-PSCronNextRun' | Should -Be $true
            $Commands -contains 'Get-PSCronSchedule' | Should -Be $true
            $Commands -contains 'Invoke-PSCronJob' | Should -Be $true
            $Commands -contains 'Send-PSCronNotification' | Should -Be $true
        }
        It 'should load all aliases' {
            $Commands = @( Get-Command -CommandType Alias -Module BW.Utils.PSCron | Select-Object -ExpandProperty Name )
            $Commands.Count | Should -Be 0
        }
    }
}

Describe 'Get-PSCronDate' {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should accept a positional parameter for -Date' {
            { Get-PSCronDate (Get-Date) } | Should -Not -Throw
        }
        It 'should accept a positional parameter for -Resolution' {
            { Get-PSCronDate (Get-Date) 'Minute' } | Should -Not -Throw
        }
        It 'should accept a [string] for -Date' {
            { Get-PSCronDate '8:00 PM' } | Should -Not -Throw
        }
        It 'should return a [PSCronDateTime] object' {
            Get-PSCronDate | Should -BeOfType [PSCronDateTime]
        }
        It 'should have a Local property' {
            $ReturnValue = Get-PSCronDate
            $ReturnValue.Local | Should -BeOfType [datetime]
            $ReturnValue.Local.Kind | Should -Be 'Local'
        }
        It 'should have a Utc property' {
            $ReturnValue = Get-PSCronDate
            $ReturnValue.Utc | Should -BeOfType [datetime]
            $ReturnValue.Utc.Kind | Should -Be 'Utc'
        }
        It 'should have equal values for Local and Utc' {
            $ReturnValue = Get-PSCronDate
            $ReturnValue.Local -eq $ReturnValue.Utc.ToLocalTime() | Should -Be $true
        }
    }
}

Describe 'Test-PSCronShouldRun' {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should accept a positional parameter for -Schedule' {
            { Test-PSCronShouldRun '* * * * *' } | Should -Not -Throw
        }
        It 'should accept a positional parameter for -ReferenceDate' {
            { Test-PSCronShouldRun '* * * * *' (Get-Date) } | Should -Not -Throw
        }
        It 'should return a [bool] object' {
            Test-PSCronShouldRun -Schedule '* * * * *' | Should -BeOfType [bool]
        }
        It 'should return $true for the schedule * * * * *' {
            Test-PSCronShouldRun -Schedule '* * * * *' | Should -Be $true
        }
        It 'should return $true when the -ReferenceDate is right now' {
            Test-PSCronShouldRun -Schedule '* * * * *' -ReferenceDate (Get-Date) | Should -Be $true
        }
        It 'should return $false when the -Schedule does not match the current time and no -ReferenceDate is supplied' {
            $Schedule = (Get-Date).AddMinutes(10).ToString( 'm * * * *' )
            Test-PSCronShouldRun -Schedule $Schedule | Should -Be $false
        }
        It 'should return $true when the -Schedule matches the -ReferenceDate' {
            Test-PSCronShouldRun -Schedule '15 0 * * *' -ReferenceDate (Get-Date -Date '0:15') | Should -Be $true
        }
        It 'should return $false when the -Schedule does not match the -ReferenceDate' {
            Test-PSCronShouldRun -Schedule '15 0 * * *' -ReferenceDate (Get-Date -Date '0:00') | Should -Be $false
        }
    }
}

Describe 'Get-PSCronNextRun' {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should accept a positional parameter for -Schedule' {
            { Get-PSCronNextRun '* * * * *' } | Should -Not -Throw
        }
        It 'should accept a positional parameter for -ReferenceDate' {
            { Get-PSCronNextRun '* * * * *' (Get-Date) } | Should -Not -Throw
        }
        It 'should ignore additional arguments' {
            { Get-PSCronNextRun '* * * * *' -FakeArgument } | Should -Not -Throw
        }
        It 'should return a [PSCronDateTime] object' {
            Get-PSCronNextRun -Schedule '* * * * *' | Should -BeOfType [PSCronDateTime]
        }
        It 'should return one minute in the future for the schedule * * * * *' {
            Get-PSCronNextRun -Schedule '* * * * *' | Should -Be (Get-PSCronDate -Date (Get-Date).AddMinutes(1) )
        }
        It 'should return the current time for the schedule * * * * * with the -Inclusive switch' {
            Get-PSCronNextRun -Schedule '* * * * *' -Inclusive | Should -Be (Get-PSCronDate)
        }
        It 'should return a future result when the schedule matches the current time' {
            $Schedule = (Get-Date).ToString( 'm * * * *' )
            $Expected = Get-PSCronDate -Date (Get-Date).AddHours(1)
            Get-PSCronNextRun -Schedule $Schedule | Should -Be $Expected
        }
        It 'should return the current time when the schedule matches the current time with the -Inclusive switch' {
            $Schedule = (Get-Date).ToString( 'm * * * *' )
            Get-PSCronNextRun -Schedule $Schedule -Inclusive | Should -Be (Get-PSCronDate)
        }
        It 'should return a future result when the schedule matches the -ReferenceDate' {
            $Reference = Get-Date
            $Schedule = $Reference.ToString( 'm * * * *' )
            $Expected = Get-PSCronDate -Date $Reference.AddHours(1)
            Get-PSCronNextRun -Schedule $Schedule -ReferenceDate $Reference | Should -Be $Expected
        }
        It 'should return the $ReferenceDate when the schedule matches the -ReferenceDate with the -Inclusive switch' {
            $Reference = Get-Date
            $Schedule = $Reference.ToString( 'm * * * *' )
            Get-PSCronNextRun -Schedule $Schedule -Inclusive | Should -Be (Get-PSCronDate -Date $Reference)
        }
    }
}

Describe 'Get-PSCronSchedule' {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should accept a positional parameter for -Schedule' {
            { Get-PSCronSchedule '0 0 * * *' } | Should -Not -Throw
        }
        It 'should accept a positional parameter for -Start' {
            { Get-PSCronSchedule '0 0 * * *' (Get-Date) } | Should -Not -Throw
        }
        It 'should accept a positional parameter for -End' {
            { Get-PSCronSchedule '0 0 * * *' (Get-Date) (Get-Date) } | Should -Not -Throw
        }
        It 'should ignore additional arguments' {
            { Get-PSCronSchedule '0 0 * * *' -FakeArgument } | Should -Not -Throw
        }
        It 'should return a collection of [PSCronDateTime] objects' {
            $Schedule = Get-PSCronSchedule -Schedule '0 */4 * * *'
            $Schedule | Should -HaveCount 6
            $Schedule | Where-Object { $_ -is [PSCronDateTime] } | Should -HaveCount 6
        }
    }
}

Describe 'Invoke-PSCronJob' {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should accept a positional parameter for -Schedule' {
            $Schedule = (Get-Date).AddMinutes(-1).ToString( 'm * * * *' )
            { Invoke-PSCronJob $Schedule -Name 'Fake Job' -Definition {$true} } | Should -Not -Throw
        }
        It 'should accept a positional parameter for -Name' {
            $Schedule = (Get-Date).AddMinutes(-1).ToString( 'm * * * *' )
            { Invoke-PSCronJob $Schedule 'Fake Job' -Definition {$true} } | Should -Not -Throw
        }
        It 'should accept a positional parameter for -Definition' {
            $Schedule = (Get-Date).AddMinutes(-1).ToString( 'm * * * *' )
            { Invoke-PSCronJob $Schedule -Name 'Fake Job' -Definition {$true} } | Should -Not -Throw
        }
        It 'should accept a -FilePath' {
            $Schedule = (Get-Date).AddMinutes(-1).ToString( 'm * * * *' )
            $File = New-TemporaryFile | %{ '$true' | Set-Content -Path $_; $_.FullName }
            { Invoke-PSCronJob $Schedule 'Fake Job' -FilePath $File } | Should -Not -Throw
            Remove-Item -Path $File -Force -Confirm:$false
        }
        It 'should create a log file if -LogPath is specified and the job runs' {
            $File = New-TemporaryFile | Select-Object -ExpandProperty FullName
            Remove-Item -Path $File -Force -Confirm:$false
            { Invoke-PSCronJob '* * * * *' 'Fake Job' { Write-Host 'Create Log' } -LogPath $File } | Should -Not -Throw
            Test-Path -Path $File | Should -Be $true
            Remove-Item -Path $File -Force -Confirm:$false
        }
        It 'should overwrite a log file if -LogPath is specified and the job runs' {
            $File = New-TemporaryFile | Select-Object -ExpandProperty FullName
            Set-Content -Path $File -Value 'EXISTING CONTENT'
            { Invoke-PSCronJob '* * * * *' 'Fake Job' { Write-Host 'Create Log' } -LogPath $File } | Should -Not -Throw
            Test-Path -Path $File | Should -Be $true
            Get-Content -Path $File | Select-Object -First 1 | Should -Not -Be 'EXISTING CONTENT'
            Remove-Item -Path $File -Force -Confirm:$false
        }
        It 'should not overwrite a log file if -LogPath and -Append is specified and the job runs' {
            $File = New-TemporaryFile | Select-Object -ExpandProperty FullName
            Set-Content -Path $File -Value 'EXISTING CONTENT'
            { Invoke-PSCronJob '* * * * *' 'Fake Job' { Write-Host 'Create Log' } -LogPath $File -Append } | Should -Not -Throw
            Test-Path -Path $File | Should -Be $true
            Get-Content -Path $File | Select-Object -First 1 | Should -Be 'EXISTING CONTENT'
            Remove-Item -Path $File -Force -Confirm:$false
        }
        It 'should not run if the -Schedule does not match the -ReferenceDate' {
            $Reference = Get-Date
            $Schedule = $Reference.AddMinutes(-1).ToString( 'm H * * *' )
            $Result = Invoke-PSCronJob $Schedule 'Fake Job' {$true} -ReferenceDate $Reference -PassThru
            $null -eq $Result | Should -Be $true
        }
        It 'should run if the -Schedule does match the -ReferenceDate' {
            $Reference = Get-Date
            $Schedule = $Reference.ToString( 'm H * * *' )
            $Result = Invoke-PSCronJob $Schedule 'Fake Job' {$true} -ReferenceDate $Reference -PassThru
            $null -eq $Result | Should -Be $false
        }
        It 'should have all information streams represented in the log' {
            $Result = Invoke-PSCronJob '* * * * *' 'Fake Job' {
                Write-Information 'Write-Information'
                Write-Host 'Write-Host'
                Write-Debug 'Write-Debug'
                Write-Warning 'Write-Warning'
                Write-Error 'Write-Error'
            } -PassThru -JobDebugPreference Continue -JobErrorActionPreference Continue
            $Result.Log | Should -Match 'Write-Information'
            $Result.Log | Should -Match 'Write-Host'
            $Result.Log | Should -Match 'Write-Debug'
            $Result.Log | Should -Match 'Write-Warning'
            $Result.Log | Should -Match 'Write-Error'
        }
        It 'should have state Failed, HadErrors set to $true, and TerminatingError populated when there is a terminating error' {
            $Result = Invoke-PSCronJob '* * * * *' 'Fake Job' { Write-Error 'Fake Error' } -PassThru
            $Result.State | Should -Be 'Failed'
            $Result.HadErrors | Should -Be $true
            $Result.TerminatingError | Should -BeOfType [System.Management.Automation.ActionPreferenceStopException]
        }
        It 'should have state Completed, HadErrors set to $true, and Errors populated when there is a non-terminating error' {
            $Result = Invoke-PSCronJob '* * * * *' 'Fake Job' { Write-Error 'Fake Error' -ErrorAction Continue } -PassThru
            $Result.State | Should -Be 'Completed'
            $Result.HadErrors | Should -Be $true
            $Result.Errors.Count | Should -BeGreaterThan 0
        }
        It 'should have state Completed, HadErrors set to $true, and Errors populated when -JobErrorActionPreference = Continue' {
            $Result = Invoke-PSCronJob '* * * * *' 'Fake Job' { Write-Error 'Fake Error' } -JobErrorActionPreference Continue -PassThru
            $Result.State | Should -Be 'Completed'
            $Result.HadErrors | Should -Be $true
            $Result.Errors.Count | Should -BeGreaterThan 0
        }
        It 'should have state Stopped, HadErrors set to $true, and TerminatingError populated if the job exceeds the -TimeOut' {
            $Result = Invoke-PSCronJob '* * * * *' 'Fake Job' { Start-Sleep -Seconds 60 } -TimeOut 1 -PassThru -WarningAction SilentlyContinue
            $Result.State | Should -Be 'Stopped'
            $Result.HadErrors | Should -Be $true
            $Result.TerminatingError | Should -BeOfType [System.Management.Automation.PipelineStoppedException]
        }
        It 'should execute jobs in the diretory supplied to -WorkingDirectory' {
            $TempPath = [System.IO.Path]::GetFullPath( $env:TEMP )
            $Result = Invoke-PSCronJob '* * * * *' 'Fake Job' { $PWD } -WorkingDirectory $TempPath -PassThru
            $Result.Output[0].Path | Should -Be $TempPath
        }
        It 'should place the path to the job script in the $Global:PSCronFile variable' {
            $File = New-TemporaryFile | Select-Object -ExpandProperty FullName
            Set-Content -Path $File -Value '$Global:PSCronFile'
            $Result = Invoke-PSCronJob '* * * * *' 'Fake Job' -FilePath $File -PassThru
            $Result.Output[0] | Should -Be $File
            Remove-Item $File
        }
    }
}