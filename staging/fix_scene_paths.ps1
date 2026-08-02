param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$projectPath = [System.IO.Path]::GetFullPath($ProjectRoot)
$files = @(
    'Tscn\ui\inventory\active_item_slot.tscn',
    'scripts\world.gd',
    'scripts\search_view.gd',
    'scripts\save_system.gd',
    'scripts\merchant_shop.gd',
    'scripts\main_menu.gd',
    'scripts\card_detail_overlay.gd',
    'scripts\card_pile_overlay.gd',
    'scripts\item_slot.gd',
    'scripts\deck_overview.gd',
    'scripts\inventory_view.gd',
    'scripts\battle.gd',
    'scripts\base.gd'
)
$replacements = [ordered]@{
    'res://scenes/battle.tscn' = 'res://Tscn/Scene/battle.tscn'
    'res://scenes/base.tscn' = 'res://Tscn/Scene/base.tscn'
    'res://scenes/world.tscn' = 'res://Tscn/Scene/world.tscn'
    'res://scenes/ui/' = 'res://Tscn/ui/'
}
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

foreach ($relativePath in $files) {
    $filePath = Join-Path $projectPath $relativePath
    if (-not (Test-Path -LiteralPath $filePath)) {
        throw "Missing expected project file: $filePath"
    }
    $original = [System.IO.File]::ReadAllText($filePath)
    $updated = $original
    foreach ($entry in $replacements.GetEnumerator()) {
        $updated = $updated.Replace($entry.Key, $entry.Value)
    }
    if ($updated -ne $original) {
        [System.IO.File]::WriteAllText($filePath, $updated, $utf8NoBom)
        Write-Output $relativePath
    }
}
