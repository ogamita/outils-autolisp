# outils-autolisp

Collection d'outils et bibliothèques AutoLISP pour l'exécution, les macros, les tests, le formatage et quelques utilitaires de documentation.

## Sous-projets

### `autolisp-script`
Wrapper CLI pour exécuter du code AutoLISP dans BricsCAD ou AutoCAD, capturer `stdout` / `stderr`, gérer un code de retour shell et piloter des tests automatisés.

Statut: actif, utilisable, avec automatisation de tests en place mais comportement macOS/BricsCAD encore à stabiliser.

Documentation: [autolisp-script/doc/autolisp-script.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-script/doc/autolisp-script.md)

### `autolisp-test`
Petit framework de tests AutoLISP avec suites, assertions et exécution agrégée via `run-suite` et `run-all`.

Statut: fonctionnel et déjà intégré à d'autres scripts du dépôt.

Documentation: [autolisp-test/doc/autolisp-test.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-test/doc/autolisp-test.md)

### `autolisp-macro`
Runtime de macros pour AutoLISP: `defmacro`, expansion de macros, chargement compatible macros et support de `quasiquote`.

Statut: avancé et vraisemblablement exploitable, avec documentation et exemples présents.

Documentation: [autolisp-macro/doc/autolisp-macro.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-macro/doc/autolisp-macro.md)

### `autolisp-formatter`
Projet de formateur / pretty-printer AutoLISP, avec spécifications et plan de travail. Le dépôt contient surtout la documentation de conception à ce stade.

Statut: phase de conception / spécification, pas encore implémenté dans ce dépôt.

Documentation: [autolisp-formatter/docs/specifications.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-formatter/docs/specifications.org)

### `autolisp-defstruct`
Prototype autour d'une implémentation `defstruct` pour AutoLISP. Le contenu actuel ressemble à des notes de conception et d'expérimentation plus qu'à une bibliothèque stabilisée.

Statut: prototype exploratoire.

Fichier principal: [autolisp-defstruct/defstruct.lsp](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-defstruct/defstruct.lsp)

### `scripts`
Scripts utilitaires orientés documentation PDF sous Windows, notamment pour installer Pandoc + MiKTeX et lancer une génération PDF via `make`.

Statut: utilitaires ciblés, probablement utilisables tels quels pour leur périmètre restreint.

Documentation: [scripts/doc/scripts.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/scripts/doc/scripts.md)

## Build et tests

Depuis la racine:

```bash
make test
```

Cette cible délègue actuellement à `autolisp-script`.

## Auteurs 

Pascal Bourguignon <ext.pascal.bourguignon@reseau.sncf.fr>
aka. Pascal Bourguignon <informatimago@gmail.com>
avec l'aide de ChatGPT/Codex (5.2, 5.3, 5.4).


## TODO Integrate with your tools

* [Set up project integrations](https://fabrik.sncf.fr/gitlab/dmoe-pop/epure/es/outils-autolisp/-/settings/integrations)

## TODO Collaborate with your team

* [Invite team members and collaborators](https://docs.gitlab.com/ee/user/project/members/)
* [Create a new merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
* [Automatically close issues from merge requests](https://docs.gitlab.com/ee/user/project/issues/managing_issues.html#closing-issues-automatically)
* [Enable merge request approvals](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
* [Set auto-merge](https://docs.gitlab.com/user/project/merge_requests/auto_merge/)

## TODO Test and Deploy

Use the built-in continuous integration in GitLab.

* [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/)
* [Analyze your code for known vulnerabilities with Static Application Security Testing (SAST)](https://docs.gitlab.com/ee/user/application_security/sast/)
* [Deploy to Kubernetes, Amazon EC2, or Amazon ECS using Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/requirements.html)
* [Use pull-based deployments for improved Kubernetes management](https://docs.gitlab.com/ee/user/clusters/agent/)
* [Set up protected environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)


## TODO Installation

Within a particular ecosystem, there may be a common way of installing things, such as using Yarn, NuGet, or Homebrew. However, consider the possibility that whoever is reading your README is a novice and would like more guidance. Listing specific steps helps remove ambiguity and gets people to using your project as quickly as possible. If it only runs in a specific context like a particular programming language version or operating system or has dependencies that have to be installed manually, also add a Requirements subsection.

## TODO Usage (for now, see subproject documentation)

Use examples liberally, and show the expected output if you can. It's helpful to have inline the smallest example of usage that you can demonstrate, while providing links to more sophisticated examples if they are too long to reasonably include in the README.

## TODO Support
Tell people where they can go to for help. It can be any combination of an issue tracker, a chat room, an email address, etc.

## TODO Roadmap
If you have ideas for releases in the future, it is a good idea to list them in the README.

## TODO Contributing
State if you are open to contributions and what your requirements are for accepting them.

For people who want to make changes to your project, it's helpful to have some documentation on how to get started. Perhaps there is a script that they should run or some environment variables that they need to set. Make these steps explicit. These instructions could also be useful to your future self.

You can also document commands to lint the code or run tests. These steps help to ensure high code quality and reduce the likelihood that the changes inadvertently break something. Having instructions for running tests is especially helpful if it requires external setup, such as starting a Selenium server for testing in a browser.

Show your appreciation to those who have contributed to the project.

## TODO Project status
If you have run out of energy or time for your project, put a note at the top of the README saying that development has slowed down or stopped completely. Someone may choose to fork your project or volunteer to step in as a maintainer or owner, allowing your project to keep going. You can also make an explicit request for maintainers.
