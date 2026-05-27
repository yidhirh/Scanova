# Brief : Reconstruction Spatiale OCR (ML Kit)

> Étape 2.5 du flux bilan, à intercaler entre l'OCR brut et le parser. Ce document explique le problème, la stratégie de résolution, et l'API attendue côté `OcrService`.

## Contexte et problème

On a construit `BilanParser` qui marche parfaitement sur du texte structuré ligne par ligne (14/14 tests passent sur des chaînes synthétiques). Mais en testant sur de vrais bilans biologiques avec ML Kit, le parser ne détecte rien.

### Diagnostic

ML Kit lit les documents **par blocs visuels**, pas par lignes logiques. Sur un bilan en colonnes typique :

```
HEMATOLOGIE                  Résultats   Unités    Valeurs Usuelles
Globules rouges               4.40        10⁶/ml    4 - 5.5
Hémoglobine                   12.7        g/dL      12 - 16
Hématocrite                   38.7        %         36 - 54
```

ML Kit retourne quelque chose comme :

```
HEMATOLOGIE
Globules rouges
Hémoglobine
Hématocrite
4.40
12.7
38.7
10⁶/ml
g/dL
%
4 - 5.5
12 - 16
36 - 54
```

Toutes les colonnes sont **désynchronisées**. Le parser regex qui cherche `NOM .... VALEUR UNITÉ NORME` sur une même ligne ne trouve rien parce que cette ligne n'existe jamais dans la sortie de ML Kit.

### Confirmation visuelle

Screenshot de l'app au moment du diagnostic : seuls les noms d'analyses apparaissent dans le texte OCR (colonne de gauche du bilan), les valeurs/unités/normes sont quelque part plus bas, complètement décorrélées.

## Contrainte utilisateur

Les médecins ciblés ont **explicitement mentionné des problèmes de réseau et d'internet** dans le formulaire de cahier des charges. La solution doit donc rester **on-device, sans API cloud**.

On accepte en contrepartie une précision imparfaite (objectif réaliste : 60-75% de valeurs détectées correctement sur des bilans imprimés), avec le formulaire de correction comme étape normale du flux.

## Stratégie de résolution

ML Kit expose les **coordonnées (bounding boxes)** de chaque élément de texte détecté. Au lieu d'utiliser `recognizedText.text` (chaîne plate), on va utiliser `recognizedText.blocks → lines → elements` et reconstruire les lignes logiques nous-mêmes.

### Algorithme

1. **Récupérer tous les `TextLine`** de toutes les `TextBlock`, avec leur `boundingBox`.
2. **Regrouper par ligne logique** : deux `TextLine` appartiennent à la même ligne du document si leurs coordonnées Y se chevauchent (tolérance basée sur la hauteur moyenne des caractères).
3. **Trier chaque groupe par X** (gauche à droite).
4. **Concaténer** avec un séparateur d'espaces multiples (`"    "`) pour préserver l'idée de colonnes — c'est exactement ce que le parser actuel sait consommer.
5. **Joindre les lignes reconstruites** par `\n`.
6. Passer le résultat au parser existant — il ne change pas.

### Schéma

```
Image
  ↓
ML Kit (recognizedText.blocks)
  ↓
Extraction de toutes les TextLine avec leur boundingBox
  ↓
Clustering par coordonnée Y (lignes du document)
  ↓
Tri par X dans chaque cluster
  ↓
Concaténation avec "    " entre colonnes
  ↓
Texte reconstruit format "NOM    VALEUR    UNITÉ    NORME"
  ↓
BilanParser (inchangé)
```

## API attendue côté `OcrService`

Le `OcrService` actuel doit exposer une **nouvelle méthode** sans casser l'ancienne (qui reste utile pour les documents non-bilans) :

```dart
class OcrService {
  /// Méthode existante - on garde.
  Future<String> extractTextFromImage(File image);

  /// NOUVELLE méthode - reconstruit les lignes logiques avant de retourner le texte.
  /// Utilisée par le flux bilan biologique.
  Future<String> extractStructuredText(File image);
}
```

