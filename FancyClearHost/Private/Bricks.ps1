using module .\Common.psm1

class Bricks
{
    static $kBallSpeed = 60
    static $kBarSpeed = 70
    static $kBarVelocityInfluenceAccelTime = 0.6
    static $kExplosionDuration = 0.6
    static $kExplosionPropagationDelayTime = [RandomDouble]::new(0.2, 0.3)

    static $foregroundColor = $null
    static $backgroundColor = $null
    static $windowWidth = 0
    static $windowHeight = 0

    static $characters = $null
    static $cellToCharacter = $null
    static $ball = $null
    static $bar = $null
    static $explosionsToAdd = $null
    static $explosions = $null

    static [void] Init($windowBuffer)
    {
        [Bricks]::foregroundColor = (Get-Host).UI.RawUI.ForegroundColor
        [Bricks]::backgroundColor = (Get-Host).UI.RawUI.BackgroundColor

        [Bricks]::CreateCharacters($windowBuffer)
        [Bricks]::CreateBall()
        [Bricks]::CreateBar()
        [Bricks]::explosionsToAdd = New-Object System.Collections.ArrayList
        [Bricks]::explosions = New-Object System.Collections.ArrayList
    }

    static [void] Term()
    {
        [Bricks]::characters = $null
        [Bricks]::ball = $null
        [Bricks]::bar = $null
        [Bricks]::explosions = $null
        [Bricks]::explosionsToAdd = $null
    }

    static [Boolean] Render([System.Management.Automation.Host.BufferCell[,]]$windowBuffer, [Double]$dt, [Double]$speed)
    {
        if (GetKeyHold ([ConsoleKey]::LeftArrow))
        {
            [Bricks]::bar.MoveLeft()
        }
        elseif (GetKeyHold ([ConsoleKey]::RightArrow))
        {
            [Bricks]::bar.MoveRight()
        }

        [Bricks]::bar.Update($dt)
        [Bricks]::ball.Update($dt * $speed)

        foreach ($explosion in [Bricks]::explosions)
        {
            $explosion.Update($dt * $speed)
        }
        foreach ($explosion in [Bricks]::explosionsToAdd)
        {
            [Bricks]::explosions.Add($explosion) | Out-Null
        }
        [Bricks]::explosionsToAdd.Clear()

        $isAllFinished = $true
        foreach ($character in [Bricks]::characters)
        {
            if (-not $character.isFinished)
            {
                $isAllFinished = $false
                break
            }
        }
        foreach ($explosion in [Bricks]::explosions)
        {
            if (-not $explosion.isFinished)
            {
                $isAllFinished = $false
                break
            }
        }

        if ($isAllFinished)
        {
            return $true
        }

        foreach ($character in [Bricks]::characters)
        {
            $character.Render($windowBuffer)
        }
        [Bricks]::ball.Render($windowBuffer)
        [Bricks]::bar.Render($windowBuffer)
        foreach ($explosion in [Bricks]::explosions)
        {
            $explosion.Render($windowBuffer)
        }

        return $false
    }

    static [void] CreateCharacters($windowBuffer)
    {
        [Bricks]::windowWidth = $windowBuffer.GetUpperBound(1)
        [Bricks]::windowHeight = $windowBuffer.GetUpperBound(0)

        [Bricks]::characters = CreateCharacters ([BricksCharacter]) $windowBuffer

        [Bricks]::cellToCharacter = New-Object 'Object[,]' ([Bricks]::windowWidth, [Bricks]::windowHeight)
        foreach ($character in [Bricks]::characters)
        {
            [Bricks]::cellToCharacter[$character.x, $character.y] = $character
            if ($character.IsTwoCell())
            {
                [Bricks]::cellToCharacter[($character.x+1), $character.y] = $character
            }
        }
    }

    static [void] CreateBall()
    {
        $x = [Int]([Bricks]::windowWidth / 2)
        $y = [Bricks]::windowHeight - 3
        [Bricks]::ball = [BricksBall]::new($x, $y)
    }

    static [void] CreateBar()
    {
        $width = 20
        $x = [Int](([Bricks]::windowWidth - $width) / 2)
        $y = [Int]([Bricks]::windowHeight - 2)
        [Bricks]::bar = [BricksBar]::new($x, $y, $width)
    }

    static [void] CreateExplosion($character, $isBackgroundColorAnimation)
    {
        [Bricks]::explosionsToAdd.Add([Explosion]::new($character, $isBackgroundColorAnimation)) | Out-Null
    }

    static [Object] GetCharacter($x, $y)
    {
        if (($x -lt 0) -or ($x -ge ([Bricks]::windowWidth)))
        {
            return $null
        }

        if (($y -lt 0) -or ($y -ge ([Bricks]::windowHeight)))
        {
            return $null
        }

        $character = [Bricks]::cellToCharacter[$x, $y]
        if ($character -and $character.isFinished)
        {
            return $null
        }

        return $character
    }
}

