# Check the frame-meter summary using a synthetic log, without running a title.
$ErrorActionPreference = 'Stop'
$esc = [char]27
$fixture = @"
2026-01-01T00:00:00.000000Z  INFO victory_gpu::host: starting frame meter
2026-01-01T00:00:01.000000Z  INFO victory_gpu::host: 10.0 fps, 100.0 ms/frame (12.0 preparing: copies 0.0 ms 0.0 MB, textures 0.0 ms 0.0 MB; 4.0 on the GPU; 0.0 copying back 0.0 MB), 4000 draws/frame, dropped 8 without a host pipeline (9 being made)
${esc}[2m2026-01-01T00:00:02.000000Z${esc}[0m ${esc}[32mINFO${esc}[0m ${esc}[2mvictory_gpu::host:${esc}[0m 20.0 fps, 50.0 ms/frame (8.5 preparing: copies 0.0 ms 0.0 MB, textures 0.0 ms 0.0 MB; 1.5 on the GPU; 0.0 copying back 0.0 MB), 4000 draws/frame, dropped 2 without a host pipeline (5 being made)
2026-01-01T00:00:02.500000Z  INFO victory_gpu::host: unrelated log message
25.0 fps, 40.0 ms/frame (5.5 preparing: copies 0.0 ms 0.0 MB, textures 0.0 ms 0.0 MB; 2.5 on the GPU; 0.0 copying back 0.0 MB), 4000 draws/frame, dropped 4 without a host pipeline (1 being made)
50.0 fps, 20.0 ms/frame (3.0 preparing: copies 0.0 ms 0.0 MB, textures 0.0 ms 0.0 MB; 0.5 on the GPU; 0.0 copying back 0.0 MB), 4000 draws/frame, dropped 0 without a host pipeline (0 being made)
"@

$log = New-TemporaryFile
try {
    [IO.File]::WriteAllText($log.FullName, $fixture)
    $summary = & (Join-Path $PSScriptRoot 'summarize-perf.ps1') -Log $log.FullName -Skip 1 -Take 2
    $expected = @(
        'Frame-meter intervals 2-3 (2 selected). Each interval has equal weight.'
        '| FPS | 22.50 | 20.00 | 25.00 |'
        '| Frame time (ms) | 45.00 | 40.00 | 50.00 |'
        '| Submission prep (ms/frame) | 7.00 | 5.50 | 8.50 |'
        '| GPU wait (ms/frame) | 2.00 | 1.50 | 2.50 |'
        '| Dropped draws (per frame) | 3.00 | 2.00 | 4.00 |'
        '| Pipelines being made | 3.00 | 1.00 | 5.00 |'
    )
    foreach ($line in $expected) {
        if ($summary -cnotcontains $line) {
            throw "Expected '$line' in summary.`n$($summary -join "`n")"
        }
    }
    'Frame-meter fixture passed.'
} finally {
    Remove-Item -LiteralPath $log.FullName
}
