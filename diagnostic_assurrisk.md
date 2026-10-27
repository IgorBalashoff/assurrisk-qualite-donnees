# Brief 8 — AssurRisk
## Diagnostic de la qualité des données, risques et RGPD

**Objectif :** évaluer la qualité et l’exploitabilité des données avant la mise en reporting.  
**Périmètre :** tables `dim_assure`, `dim_agence`, `dim_garantie`, `dim_contrat`, `contrat_garantie`, `fact_sinistre` et `fact_indemnisation`.  
**Source :** contrôles SQL et résultats consignés dans le fichier de travail fourni. Les résultats ci-dessous sont ceux rapportés dans ce fichier ; ils n’ont pas été réexécutés indépendamment lors de la rédaction du présent rapport.

## 1. Synthèse exécutive

La base contient notamment **25 040 assurés**, **32 000 contrats**, **12 490 sinistres** et **13 890 indemnisations**. Plusieurs contrôles de relations n’ont détecté aucun enregistrement orphelin dans les cas testés. Des points doivent toutefois être investigués avant de valider les indicateurs : dates de déclaration antérieures à la survenance, doublons potentiels de sinistres, données personnelles manquantes ou répétées, et normalisation des libellés.

## 2. Volumes des tables

| Table | Lignes |
|---|---:|
| `contrat_garantie` | 89 600 |
| `dim_agence` | 25 |
| `dim_assure` | 25 040 |
| `dim_contrat` | 32 000 |
| `dim_garantie` | 12 |
| `fact_indemnisation` | 13 890 |
| `fact_sinistre` | 12 490 |

Les volumes ont été relevés dans PostgreSQL. Leur conformité aux volumes attendus doit être confirmée par comparaison avec la documentation du brief, dont les valeurs de référence ne figurent pas dans les résultats fournis.

## 3. Principales anomalies et limites

| Contrôle | Résultat rapporté | Risque / interprétation |
|---|---|---|
| Période des sinistres | Survenance : 01/01/2024–28/10/2025 ; déclaration : 02/01/2024–24/11/2025 | Les dates sont concentrées sur 2024–2025 ; comparer avec la période attendue dans le brief. |
| Doublons potentiels | 100 groupes, 200 lignes concernées, 100 lignes excédentaires potentielles ; maximum 2 occurrences | Les groupes sont des doublons potentiels selon les colonnes comparées, pas des doublons confirmés. Vérifier les identifiants et les autres attributs avant toute suppression. |
| Cohérence des dates | 80 sinistres déclarés avant leur date de survenance ; écart maximal rapporté : 14 jours | Peut fausser les analyses de délai de déclaration. Vérifier les sources et les règles métier. |
| Contrats non actifs | 70 sinistres liés à des contrats résiliés et 30 à des contrats expirés, soit 100 | Anomalies potentielles uniquement : vérifier si le contrat était couvert à la date de survenance, plutôt que de se baser uniquement sur le statut actuel. |
| Localisation | 40 villes manquantes, 30 départements manquants, 60 régions manquantes, 60 coordonnées incomplètes | Peut limiter les analyses géographiques. Ces catégories peuvent se chevaucher. |
| Coordonnées invalides | 0 latitude hors plage, 0 longitude hors plage, 0 couple (0,0) | Aucun problème détecté selon ces trois règles ; cela ne prouve pas que chaque point correspond à une adresse réelle. |
| Données personnelles | 500 dates de naissance manquantes ; 757 emails manquants ; 24 185 emails distincts après normalisation ; 0 format suspect selon la règle SQL utilisée | Limite certaines analyses démographiques et de contact. Des emails répétés doivent être examinés sans conclure automatiquement à des doublons de personnes. |
| Relations testées | 8 clés étrangères déclarées ; 0 contrat sans agence, 0 sinistre sans contrat, 0 sinistre sans garantie, 0 indemnisation sans sinistre dans les contrôles rapportés | Résultats rassurants pour les relations testées, mais ils ne remplacent pas la vérification de toutes les règles métier. |

## 4. Indicateurs métier exploratoires

### Répartition annuelle
- 2024 : **6 490 sinistres**
- 2025 : **6 000 sinistres**
- Écart : **−490**, soit environ **−7,55 %**

La comparaison annuelle doit tenir compte du fait que 2025 n’est pas une année complète dans les données observées (date maximale de survenance : 28 octobre 2025). Il ne faut donc pas interpréter directement cette baisse comme une baisse réelle du risque.