class BricksCharacter : RenderItem
{
    BricksCharacter($cell, $cellTrailing, $x, $y)
        : base($cell, $cellTrailing, $x, $y)
    {
    }

    [void] Update($dt)
    {
    }
}

class BricksBall : RenderItem
{
    $velocity = @(0.0, 0.0)

    BricksBall($x, $y)
        : base((New-Object System.Management.Automation.Host.BufferCell(
            [char]0x2b24,
            [System.ConsoleColor]::Yellow,
            [Bricks]::backgroundColor,
            [System.Management.Automation.Host.BufferCellType]::Complete)),
            $null,
            $x, $y)
    {
        $this.SetVelocity(-1.0, -1.0)
    }

    [void] Update($dt)
    {
        # assume cell width and height ratio is 1:2
        $newX = $this.x + $this.velocity[0] * $dt
        $newY = $this.y + $this.velocity[1] * 0.5 * $dt

        $this.SetNewPos($newX, $newY)
    }

    [void] SetVelocity($x, $y)
    {
        $length = [Math]::Sqrt($x * $x + $y * $y);
        $this.velocity[0] = $x * [Bricks]::kBallSpeed / $length
        $this.velocity[1] = $y * [Bricks]::kBallSpeed / $length
    }

    [void] SetNewPos($newX, $newY)
    {
        $walls = @()
        $walls += $this.GetWalls($this.x, $newX, 0)
        $walls += $this.GetWalls($this.y, $newY, 1)
        $walls = $walls | Sort-Object -Property t

        $dx = $newX - $this.x
        $dy = $newY - $this.y
        $windowSize = [Bricks]::windowWidth, [Bricks]::windowHeight

        $iSearchCoord = [Int]$this.x, [Int]$this.y
        foreach ($wall in $walls)
        {
            $componentIndex = $wall.componentIndex
            $iSearchCoord[$componentIndex] = $wall.cellIndex

            $isHit = $false
            $barVelocityAndInfluence = $null
            if (($iSearchCoord[$componentIndex] -lt 0) -or ($iSearchCoord[$componentIndex] -ge $windowSize[$componentIndex]))
            {
                $isHit = $true
            }
            else
            {
                $character = [Bricks]::GetCharacter($iSearchCoord[0], $iSearchCoord[1])
                if ($character)
                {
                    $character.Finish()
                    [Bricks]::CreateExplosion($character, $true)
                    $isHit = $true
                }
                elseif ([Bricks]::bar.IsInside($iSearchCoord[0], $iSearchCoord[1]))
                {
                    $barVelocityAndInfluence = [Bricks]::bar.GetBallVelocityAndInfluence()
                    $isHit = $true
                }
            }

            if ($isHit)
            {
                $newVelocity = $this.velocity.Clone()
                $newVelocity[$componentIndex] = -$newVelocity[$componentIndex]
                if ($barVelocityAndInfluence)
                {
                    $barVelocityX = $barVelocityAndInfluence[0]
                    $barVelocityY = $barVelocityAndInfluence[1]
                    $barInfluence = $barVelocityAndInfluence[2]

                    $barVelocityY *= [Math]::Sign($newVelocity[1])

                    $newVelocity[0] = Lerp $newVelocity[0] $barVelocityX $barInfluence
                    $newVelocity[1] = Lerp $newVelocity[1] $barVelocityY $barInfluence
                }
                $this.SetVelocity($newVelocity[0], $newVelocity[1])

                $this.x = Limit ($this.x + $dx * $wall.t) 0 ([Bricks]::windowWidth-1)
                $this.y = Limit ($this.y + $dy * $wall.t) 0 ([Bricks]::windowHeight-1)
                return
            }
        }

        $this.x = $newX
        $this.y = $newY
    }

    [Object[]] GetWalls($currentCoord, $newCoord, $componentIndex)
    {
        $walls = @()
        $min = [Math]::Min($currentCoord, $newCoord)
        $max = [Math]::Max($currentCoord, $newCoord)
        $d = $newCoord - $currentCoord
        $sign = [Math]::Sign($d)

        $wallCoords = @(([Math]::Floor($min))..([Math]::Floor($max)))
        if ($wallCoords.Count -gt 1)
        {
            $wallCoords = $wallCoords[1..($wallCoords.Count-1)]
            foreach ($wallCoord in $wallCoords)
            {
                $t = ($wallCoord - $currentCoord) / $d
                $walls += @{componentIndex = $componentIndex; t = $t; cellIndex = ($wallCoord + $sign)}
            }
        }
        return $walls
    }
}

class BricksBar
{
    $x = 0
    $y = 0
    $width = 0
    $renderItems = $null
    $nextMoveDirection = 0
    $prevMoveDirection = 0
    $velocityInfluence = 0.0

