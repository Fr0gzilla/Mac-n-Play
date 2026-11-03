# Icône macOS 26 déjà compilée

`Assets.car` est l'icône `gui/AppIcon.icon` compilée par l'outil `actool` de Xcode 26.
La fabrication GitHub essaie de la recompiler à chaque fois ; si l'outil plante (ça arrive sur
certaines machines GitHub), elle prend ce fichier.

**Après une modification de `gui/AppIcon.icon`**, remplacez ce fichier par celui d'une fabrication
réussie (dans l'appli : `Contents/Resources/Assets.car`), ou recompilez-le sur un Mac avec Xcode 26 :

```sh
xcrun actool gui/AppIcon.icon --compile gui/AppIcon-compiled --app-icon AppIcon \
  --enable-on-demand-resources NO --platform macosx --target-device mac \
  --minimum-deployment-target 15.0 --output-partial-info-plist /dev/null
```