### Types de sinistres après standardisation
| Type | Nombre | Montant moyen estimé |
|---|---:|---:|
| Dégât des eaux | 3 746 | 4 385,14 € |
| Vol | 2 196 | 7 452,78 € |
| Grêle | 1 608 | 3 333,38 € |
| Tempête | 1 546 | 11 355,55 € |
| Bris de glace | 1 466 | 13 223,03 € |
| Responsabilité civile | 900 | 2 600,03 € |
| Incendie | 628 | 26 732,65 € |
| Inondation | 400 | 18 111,01 € |

Les incendies présentent le montant moyen estimé le plus élevé parmi les catégories listées ; les dégâts des eaux sont les plus fréquents. Les règles de standardisation doivent être validées sur les valeurs brutes restantes avant publication des indicateurs.

### Répartition régionale et statuts
- Région la plus représentée dans le résultat : **Occitanie, 1 870 sinistres**.
- **60** sinistres sans région renseignée.
- Statuts : clôturé 4 850 ; en cours 2 460 ; expertisé 2 400 ; refusé 1 800 ; déclaré 980.
- Montant total des indemnisations rapporté : **57 602 664,10 €**.
- Montant moyen d’une indemnisation rapporté : **4 147,06 €**.

Ces indicateurs restent descriptifs. Pour comparer le risque entre régions ou formules de contrat, il faudra tenir compte des volumes de contrats, du portefeuille d’assurés, de la période d’exposition et des éventuelles valeurs manquantes.

## 5. RGPD et minimisation des données

La table `dim_assure` contient des données directement identifiantes (nom, prénom, email), ainsi que la date de naissance et des informations géographiques. L’identifiant `assure_id` permet de relier les informations d’une même personne et ne garantit donc pas à lui seul l’anonymat.

### Recommandations
1. Conserver `assure_id` uniquement lorsqu’il est nécessaire aux jointures ou au comptage.
2. Ne pas exposer les noms, prénoms et emails dans les tableaux de bord généraux.
3. Privilégier les indicateurs agrégés par territoire, type ou statut.
4. Normaliser les emails avec `LOWER(TRIM(email))` pour les contrôles, puis investiguer les répétitions.
5. Ne pas inventer de dates de naissance ni d’autres valeurs de remplacement.
6. Documenter les champs nécessaires au reporting et limiter les accès selon le besoin métier.
7. Vérifier les obligations et règles internes applicables avant toute diffusion de données personnelles.

## 6. Investigations prioritaires

1. **Dates de naissance manquantes (500)** : identifier l’origine et déterminer si ces données sont nécessaires aux indicateurs démographiques.
2. **Emails manquants (757)** : confirmer si l’email est requis pour les usages métier envisagés.
3. **Emails partagés ou répétés** : l’écart entre 24 283 emails renseignés et 24 185 emails distincts normalisés indique des répétitions à examiner. Cela ne prouve pas que des personnes sont dupliquées.
4. **80 incohérences de dates** : examiner les dossiers concernés et les règles de saisie avant correction.
5. **100 groupes de doublons potentiels de sinistres** : comparer les identifiants et les attributs non inclus dans la clé de regroupement.
6. **100 sinistres associés à des contrats actuellement non actifs** : vérifier les dates de couverture à la date de survenance.
7. **Localisations incomplètes** : rechercher les informations sources disponibles et conserver les valeurs inconnues si elles ne peuvent pas être confirmées.
8. **Nomenclature des types de sinistres** : vérifier les libellés non reconnus après standardisation et valider la nomenclature métier.

## 7. Traitements recommandés avant reporting

- Créer des vues de reporting qui ne contiennent que les colonnes nécessaires.
- Normaliser les libellés catégoriels à l’aide d’une règle documentée et validée.
- Contrôler les valeurs manquantes, les dates incohérentes et les doublons potentiels à chaque actualisation.
- Conserver une trace des contrôles, des résultats et des décisions.
- Ne pas supprimer ou modifier les données sources sans investigation et validation.
- Comparer les montants estimés et les indemnisations avec prudence : ils ne représentent pas nécessairement la même mesure ni la même période.
- Ajouter une date de mise à jour et la période couverte à chaque tableau de bord.

## 8. Conclusion

La base permet déjà plusieurs analyses descriptives et les contrôles de relations rapportés sont satisfaisants pour les cas testés. La mise en reporting doit cependant être conditionnée à l’investigation des dates incohérentes, des doublons potentiels, des contrats non actifs, des données manquantes et des emails répétés. La minimisation des données personnelles doit être appliquée dès la préparation des vues de reporting.

**Limite importante :** les résultats de ce rapport proviennent des commentaires consignés dans le fichier de travail. Ils doivent être vérifiés dans PostgreSQL avant validation définitive, en particulier les volumes de référence, les anomalies et les montants financiers.