`extractStructuredText` applique l'algorithme ci-dessus et retourne une chaîne où chaque ligne du résultat correspond à une ligne logique du document scanné.

## Implémentation détaillée

### Étape 1 — Récupérer les lignes avec leurs coordonnées

```dart
Future<String> extractStructuredText(File image) async {
  final inputImage = InputImage.fromFile(image);
  final recognizedText = await _textRecognizer.processImage(inputImage);

  // Aplatir : toutes les TextLine de tous les TextBlock dans une seule liste.
  final allLines = <TextLine>[];
  for (final block in recognizedText.blocks) {
    allLines.addAll(block.lines);
  }

  if (allLines.isEmpty) return '';

  // ... clustering + tri + concaténation (étapes suivantes)
}
```

### Étape 2 — Clustering par coordonnée Y

Deux lignes ML Kit appartiennent à la même ligne logique du document si leurs rectangles se chevauchent verticalement. On utilise le centre Y de chaque rectangle et une tolérance basée sur la hauteur.

```dart
class _LineCluster {
  final double centerY;
  final double height;
  final List<TextLine> lines = [];

  _LineCluster(TextLine first)
      : centerY = first.boundingBox.center.dy,
        height = first.boundingBox.height {
    lines.add(first);
  }

  /// Une ligne appartient au cluster si son centre Y est dans la tolérance.
  bool accepts(TextLine line) {
    final tolerance = height * 0.5; // 50% de la hauteur de la première ligne
    return (line.boundingBox.center.dy - centerY).abs() < tolerance;
  }

  void add(TextLine line) => lines.add(line);
}

List<_LineCluster> _clusterByY(List<TextLine> lines) {
  // Trier par Y croissant pour clustering séquentiel
  final sorted = [...lines]
    ..sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));

  final clusters = <_LineCluster>[];
  for (final line in sorted) {
    if (clusters.isEmpty || !clusters.last.accepts(line)) {
      clusters.add(_LineCluster(line));
    } else {
      clusters.last.add(line);
    }
  }
  return clusters;
}
```

### Étape 3 — Tri par X et concaténation

```dart
String _clusterToLine(_LineCluster cluster) {
  // Trier par X croissant (gauche à droite)
  final sorted = [...cluster.lines]
    ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

  // 4 espaces entre éléments : le parser actuel matche déjà "\s{2,}" comme séparateur
  return sorted.map((l) => l.text).join('    ');
}
```

### Étape 4 — Assemblage final

```dart
Future<String> extractStructuredText(File image) async {
  final inputImage = InputImage.fromFile(image);
  final recognizedText = await _textRecognizer.processImage(inputImage);

  final allLines = <TextLine>[];
  for (final block in recognizedText.blocks) {
    allLines.addAll(block.lines);
  }

  if (allLines.isEmpty) return '';

  final clusters = _clusterByY(allLines);
  return clusters.map(_clusterToLine).join('\n');
}
```

## Points d'attention

### 1. Photos inclinées

Si la photo n'est pas droite, deux lignes peuvent avoir des Y différents même si elles sont logiquement sur la même ligne du document. La tolérance à 50% de la hauteur aide, mais sur des inclinations fortes (>5 degrés) ça casse.

**Mitigation v1** : on accepte. Si les résultats sont mauvais en testant, on ajoutera plus tard un redressement d'image (deskew) en pré-traitement.

### 2. Tableaux complexes (TSH par âge, PSA par âge)

Ces tableaux ont des cellules de tailles très variables. Le clustering Y peut mal les gérer.

**Mitigation v1** : on accepte. Le brief disait déjà qu'on ignore ces tableaux. Le parser principal extraira la valeur principale ; les tranches d'âge seront perdues mais c'est OK.

### 3. Lignes très proches

