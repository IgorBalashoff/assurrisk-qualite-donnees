# AssurRisk — Brief 8

## Objectif
Contrôler la qualité des données, repérer les anomalies susceptibles d'affecter les analyses et proposer des mesures de minimisation des données personnelles (RGPD).

## Livrables
- `assurrisk_controles.sql` : requêtes de contrôle et d'analyse.
- `diagnostic_assurrisk.md` : version texte du diagnostic.
- `diagnostic_assurrisk.pdf` : version PDF destinée à la remise.

## Environnement
- PostgreSQL
- Schéma : `public`
- Exécution des requêtes : DBeaver ou un client PostgreSQL équivalent.

## Reproduction
1. Vérifier que la base et les tables du brief sont disponibles.
2. Exécuter les contrôles dans l'ordre.
3. Comparer les résultats avec les résultats consignés dans le diagnostic.
4. Documenter les écarts éventuels avant de modifier les données sources.

## Points de vigilance
Les doublons détectés sont des doublons potentiels selon les colonnes utilisées pour le regroupement. Les dates incohérentes et les contrats actuellement non actifs nécessitent une validation métier avant correction. Les noms, prénoms et emails ne doivent pas être exposés dans un reporting général lorsque ce n'est pas nécessaire.
