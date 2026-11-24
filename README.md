# Catalogue de modules Vigie

Catalogue de la boutique de [Vigie](https://github.com/SertinoxVS) : l'onglet **Modules** lit
`catalogue.json`, montre les permissions de chaque module avant de l'installer, puis télécharge les
fichiers de `modules/<id>/<version>/` en vérifiant leur taille et leur empreinte SHA-256.

## Publier un module

Ne pas modifier `catalogue.json` à la main. Depuis un clone de ce dépôt :

```powershell
vigie --publier chemin\vers\mon-module chemin\vers\vigie-modules
git add . ; git commit -m "Mon module 1.0.0" ; git push
```

Une version publiée n'est jamais remplacée : pour une mise à jour, augmente `version` dans
`module.toml`. Format des modules et API : `docs/modules.md` dans le dépôt de Vigie.