Sur certains bilans très denses, deux lignes consécutives peuvent avoir leurs rectangles qui se touchent presque. Le clustering peut les fusionner par erreur.

**Mitigation** : si tests montrent ce problème, réduire la tolérance de `0.5` à `0.3`.

### 4. Calibrage

Les seuils (tolérance Y, nombre d'espaces de séparation) devront sans doute être ajustés en testant sur tes vrais bilans. Garde-les en `const` en haut de fichier pour qu'ils soient faciles à modifier.

```dart
class OcrService {
  static const double _yClusteringTolerance = 0.5; // % de la hauteur de ligne
  static const String _columnSeparator = '    ';   // 4 espaces
  // ...
}
```

## Intégration dans le flux bilan

L'écran `AddDocumentScreen` (ou un nouveau `BilanScanScreen` si tu préfères séparer) doit :

1. Quand l'utilisateur choisit le type "Bilan biologique"
2. Prendre la photo (caméra ou galerie)
3. Appeler `ocrService.extractStructuredText(image)` (pas `extractTextFromImage`)
4. Passer le résultat au `BilanParser.parse(texteReconstruit, patientId)`
5. Ouvrir le `BilanFormScreen` avec le bilan préremrempli pour vérification/correction

## Tests à ajouter

Dans `test/ocr_service_test.dart` (à créer), tester l'algorithme de clustering avec des `TextLine` simulés (mock de `boundingBox`) :

- Cas 1 : 4 lignes à Y identique → 1 cluster → 1 ligne reconstruite avec 4 colonnes
- Cas 2 : 4 lignes à Y très différents → 4 clusters → 4 lignes
- Cas 3 : Mix réaliste (3 lignes du document, chacune avec 4 colonnes) → 3 clusters

## Ordre d'implémentation suggéré

1. **Refactor `OcrService`** pour ajouter `extractStructuredText`, sans toucher à `extractTextFromImage`.
2. **Tests unitaires** du clustering avec `TextLine` mockés.
3. **Brancher dans le flux bilan** (modifier `AddDocumentScreen` ou créer `BilanScanScreen`).
4. **Tester sur de vrais bilans** des 3 labos (Boudjebla, AdomLAB, Kacher).
5. **Itérer** sur les seuils si nécessaire en regardant ce qui est extrait.

## Résultat attendu

Avant ce brief : **~10% des valeurs détectées** sur des bilans réels (à peu près rien, car le parser reçoit du texte désordonné).

Après ce brief : **60-75% des valeurs détectées** sur des bilans imprimés bien photographiés. Le reste sera complété manuellement dans `BilanFormScreen` — c'est attendu et acceptable.

Si après tests sur de vrais bilans on est en dessous de 50%, c'est qu'il y a un problème à diagnostiquer (mauvais seuils, photos trop inclinées, format de bilan non couvert). À ce moment-là on ajustera.

## Ce qu'on ne fait PAS dans cette étape

- Pré-traitement d'image (deskew, contraste, binarisation) → étape ultérieure si nécessaire.
- Reconnaissance des tableaux complexes (tranches d'âge) → reste hors scope.
- Changement de moteur OCR → on reste sur ML Kit.
- Fallback vers API cloud → décision utilisateur, on reste 100% on-device.

---

## Prompt suggéré pour Claude Code

> Lis `OCR_LAYOUT_RECONSTRUCTION.md` à la racine. C'est l'étape 2.5 du flux bilan qu'on aurait dû faire avant le parser. Le problème : le parser actuel marche sur du texte structuré mais ML Kit retourne du texte désordonné sur les bilans en colonnes. La solution : utiliser les bounding boxes de ML Kit pour reconstruire les lignes logiques avant de passer au parser.
>
> Implémente cette étape uniquement. N'ajoute pas de pré-traitement d'image, ne change pas de moteur OCR, ne touche pas au parser actuel.
>
> Comme d'habitude : avant de coder, montre-moi les fichiers que tu vas créer/modifier, et attends ma validation.
