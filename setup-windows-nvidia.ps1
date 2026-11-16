[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $PSScriptRoot 'ComfyUI_windows_portable'),
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$release = '0.45.0'
$markerName = '.minimax-h3-preview-install'
$markerValue = "MiniMax H3 Hybrid Preview / ComfyUI $release"
$archive = @{
    Name = 'ComfyUI_windows_portable_nvidia.7z'
    Bytes = 2071479423L
    Sha256 = '60c12e8c7af778047ad0413722dd3dc0f6ca773a41cbf5cb229ee9bc92c44a6f'
    Sources = @("https://github.com/Comfy-Org/ComfyUI/releases/download/v$release/ComfyUI_windows_portable_nvidia.7z")
}

$hybrid = 'minimax_h3_hybrid_fl2va_ref2va_b25-49-int8.safetensors'
$encoder = 'qwen3vl_32b_minimax_h3_ultra_uncensored_heretic_int8_convrot.safetensors'
$vaeVideo = 'minimax_h3_video_vae_int8_convrot.safetensors'
$vaeAudio = 'minimax_h3_audio_vae_fp32.safetensors'
$hfVae = 'https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/4b53a35191437de05370da548e59aeabe2a5a09a/vae'
$msVae = 'https://modelscope.cn/models/Comfy-Org/MiniMax-H3/resolve/master/vae'
$models = @(
    @{
        Name = $hybrid
        Directory = 'diffusion_models'
        Bytes = 20970379632L
        Sha256 = 'a629cfea8d89a071b140c6e1935dc9a23e72de6badc18975a2bb9e6d1423d76d'
        Sources = @(
            "https://ai.gitcode.com/hf_mirrors/smhfacct/Minimax-H3-fl2va-ref2va-hybrid-models/resolve/main/$hybrid"
            "https://huggingface.co/smhfacct/Minimax-H3-fl2va-ref2va-hybrid-models/resolve/a36feb17fbd1f20ff4bdd509ccd07e2b7b585a38/$hybrid"
        )
    }
    @{
        Name = $encoder
        Directory = 'text_encoders'
        Bytes = 26363476151L
        Sha256 = 'd84547412144b7c50a6ec77437a889b869d3ace88da77ef1775d3d2a4901c192'
        Sources = @(
            "https://ai.gitcode.com/hf_mirrors/ethanfel/Qwen3-VL-32B-Ultra-Heretic-MiniMax-H3-ComfyUI-INT8-ConvRot/resolve/main/$encoder"
            "https://huggingface.co/OTMFLY/Qwen3-VL-32B-Ultra-Heretic-MiniMax-H3-ComfyUI-INT8-ConvRot/resolve/a7fc7d013153adb0fa77af64f6e859986fce4ac8/$encoder"
        )
    }
    @{
        Name = $vaeVideo
        Directory = 'vae'
        Bytes = 2811065184L
        Sha256 = '52a2c8c73583c86e4f41cdcce3a6ad0ea562987bc0bf3d60a0cef5f5c8e60c0e'
        Sources = @("$msVae/$vaeVideo", "$hfVae/$vaeVideo")
    }
    @{
        Name = $vaeAudio
        Directory = 'vae'
        Bytes = 605254808L
        Sha256 = '8e505d95dd1561d47abd43d4238fd40d9bb1ae9e147ed0a4cba778d76ae4db48'
        Sources = @("$msVae/$vaeAudio", "$hfVae/$vaeAudio")
    }
)

function Get-Length([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return (Get-Item -LiteralPath $Path).Length
    }
    return 0L
}

function Test-Asset([string]$Path, [hashtable]$Asset) {
    if ((Get-Length $Path) -ne $Asset.Bytes) { return $false }
    Write-Host "Checking SHA-256: $($Asset.Name)"
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $Asset.Sha256
}

