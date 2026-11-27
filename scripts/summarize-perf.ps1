# Summarize the frame-meter intervals from a saved VIctory run log.
param(
    [Parameter(Mandatory, Position = 0)][string]$Log,
    [ValidateRange(0, 2147483647)][int]$Skip = 0,
    [ValidateRange(1, 2147483647)][int]$Take = [int]::MaxValue
)

$number = '[0-9]+(?:\.[0-9]+)?'
$ansi = [regex] ([string][char]27 + '\[[0-?]*[ -/]*[@-~]')
# Accept tracing output as well as frame-meter messages copied without the prefix.
$prefix = '^\s*(?:(?:\S+\s+)?INFO\s+victory_gpu::host:\s+)?'
$pattern = [regex] ($prefix +
    "(?<fps>$number) fps, (?<frame>$number) ms/frame \((?<prep>$number) preparing: [^;]*; " +
    "(?<wait>$number) on the GPU; [^)]*\), $number draws/frame, " +
    "dropped (?<dropped>$number) without a host pipeline \((?<making>[0-9]+) being made\)")

$samples = @(
    Get-Content -LiteralPath $Log -Encoding UTF8 -ErrorAction Stop | ForEach-Object {
        $sample = $pattern.Match($ansi.Replace($_, ''))
        if ($sample.Success) { $sample }
    } | Select-Object -Skip $Skip -First $Take
)
if ($samples.Count -eq 0) {
    throw 'No frame-meter intervals selected. Check that the log contains VIctory frame-meter lines and that -Skip is in range.'
}

$culture = [Globalization.CultureInfo]::InvariantCulture
$metrics = [ordered]@{
    fps = 'FPS'
    frame = 'Frame time (ms)'
    prep = 'Submission prep (ms/frame)'
    wait = 'GPU wait (ms/frame)'
    dropped = 'Dropped draws (per frame)'
    making = 'Pipelines being made'
}
$first = $Skip + 1
$last = $Skip + $samples.Count
"Frame-meter intervals $first-$last ($($samples.Count) selected). Each interval has equal weight."
''
'| Metric | Mean | Min | Max |'
'| --- | ---: | ---: | ---: |'
foreach ($key in $metrics.Keys) {
    $stats = $samples | ForEach-Object {
        [double]::Parse($_.Groups[$key].Value, $culture)
    } | Measure-Object -Average -Minimum -Maximum
    [string]::Format($culture, '| {0} | {1:F2} | {2:F2} | {3:F2} |',
        $metrics[$key], $stats.Average, $stats.Minimum, $stats.Maximum)
}