    BricksBar($x, $y, $width)
    {
        $this.x = $x
        $this.y = $y
        $this.width = $width

        $color = [System.ConsoleColor]::Blue
        $firstCell = New-Object System.Management.Automation.Host.BufferCell(
            "(",
            $color,
            [Bricks]::backgroundColor,
            [System.Management.Automation.Host.BufferCellType]::Complete)

        $lastCell = New-Object System.Management.Automation.Host.BufferCell(
            ")",
            $color,
            [Bricks]::backgroundColor,
            [System.Management.Automation.Host.BufferCellType]::Complete)

        $middleCell = New-Object System.Management.Automation.Host.BufferCell(
            " ",
            [Bricks]::foregroundColor,
            $color,
            [System.Management.Automation.Host.BufferCellType]::Complete)

        $this.renderItems = New-Object System.Collections.ArrayList
        $this.renderItems.Add([RenderItem]::new($firstCell, $null, $x, $y)) | Out-Null
        for ($i = 1; $i -lt ($width-1); ++$i)
        {
            $this.renderItems.Add([RenderItem]::new($middleCell, $null, ($x + $i), $y)) | Out-Null
        }
        $this.renderItems.Add([RenderItem]::new($lastCell, $null, $x + ($width-1), $y)) | Out-Null
    }

    [void] Render($windowBuffer)
    {
        foreach ($item in $this.renderItems)
        {
            $item.Render($windowBuffer)
        }
    }

    [void] Update($dt)
    {
        if ($this.nextMoveDirection -eq 0)
        {
            $this.velocityInfluence = 0.0
        }
        elseif (($this.prevMoveDirection * $this.nextMoveDirection) -lt 0)
        {
            # Moved in opposite direction
            $this.velocityInfluence = 0.0
        }
        else
        {
            $this.velocityInfluence += $dt / [Bricks]::kBarVelocityInfluenceAccelTime
            $this.velocityInfluence = [Math]::Min($this.velocityInfluence, 1.0)
        }

        $this.x += $this.nextMoveDirection * [Bricks]::kBarSpeed * $dt
        $this.prevMoveDirection = $this.nextMoveDirection
        $this.nextMoveDirection = 0

        $maxX = [Bricks]::windowWidth - $this.width - 1
        if (($this.x -lt 0) -or ($this.x -gt $maxX))
        {
            $this.velocityInfluence = 0.0
        }
        $this.x = [Math]::Max($this.x, 0)
        $this.x = [Math]::Min($this.x, $maxX)

        for ($i = 0; $i -lt $this.width; ++$i)
        {
            $this.renderItems[$i].x = $this.x + $i
        }
    }

    [void] MoveLeft()
    {
        $this.nextMoveDirection = -1
    }

    [void] MoveRight()
    {
        $this.nextMoveDirection = 1
    }

    [Boolean] IsInside($x, $y)
    {
        if ($y -ne $this.y)
        {
            return $false
        }

        if ($x -lt $this.x)
        {
            return $false
        }

        if ($x -ge ($this.x + $this.width))
        {
            return $false
        }

        return $true
    }

    [Double[]] GetBallVelocityAndInfluence()
    {
        $velocityX = [Math]::Sign($this.prevMoveDirection) * [Bricks]::kBallSpeed
        $velocityY = 0.5 * [Bricks]::kBallSpeed
        return $velocityX, $velocityY, $this.velocityInfluence
    }
}


class Explosion : RenderItem
{
    $timer = 0.0
    $colorAnimation = $null
    $isBackgroundColorAnimation = $true
    $propagationDelayTime = 0.0

    static $kColors = @(
        [System.ConsoleColor]::Yellow,
        [System.ConsoleColor]::Yellow,
        [System.ConsoleColor]::Blue,
        [System.ConsoleColor]::DarkBlue
    )

    Explosion($character, $isBackgroundColorAnimation)
        : base(
            $character.cells[0],
            $character.cells[1],
            $character.x, $character.y)
    {
        $this.colorAnimation = [LinearAnimation]::new([Explosion]::kColors, [Bricks]::kExplosionDuration)
        $this.isBackgroundColorAnimation = $isBackgroundColorAnimation
        $this.propagationDelayTime = [Bricks]::kExplosionPropagationDelayTime.Get()
    }

    [void] Update($dt)
    {
        if ($this.isFinished)
        {
            return
        }

        $this.colorAnimation.Update($dt)
        $color = $this.colorAnimation.GetValue()
        if ($this.isBackgroundColorAnimation)
        {
            $this.SetCell($null, $null, $color)
        }
        else
        {
            $this.SetCell($null, $color, $null)
        }

        if ($this.colorAnimation.GetRatio() -gt $this.propagationDelayTime)
        {
            foreach ($offsetX in @(-1..1))
            {
                foreach ($offsetY in @(-1..1))
                {
                    $character = [Bricks]::GetCharacter($this.x + $offsetX, $this.y + $offsetY)
                    if ($character)
                    {
                        $character.Finish()
                        [Bricks]::CreateExplosion($character, $false)
                    }
                }
            }
        }

        if ($this.colorAnimation.IsFinished())
        {
            $this.Finish()
        }
    }
}
