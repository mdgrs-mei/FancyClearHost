
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace FancyClearHost {

public class Native
{
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int virtualKeyCode);

    public static void ClearBuffer(
        System.Management.Automation.Host.BufferCell[,] buffer,
        System.ConsoleColor foregroundColor,
        System.ConsoleColor backgroundColor)
    {
        int width = buffer.GetUpperBound(1);
        int height = buffer.GetUpperBound(0);
        var clearCell = new System.Management.Automation.Host.BufferCell(
            ' ',
            foregroundColor,
            backgroundColor,
            System.Management.Automation.Host.BufferCellType.Complete);

        for (int x = 0; x < width; ++x)
        {
            for (int y = 0; y < height; ++y)
            {
                buffer[y, x] = clearCell;
            }
        }
    }
}

}
"@

class RenderItem
{
    [System.Collections.Generic.List[System.Management.Automation.Host.BufferCell]]$cells = $null
    [Double]$x = 0.0
    [Double]$y = 0.0
    [Boolean]$isFinished = $false

    RenderItem($cell, $cellTrailing, $x, $y)
    {
        $this.cells = [System.Collections.Generic.List[System.Management.Automation.Host.BufferCell]]::new()
        $this.cells.Add($cell)
        if ($cellTrailing)
        {
            $this.cells.Add($cellTrailing)
        }
        $this.x = $x
        $this.y = $y
    }

    [Boolean] IsTwoCell()
    {
        return ($this.cells.Count -eq 2)
    }

    [void] Finish()
    {
        $this.isFinished = $true
    }

    [void] Render([System.Management.Automation.Host.BufferCell[,]]$buffer)
    {
        if ($this.isFinished)
        {
            return
        }

        $ix = [Int]$this.x
        $iy = [Int]$this.y

        $buffer[$iy, $ix] = $this.cells[0]
        if ($this.cells.Count -gt 1)
        {
            $buffer[$iy, ($ix+1)] = $this.cells[1]
        }
    }

    [void] SetCell($character, $foregroundColor, $backgroundColor)
    {
        foreach ($i in @(0..($this.cells.Count-1)))
        {
            $newCell = $this.cells[$i]
            if ($null -ne $character)
            {
                $newCell.Character = $character
                $newCell.BufferCellType = [System.Management.Automation.Host.BufferCellType]::Complete
            }
            if ($null -ne $foregroundColor)
            {
                $newCell.ForegroundColor = $foregroundColor
            }
            if ($null -ne $backgroundColor)
            {
                $newCell.BackgroundColor = $backgroundColor
            }
            $this.cells[$i] = $newCell
        }
    }
}

class LinearAnimation
{
    [Object[]]$values = $null
    [Double]$duration = 0.0
    [Double]$timer = 0.0

    LinearAnimation($values, $duration)
    {
        $this.values = $values
        $this.duration = $duration
    }

    [void] Update($dt)
    {
        $this.timer += $dt
    }

    [Object] GetValue()
    {
        [Int]$index = $this.values.Length * ($this.timer / $this.duration)
        $index = [Math]::Min($index, $this.values.Length-1)

        return $this.values[$index]
    }

    [Double] GetRatio()
    {
        return [Math]::Min($this.timer / $this.duration, 1.0)
    }

    [Boolean] IsFinished()
    {
        return ($this.timer -ge $this.duration)
    }
}

class RandomDouble
{
    static [System.Random]$rand = (New-Object System.Random)
    [Double]$min = 0.0
    [Double]$diff = 0.0

    RandomDouble($min, $max)
    {
        $this.min = $min
        $this.diff = $max - $min
    }

    [Double] Get()
    {
        return $this.min + [RandomDouble]::rand.NextDouble() * $this.diff
    }
}

class RandomInt
{
    [Int]$min = 0
    [Int]$max = 0

    RandomInt($min, $max)
    {
        $this.min = $min
        $this.max = $max + 1
    }

    [Int] Get()
    {
        return [RandomDouble]::rand.Next($this.min, $this.max)
    }
}

