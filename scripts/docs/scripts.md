# scripts

## Objectif
`outils/scripts` contient des scripts utilitaires pour la chaîne documentaire PDF sous Windows :
- installation de Pandoc + MiKTeX
- génération de PDF depuis Markdown avec Pandoc

## Emplacement
- Script d’installation : `outils/scripts/install-pandox-miktex.ps1`
- Makefile de build : `outils/scripts/Makefile.pandoc`

## 1) Installer la chaîne d’outils (Windows)
Exécuter dans PowerShell :
```powershell
powershell -ExecutionPolicy Bypass -File .\outils\scripts\install-pandox-miktex.ps1
```

Ce que fait le script :
- vérifie `winget`
- installe `JohnMacFarlane.Pandoc`
- installe `MiKTeX.MiKTeX`
- rafraîchit le `PATH`
- vérifie `pandoc` et `xelatex`

## 2) Générer un PDF depuis Markdown
Depuis un dossier contenant `doc.md` :
```bash
make -f outils/scripts/Makefile.pandoc pdf
```

Valeurs par défaut de `Makefile.pandoc` :
- source : `doc.md`
- sortie : `doc.pdf`
- moteur PDF : `xelatex`

Surcharger les variables :
```bash
make -f outils/scripts/Makefile.pandoc pdf SRC=guide.md PDF=guide.pdf
```

Nettoyer :
```bash
make -f outils/scripts/Makefile.pandoc clean PDF=guide.pdf
```

## Notes
- `Makefile.pandoc` est pensé pour `make` sous Windows (`del /Q` pour le nettoyage).
- Au premier build PDF, MiKTeX peut télécharger des packages LaTeX supplémentaires.
