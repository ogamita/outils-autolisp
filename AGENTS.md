# AGENTS.md

Consignes globales pour ce dépôt:

- L'encodage des fichiers texte est `UTF-8`.
- Les fins de ligne ne sont pas uniformes: elles dépendent de l'usage du fichier.
- Les scripts et fichiers exécutés sur macOS / Linux utilisent `LF`.
- Les sources AutoLISP, la documentation et les spécifications utilisent `CRLF` par défaut.
- Les textes français doivent être correctement accentués.
- Pour les textes français, utiliser un encodage qui préserve les accents; dans ce dépôt, la règle normale reste `UTF-8`.
- Pour les nouveaux fichiers documentaires, préférer `org-mode`.
- Les fichiers techniques peuvent rester dans leur format usuel, par exemple `README.md`, `AGENTS.md`, `.gitattributes` ou les fichiers de pilotage du dépôt.
- Ne pas convertir rétroactivement un fichier existant d'un format vers un autre uniquement pour appliquer cette convention. Par exemple, ne pas transformer un fichier `*.md` existant en `*.org`.

Règles pratiques:

- `LF` pour les scripts shell, Python, PowerShell, les `Makefile` et les autres fichiers exécutés directement par des outils Unix.
- `CRLF` pour les fichiers `*.lsp`, `*.lisp`, `*.org`, `*.scr` et, sauf exception technique explicite, pour les autres fichiers documentaires.
- Dans le code source, les identificateurs peuvent rester sans accent; en revanche, les commentaires et textes français doivent être accentués.
- Pour un nouveau fichier documentaire, choisir `org-mode` par défaut sauf raison technique explicite.
- Pour un fichier existant, on peut ajuster l'encodage et les fins de ligne pour respecter ces conventions, sans changer son format.