function Play($playerClass, $speed, $debugSkipRender = $false)
{
    ClearKeyHold ([ConsoleKey]::Q)
    $prevCursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    $framerate = 60.0
    $dt = 1.0 / $framerate
    $vsyncTimer = New-Object System.Diagnostics.StopWatch
    $dtTimer = New-Object System.Diagnostics.StopWatch

    $windowSize = $host.UI.RawUI.WindowSize
    $windowPosition = $host.UI.RawUI.WindowPosition
    $windowWidth = $windowSize.Width
    $windowHeight = $windowSize.Height

    $windowRect = New-Object System.Management.Automation.Host.Rectangle(
        $windowPosition.X,
        $windowPosition.Y,
        ($windowPosition.X + $windowWidth),
        ($windowPosition.Y + $windowHeight))

    $windowBuffer = $host.UI.RawUI.GetBufferContents($windowRect)

    $playerClass::Init($windowBuffer)

    $quit = $false
    while ($true)
    {
        ClearBuffer $windowBuffer

        $dtTimer.Stop()
        if ($dtTimer.Elapsed.TotalSeconds -ne 0)
        {
            $dt = $dtTimer.Elapsed.TotalSeconds
        }
        $dtTimer.Reset()
        $dtTimer.Start()

        $finished = $playerClass::Render($windowBuffer, $dt, $speed)
        if (GetKeyHold ([ConsoleKey]::Q))
        {
            $finished = $true
            $quit = $true
        }
        $vsyncTimer.Stop()

        if ($vsyncTimer.Elapsed.TotalMilliseconds -ne 0)
        {
            $sleepMilliseconds = [Math]::Max((1000.0/$framerate) - $vsyncTimer.Elapsed.TotalMilliseconds, 0)
            if ($sleepMilliseconds -gt 0)
            {
                Start-Sleep -Millisecond $sleepMilliseconds
            }
        }

        $vsyncTimer.Reset()
        $vsyncTimer.Start()
        if (-not $debugSkipRender)
        {
            $host.UI.RawUI.SetBufferContents($windowPosition, $windowBuffer)
        }

        if ($finished)
        {
            $vsyncTimer.Stop()
            $dtTimer.Stop()
            break
        }
    }

    $playerClass::Term()

    if (-not $quit)
    {
        Start-Sleep -Millisecond 500
    }

    Clear-Host
    $host.UI.RawUI.FlushInputBuffer()
    [Console]::CursorVisible = $prevCursorVisible
}

function CreateCharacters($characterClass, $windowBuffer)
{
    $characters = [System.Collections.Generic.List[PSObject]]::new()

    $width = $windowBuffer.GetUpperBound(1)
    $height = $windowBuffer.GetUpperBound(0)
    $bgColor = $host.UI.RawUI.BackgroundColor

    foreach ($x in @(0..($width-1)))
    {
        foreach ($y in @(0..($height-1)))
        {
            $cell = $windowBuffer[$y, $x]
            if ($cell.BufferCellType -eq [System.Management.Automation.Host.BufferCellType]::Trailing)
            {
                continue
            }

            if (($cell.Character -ne " ") -or
                ($cell.BackgroundColor -ne $bgColor))
            {
                $cellTrailing = $null
                if ($cell.BufferCellType -eq [System.Management.Automation.Host.BufferCellType]::Leading)
                {
                    $cellTrailing = $windowBuffer[$y, ($x+1)]
                }
                $character = $characterClass::new($cell, $cellTrailing, $x, $y)
                $characters.Add($character)
            }
        }
    }

    $characters
}

function ClearBuffer([System.Management.Automation.Host.BufferCell[,]]$buffer)
{
    $bgColor = $host.UI.RawUI.BackgroundColor
    [FancyClearHost.Native]::ClearBuffer($buffer, $bgColor, $bgColor)
}

function GetKeyHold([ConsoleKey]$consoleKey)
{
    $state = [FancyClearHost.Native]::GetAsyncKeyState([Int]$consoleKey)
    [Boolean]$state
}

function ClearKeyHold([ConsoleKey]$consoleKey)
{
    [FancyClearHost.Native]::GetAsyncKeyState([Int]$consoleKey) | Out-Null
}

function Limit($x, $min, $max)
{
    [Math]::Min([Math]::Max($x, $min), $max)
}

function Lerp($a, $b, $t)
{
    $a * (1.0 - $t) + $b * $t
}
