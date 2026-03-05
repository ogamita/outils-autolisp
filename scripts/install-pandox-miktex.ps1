# -*- mode:shell-script -*-
# install-pandoc-miktex.ps1
# Installe Pandoc + MiKTeX via winget, puis vérifie que pandoc/xelatex sont utilisables.
# Exécuter dans PowerShell (idéalement en Admin si winget le demande):
#   powershell -ExecutionPolicy Bypass -File .\install-pandoc-miktex.ps1

$ErrorActionPreference = "Stop"

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Commande introuvable: $name. Installe-la ou vérifie le PATH."
  }
}

Require-Command "winget"

Write-Host "==> Installation Pandoc..."
winget install -e --id JohnMacFarlane.Pandoc --accept-source-agreements --accept-package-agreements

Write-Host "==> Installation MiKTeX..."
winget install -e --id MiKTeX.MiKTeX --accept-source-agreements --accept-package-agreements

# Rafraîchit le PATH de la session (winget peut installer sans recharger la session)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "==> Vérifications..."

Require-Command "pandoc"

# xelatex peut ne pas être immédiatement dans le PATH selon l’install MiKTeX.
# On tente "xelatex", sinon on essaye de retrouver le binaire via emplacements usuels MiKTeX.
$xelatex = (Get-Command "xelatex" -ErrorAction SilentlyContinue)?.Source
if (-not $xelatex) {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64\xelatex.exe",
    "$env:ProgramFiles\MiKTeX\miktex\bin\x64\xelatex.exe",
    "$env:ProgramFiles(x86)\MiKTeX\miktex\bin\x64\xelatex.exe"
  ) | Where-Object { Test-Path $_ }

  if ($candidates.Count -gt 0) {
    $xelatex = $candidates[0]
    Write-Host "==> xelatex trouvé ici: $xelatex"
    # Ajoute au PATH utilisateur pour les prochaines sessions
    $binDir = Split-Path $xelatex -Parent
    $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
    if ($userPath -notlike "*$binDir*") {
      [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
      Write-Host "==> Ajouté au PATH (User): $binDir"
    }
    # Met à jour aussi la session courante
    $env:Path = $env:Path + ";" + $binDir
  }
}

# Dernier check
if (-not (Get-Command "xelatex" -ErrorAction SilentlyContinue)) {
  Write-Warning "xelatex n'est pas encore dans le PATH. Redémarre le terminal, ou vérifie MiKTeX."
  Write-Warning "Astuce: MiKTeX peut installer des packages à la volée au premier 'pandoc --pdf-engine=xelatex'."
} else {
  Write-Host "==> xelatex OK: " (Get-Command xelatex).Source
}

Write-Host "==> Versions:"
pandoc --version | Select-Object -First 2
xelatex --version | Select-Object -First 1

Write-Host "==> Terminé."