function Get-Asset([hashtable]$Asset, [string]$Destination) {
    if (Test-Path -LiteralPath $Destination) {
        if (!(Test-Asset $Destination $Asset)) { throw "Existing file failed verification: $Destination" }
        return
    }

    $partial = "$Destination.part"
    if (Test-Asset $partial $Asset) {
        Move-Item -LiteralPath $partial -Destination $Destination
        return
    }
    if ((Get-Length $partial) -ge $Asset.Bytes) { Remove-Item -LiteralPath $partial }

    foreach ($source in $Asset.Sources) {
        foreach ($attempt in 1..2) {
            $resuming = (Get-Length $partial) -gt 0
            $curlArgs = @('--fail', '--location', '--retry', '2', '--connect-timeout', '20',
                '--speed-limit', '1024', '--speed-time', '60', '--max-filesize', [string]$Asset.Bytes,
                '--output', $partial, $source)
            if ($resuming) { $curlArgs = @('--continue-at', '-') + $curlArgs }
            Write-Host "Downloading $($Asset.Name) from $(([uri]$source).Host)"
            & curl.exe @curlArgs
            $curlExit = $LASTEXITCODE

            $length = Get-Length $partial
            if ($length -eq $Asset.Bytes -and (Test-Asset $partial $Asset)) {
                Move-Item -LiteralPath $partial -Destination $Destination
                return
            }
            if ($length -ge $Asset.Bytes -or ($resuming -and $curlExit -eq 33)) {
                Remove-Item -LiteralPath $partial
                if ($resuming -and $attempt -eq 1) { continue }
            }
            Write-Warning "Download did not verify ($length of $($Asset.Bytes) bytes, curl exit $curlExit)."
            break
        }
    }
    throw "No source completed $($Asset.Name). Rerun setup to resume the partial download."
}

function Assert-Runtime([string]$Root) {
    $python = Join-Path $Root 'python_embeded\python.exe'
    $version = Join-Path $Root 'ComfyUI\comfyui_version.py'
    if (!(Test-Path -LiteralPath $python -PathType Leaf) -or
        !(Test-Path -LiteralPath (Join-Path $Root 'ComfyUI\main.py') -PathType Leaf) -or
        !(Test-Path -LiteralPath $version -PathType Leaf)) { throw "Portable runtime is incomplete: $Root" }
    $versionPattern = '(?m)^__version__\s*=\s*"' + [regex]::Escape($release) + '"\s*$'
    if ((Get-Content -LiteralPath $version -Raw) -notmatch $versionPattern) {
        throw "Expected ComfyUI $release at $Root"
    }
    $torchVersion = & $python -B -I -c "from importlib.metadata import version; print(version('torch'))"
    if ($LASTEXITCODE -ne 0 -or $torchVersion -notmatch '\+cu130$') {
        throw "Expected the embedded NVIDIA CUDA 13.0 PyTorch at $Root"
    }
    Write-Host "ComfyUI $release / PyTorch $torchVersion"
}

function Get-ModelPath([hashtable]$Model) {
    return Join-Path (Join-Path $root "ComfyUI\models\$($Model.Directory)") $Model.Name
}

try {
    $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallDir).TrimEnd('\', '/')
    if ($root -notmatch '^[A-Za-z]:\\[^\\]') { throw 'Choose an installation folder on a local Windows drive.' }
    $cache = "$root.h3-setup"
    $marker = Join-Path $root $markerName
    Write-Host "ComfyUI folder: $root"

    if ($VerifyOnly) {
        Assert-Runtime $root
        $failed = @($models | Where-Object { !(Test-Asset (Get-ModelPath $_) $_) })
        if ($failed.Count -gt 0) { throw "Missing or incorrect models: $($failed.Name -join ', ')" }
        Write-Host 'Verified the portable runtime and all four model files.'
        exit 0
    }

    if (Test-Path -LiteralPath $root) {
        if (!(Test-Path -LiteralPath $marker -PathType Leaf) -or
            (Get-Content -LiteralPath $marker -Raw).Trim() -ne $markerValue) {
            throw 'InstallDir already exists and was not created by this setup. Choose a new folder. For an existing installation, use -VerifyOnly.'
        }
    }

    $workflow = Join-Path $PSScriptRoot 'minimax-h3-hybrid-r2v.json'
    $sample = Join-Path $PSScriptRoot 'h3-hybrid-reference.png'
    foreach ($file in @($workflow, $sample)) {
        if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing package file: $file" }
    }
    $null = Get-Command curl.exe -ErrorAction Stop
    $newRuntime = !(Test-Path -LiteralPath $root)
    if ($newRuntime) { $null = Get-Command tar.exe -ErrorAction Stop }

    $archivePath = Join-Path $cache $archive.Name
    $bytesNeeded = 1GB
    if ($newRuntime) {
        $bytesNeeded += 10GB + $archive.Bytes - [Math]::Min($archive.Bytes,
            [Math]::Max((Get-Length $archivePath), (Get-Length "$archivePath.part")))
    }
    foreach ($model in $models) {
        $path = Get-ModelPath $model
        $bytesNeeded += $model.Bytes - [Math]::Min($model.Bytes,
            [Math]::Max((Get-Length $path), (Get-Length "$path.part")))
    }
    $free = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($root)).AvailableFreeSpace
    Write-Host ('Available space: {0:N1} GiB. Estimated additional space: {1:N1} GiB.' -f ($free / 1GB), ($bytesNeeded / 1GB))
    if ($free -lt $bytesNeeded) { throw 'Free up space on the target drive or choose another -InstallDir.' }

    [IO.Directory]::CreateDirectory($cache) | Out-Null
    $lock = [IO.File]::Open((Join-Path $cache 'setup.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        if (!(Test-Path -LiteralPath $root)) {
            Get-Asset $archive $archivePath
            $staging = Join-Path $cache ('extract-' + [guid]::NewGuid())
            [IO.Directory]::CreateDirectory($staging) | Out-Null
            try {
                Write-Host 'Extracting the official ComfyUI archive.'
                & tar.exe -xf $archivePath -C $staging
                if ($LASTEXITCODE -ne 0) { throw 'Could not extract the verified 7z archive.' }
                $layout = Join-Path $staging 'ComfyUI_windows_portable'
                Assert-Runtime $layout
                Set-Content -LiteralPath (Join-Path $layout $markerName) -Value $markerValue -Encoding Ascii
                [IO.Directory]::Move($layout, $root)
            } finally {
                $resolvedStaging = (Resolve-Path -LiteralPath $staging).ProviderPath
                $resolvedCache = (Resolve-Path -LiteralPath $cache).ProviderPath
                if ([IO.Path]::GetDirectoryName($resolvedStaging) -eq $resolvedCache) {
                    Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
                }
            }
        } else {
            if (!(Test-Path -LiteralPath $marker -PathType Leaf) -or
                (Get-Content -LiteralPath $marker -Raw).Trim() -ne $markerValue) {
                throw "Installation folder appeared during setup: $root"
            }
            Assert-Runtime $root
        }

        foreach ($model in $models) {
            $path = Get-ModelPath $model
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
            Get-Asset $model $path
        }

        $workflowDir = Join-Path $root 'ComfyUI\user\default\workflows'
        $inputDir = Join-Path $root 'ComfyUI\input'
        $copies = @(@{ Source = $workflow; Target = $workflowDir }, @{ Source = $sample; Target = $inputDir })
        foreach ($copy in $copies) {
            [IO.Directory]::CreateDirectory($copy.Target) | Out-Null
            $destination = Join-Path $copy.Target ([IO.Path]::GetFileName($copy.Source))
            if (!(Test-Path -LiteralPath $destination)) {
                Copy-Item -LiteralPath $copy.Source -Destination $destination
            }
        }

        $launcher = Join-Path $root 'run_minimax_h3_hybrid.bat'
        if (!(Test-Path -LiteralPath $launcher)) {
            Set-Content -LiteralPath $launcher -Encoding Ascii -Value @(
                '@echo off'
                'cd /d "%~dp0"'
                '".\python_embeded\python.exe" -s ComfyUI\main.py --windows-standalone-build --disable-pinned-memory'
                'pause'
            )
        }
        Write-Host "Installed. Run: $launcher"
    } finally {
        $lock.Dispose()
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
