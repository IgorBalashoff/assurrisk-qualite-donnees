
-- Brief 8 "AssurRisk" -- 
------------------------------------------------

-- Vérification des volumes des tables
-- Question métier : Les volumes des tables correspondent-ils aux volumes attendus dans la documentation ?
SELECT 'dim_assure' AS table_name, COUNT(*) AS nb_lignes
FROM public.dim_assure
UNION ALL
SELECT 'dim_agence', COUNT(*) FROM public.dim_agence
UNION ALL
SELECT 'dim_garantie', COUNT(*) FROM public.dim_garantie
UNION ALL
SELECT 'dim_contrat', COUNT(*) FROM public.dim_contrat
UNION ALL
SELECT 'contrat_garantie', COUNT(*) FROM public.contrat_garantie
UNION ALL
SELECT 'fact_sinistre', COUNT(*) FROM public.fact_sinistre
UNION ALL
SELECT 'fact_indemnisation', COUNT(*) FROM public.fact_indemnisation
ORDER BY table_name;
-----------------------------------------------------------------------------

-- =====================================================
-- CONTROLE 2 : PERIODE DES SINISTRES
-- =====================================================

-- QUESTION METIER :
-- Les dates des sinistres correspondent-elles
-- a la periode annoncee dans le brief ?


SELECT
    MIN(date_survenance) AS date_surv_min,
    MAX(date_survenance) AS date_surv_max,
    MIN(date_declaration) AS date_decl_min,
    MAX(date_declaration) AS date_decl_max,
    COUNT(*) FILTER (
        WHERE EXTRACT(YEAR FROM date_survenance) = 2026
    ) AS sinistres_2026,
    COUNT(*) FILTER (
        WHERE EXTRACT(YEAR FROM date_declaration) = 2026
    ) AS declarations_2026
FROM public.fact_sinistre;
-- RESULTAT OBTENU :
-- Date minimale de survenance : 2024-01-01
-- Date maximale de survenance : 2025-10-28
-- Date minimale de declaration : 2024-01-02
-- Date maximale de declaration : 2025-11-24
-------------------------------------------------------------------------------

-- =====================================================
-- CONTROLE 3 : IDENTIFICATION DES CLÉS ÉTRANGÈRES
-- =====================================================

-- QUESTION METIER : Quelles relations entre les tables sont définies dans PostgreSQL ?

SELECT
    tc.table_name AS table_source,
    kcu.column_name AS colonne_source,
    ccu.table_name AS table_cible,
    ccu.column_name AS colonne_cible
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;
-- Résultat obtenu : 8 clés étrangères ont été identifiées.
--------------------------------------------------------------------------------

-- =====================================================
-- CONTROLE 4 : DOUBLONS POTENTIELS DES SINISTRES
-- =====================================================

-- QUESTION METIER :
-- Existe-t-il des lignes de sinistres potentiellement
-- dupliquees pouvant fausser les indicateurs ?

SELECT
    contrat_id,
    agence_id,
    garantie_id,
    date_survenance,
    date_declaration,
    type_sinistre,
    cause_sinistre,
    COUNT(*) AS nb_occurrences
FROM public.fact_sinistre
GROUP BY
    contrat_id,
    agence_id,
    garantie_id,
    date_survenance,
    date_declaration,
    type_sinistre,
    cause_sinistre
HAVING COUNT(*) > 1
ORDER BY nb_occurrences DESC;


-- CONTROLE 4B : QUANTIFICATION DES DOUBLONS POTENTIELS

-- QUESTION METIER :
-- Combien de groupes et de lignes sont concernes
-- par des doublons potentiels ?

WITH doublons AS (
    SELECT
        contrat_id,
        agence_id,
        garantie_id,
        date_survenance,
        date_declaration,
        type_sinistre,
        cause_sinistre,
        COUNT(*) AS nb_occurrences
    FROM public.fact_sinistre
    GROUP BY
        contrat_id,
        agence_id,
        garantie_id,
        date_survenance,
        date_declaration,
        type_sinistre,
        cause_sinistre
    HAVING COUNT(*) > 1
)

SELECT
    COUNT(*) AS nb_groupes_potentiels,
    SUM(nb_occurrences) AS nb_lignes_concernees,
    SUM(nb_occurrences - 1)
        AS nb_lignes_excedentaires_si_doublons_confirmes,
    MAX(nb_occurrences) AS max_occurrences
FROM doublons;


-- RESULTAT OBTENU :
-- Groupes potentiels : 100
-- Lignes concernees : 200
-- Lignes excedentaires potentielles : 100
-- Maximum d'occurrences par groupe : 2

-- INTERPRETATION :
-- 100 groupes de doublons potentiels ont ete detectes.
-- Chaque groupe contient exactement 2 lignes.
-- Si les doublons sont confirmes, 100 lignes seraient
-- excedentaires.
-- Aucune suppression ne doit etre effectuee avant
-- verification des identifiants et des autres colonnes.
------------------------------------------------------------------------------------

-- =====================================================
-- CONTROLE 5 : COHERENCE DES DATES
-- =====================================================

-- QUESTION METIER :
-- Existe-t-il des sinistres declares avant leur
-- date de survenance ?

SELECT
    sinistre_id,
    contrat_id,
    date_survenance,
    date_declaration,
    type_sinistre
FROM fact_sinistre
WHERE date_declaration < date_survenance
ORDER BY date_survenance;


-- RESULTAT OBTENU :
-- 80 lignes affichees dans le resultat transmis.
-- Les dates de declaration sont anterieures
-- aux dates de survenance.

-- INTERPRETATION :
-- Ces incoherences peuvent fausser l'analyse
-- des delais de declaration des sinistres.
-- Une investigation est necessaire avant correction.
-- Aucune modification de la table source.
-------------------------

-- Contrôle 5B — Quantification des incohérences de dates
-- Question métier : Combien de sinistres présentent une date de déclaration antérieure à la date de survenance ?

SELECT
    COUNT(*) AS nb_dates_incoherentes,
    MAX(date_survenance - date_declaration)
        AS retard_maximum_jours
FROM fact_sinistre
WHERE date_declaration < date_survenance;

-- RESULTAT OBTENU :
-- Nombre de dates incoherentes : 80
-- Ecart maximum entre les dates : 14 jours

-- INTERPRETATION :
-- 80 sinistres ont une date de declaration
-- anterieure a la date de survenance.
-- L'ecart maximal observe est de 14 jours.
-- Ces anomalies peuvent fausser l'analyse des delais
-- de declaration. Une investigation est necessaire
-- avant toute correction.

------------------------------------------------------------------------------------------

-- =====================================================
-- CONTROLE 6 : SINISTRES ET CONTRATS NON ACTIFS
-- =====================================================

-- QUESTION METIER :
-- Combien de sinistres sont associes a des contrats
-- dont le statut est different de 'actif' ?

SELECT
    c.statut_contrat,
    COUNT(*) AS nb_sinistres
FROM fact_sinistre AS s
JOIN public.dim_contrat AS c
    ON s.contrat_id = c.contrat_id
WHERE c.statut_contrat <> 'actif'
GROUP BY c.statut_contrat
ORDER BY nb_sinistres DESC;

-- RESULTAT OBTENU :
-- Contrats résiliés : 70 sinistres
-- Contrats expirés : 30 sinistres
-- Total : 100 sinistres associés à des contrats non actifs

-- INTERPRETATION :
-- 100 sinistres sont associés à des contrats
-- dont le statut actuel est différent de 'actif'.

-- CONCLUSION METIER :
-- Ces cas constituent des anomalies potentielles.
-- Une vérification des dates de couverture est nécessaire
-- avant de confirmer une anomalie réelle.

---------------------------------------------------------------------------------

-- =====================================================
-- CONTRÔLE 7 : LOCALISATIONS MANQUANTES OU INEXPLOITABLES
-- =====================================================

-- QUESTION METIER :
-- Combien de sinistres ont une localisation manquante
-- ou inexploitable ?

-- Quels sont les champs disponibles dans la table des sinistres ?

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'fact_sinistre'
ORDER BY ordinal_position;


-- Combien de sinistres ont une localisation manquante
-- ou inexploitable ?

SELECT
    COUNT(*) AS nb_total_sinistres,

    COUNT(*) FILTER (
        WHERE ville_sinistre IS NULL
           OR TRIM(ville_sinistre) = ''
    ) AS villes_manquantes,

    COUNT(*) FILTER (
        WHERE departement_sinistre IS NULL
           OR TRIM(departement_sinistre) = ''
    ) AS departements_manquants,

    COUNT(*) FILTER (
        WHERE region_sinistre IS NULL
           OR TRIM(region_sinistre) = ''
    ) AS regions_manquantes,

    COUNT(*) FILTER (
        WHERE latitude IS NULL
           OR longitude IS NULL
    ) AS coordonnees_incompletes

FROM fact_sinistre;


-- RESULTAT OBTENU :
-- Nombre total de sinistres : 12 490
-- Villes manquantes : 40
-- Departements manquants : 30
-- Regions manquantes : 60
-- Coordonnees incompletes : 60

-- INTERPRETATION :
-- 40 sinistres n'ont pas de ville renseignee.
-- 30 sinistres n'ont pas de departement renseigne.
-- 60 sinistres n'ont pas de region renseignee.
-- 60 sinistres ont au moins une coordonnee manquante.

-- IMPACT METIER :
-- Ces anomalies peuvent limiter l'analyse geographique
-- des sinistres et fausser les rapports regionaux.
-- Les indicateurs peuvent se chevaucher :
-- un meme sinistre peut presenter plusieurs anomalies.

-- DECISION PROPOSEE :
-- Verifier les donnees sources et completer les champs
-- manquants lorsque cela est possible.
-- Ne pas inventer les valeurs manquantes.
-- Documenter les anomalies qui ne peuvent pas etre corrigees.
----------------------------------------------------------------------------------------

-- =====================================================
-- CONTRÔLE 8 : COORDONNEES GEOGRAPHIQUES INVALIDES
-- =====================================================

-- QUESTION METIER :
-- Existe-t-il des coordonnées géographiques invalides
-- dans les données des sinistres ?

SELECT
    COUNT(*) FILTER (
        WHERE latitude IS NOT NULL
          AND (latitude < -90 OR latitude > 90)
    ) AS latitudes_invalides,

    COUNT(*) FILTER (
        WHERE longitude IS NOT NULL
          AND (longitude < -180 OR longitude > 180)
    ) AS longitudes_invalides,

    COUNT(*) FILTER (
        WHERE latitude IS NOT NULL
          AND longitude IS NOT NULL
          AND latitude = 0
          AND longitude = 0
    ) AS coordonnees_zero_zero

FROM fact_sinistre;


-- RESULTAT OBTENU :
-- Latitudes invalides : 0
-- Longitudes invalides : 0
-- Coordonnees (0, 0) : 0

-- INTERPRETATION :
-- Aucune latitude hors des limites autorisees
-- (-90 a 90 degres) n'a ete detectee.
-- Aucune longitude hors des limites autorisees
-- (-180 a 180 degres) n'a ete detectee.
-- Aucune coordonnee egale a (0, 0) n'a ete detectee.

-- IMPACT METIER :
-- Aucun probleme de coordonnees geographiques
-- invalides n'a ete detecte selon ces trois controles.
-- Cela ne garantit pas que toutes les coordonnees
-- correspondent a une localisation reelle correcte.

-- DECISION PROPOSEE :
-- Aucun nettoyage n'est necessaire pour ces trois
-- criteres sur la base des resultats obtenus.
-- Conserver ces controles dans le processus de qualite.
------------------------------------------------------------------------------------
-- =====================================================
-- CONTRÔLE 9.1 : CONTRATS ET ASSURES
-- =====================================================

-- QUESTION METIER :
-- Chaque contrat reference-t-il un assure existant ?

SELECT
    COUNT(*) AS nb_contrats_total,
    COUNT(*) FILTER (
        WHERE a.assure_id IS NULL
    ) AS nb_contrats_sans_assure
FROM dim_contrat AS c
LEFT JOIN public.dim_assure AS a
    ON c.assure_id = a.assure_id;
----------------------------------------

-- CONTROLE 9.2 : CONTRATS ET AGENCES
-- QUESTION METIER :
-- Chaque contrat reference-t-il une agence existante ?

SELECT
    COUNT(*) AS nb_contrats_total,
    COUNT(*) FILTER (
        WHERE a.agence_id IS NULL
    ) AS nb_contrats_sans_agence
FROM dim_contrat AS c
LEFT JOIN public.dim_agence AS a
    ON c.agence_id = a.agence_id;


-- RESULTAT OBTENU :
-- Nombre total de contrats : 32 000
-- Contrats sans agence existante : 0

-- INTERPRETATION :
-- Les 32 000 contrats sont associes a des agences
-- existantes dans la table dim_agence.
-- Aucune relation invalide n'a ete detectee.

-- IMPACT METIER :
-- Les analyses par agence peuvent s'appuyer
-- sur les relations entre contrats et agences.
-- Aucun contrat orphelin n'a ete identifie.

-- DECISION PROPOSEE :
-- Aucune correction necessaire pour ce controle.
-- Conserver cette verification dans le processus
-- de controle de la qualite des donnees.
---------------------------------------------------------

-- CONTROLE 9.3 : SINISTRES ET CONTRATS
-- QUESTION METIER :
-- Chaque sinistre reference-t-il un contrat existant ?

SELECT
    COUNT(*) AS nb_sinistres_total,
    COUNT(*) FILTER (
        WHERE c.contrat_id IS NULL
    ) AS nb_sinistres_sans_contrat
FROM fact_sinistre AS s
LEFT JOIN public.dim_contrat AS c
    ON s.contrat_id = c.contrat_id;

-- RESULTAT OBTENU :
-- Nombre total de sinistres : 12 490
-- Sinistres sans contrat existant : 0

-- INTERPRETATION :
-- Les 12 490 sinistres sont associes a des contrats
-- existants dans la table dim_contrat.
-- Aucun sinistre orphelin n'a ete detecte.

-- IMPACT METIER :
-- Les analyses reliant les sinistres aux contrats
-- peuvent s'appuyer sur cette relation.
-- Aucun sinistre sans contrat correspondant
-- n'a ete identifie.

-- DECISION PROPOSEE :
-- Aucune correction necessaire pour ce controle.
-- Conserver cette verification dans le processus
-- de controle de la qualite des donnees.
----------------------------------------------------------

-- CONTROLE 9.4 : SINISTRES ET GARANTIES
-- QUESTION METIER :
-- Chaque sinistre reference-t-il une garantie existante ?

SELECT
    COUNT(*) AS nb_sinistres_total,
    COUNT(*) FILTER (
        WHERE g.garantie_id IS NULL
    ) AS nb_sinistres_sans_garantie
FROM fact_sinistre AS s
LEFT JOIN public.dim_garantie AS g
    ON s.garantie_id = g.garantie_id;


-- RESULTAT OBTENU :
-- Nombre total de sinistres : 12 490
-- Sinistres sans garantie existante : 0

-- INTERPRETATION :
-- Les 12 490 sinistres sont associes a des garanties
-- existantes dans la table dim_garantie.
-- Aucune relation invalide n'a ete detectee.

-- IMPACT METIER :
-- Les analyses reliant les sinistres aux garanties
-- peuvent s'appuyer sur cette relation.
-- Aucun sinistre orphelin n'a ete identifie selon ce controle.

-- DECISION PROPOSEE :
-- Aucune correction necessaire pour ce controle.
-- Conserver cette verification dans le processus
-- de controle de la qualite des donnees.
---------------------------------------------------------------

-- CONTROLE 9.5 : INDEMNISATIONS ET SINISTRES
-- QUESTION METIER :
-- Chaque indemnisation reference-t-elle un sinistre existant ?

SELECT
    COUNT(*) AS nb_indemnisations_total,
    COUNT(*) FILTER (
        WHERE s.sinistre_id IS NULL
    ) AS nb_indemnisations_sans_sinistre
FROM fact_indemnisation AS i
LEFT JOIN public.fact_sinistre AS s
    ON i.sinistre_id = s.sinistre_id;


-- RESULTAT OBTENU :
-- Nombre total d'indemnisations : 13 890
-- Indemnisations sans sinistre existant : 0

-- INTERPRETATION :
-- Les 13 890 indemnisations referencees dans la table
-- fact_indemnisation sont associees a des sinistres
-- existants dans la table fact_sinistre.
-- Aucune relation invalide n'a ete detectee.

-- IMPACT METIER :
-- Les analyses reliant les indemnisations aux sinistres
-- peuvent s'appuyer sur cette relation.
-- Aucune indemnisation orpheline n'a ete identifiee
-- selon ce controle.

-- DECISION PROPOSEE :
-- Aucune correction necessaire pour ce controle.
-- Conserver cette verification dans le processus
-- de controle de la qualite des donnees.
-------------------------------------------------


-- CONTROLE 9.6 : IMPACT DES RELATIONS INVALIDES

-- QUESTION METIER :
-- Quel serait l'impact d'une relation invalide
-- sur une future analyse ?

-- INTERPRETATION :
-- Une relation invalide peut empecher de relier
-- correctement deux tables.
-- Elle peut entrainer la perte de lignes lors des JOIN,
-- fausser les indicateurs et produire des resultats
-- incomplets ou inexacts.

-- IMPACT METIER :
-- Les analyses du nombre de sinistres,
-- des indemnisations et des garanties peuvent etre
-- faussees si les relations entre les tables
-- ne sont pas fiables.

-- DECISION PROPOSEE :
-- Verifier les relations entre les tables avant
-- de produire les indicateurs.
-- Documenter les anomalies et corriger les relations
-- invalides apres investigation.
-- Conserver les controles dans le processus
-- de qualite des donnees.

-- CONCLUSION DU CONTROLE 9 :
-- Aucune relation invalide n'a ete detectee
-- dans les cinq controles effectues.
-- Les relations verifiees sont conformes aux controles.

-----------------------------------------------------------------------

-- =====================================================
-- CONTROLE 10.1 : NOMBRE DE SINISTRES PAR ANNEE
-- =====================================================

-- QUESTION METIER :
-- Combien de sinistres sont enregistres par annee ?

SELECT
    EXTRACT(YEAR FROM date_survenance) AS annee,
    COUNT(*) AS nb_sinistres
FROM fact_sinistre
GROUP BY EXTRACT(YEAR FROM date_survenance)
ORDER BY annee;


-- RESULTAT OBTENU :
-- 2024 : 6 490 sinistres
-- 2025 : 6 000 sinistres
-- Total : 12 490 sinistres

-- INTERPRETATION :
-- Le nombre de sinistres est passe de 6 490 en 2024
-- a 6 000 en 2025.
-- Cela represente une baisse de 490 sinistres,
-- soit environ 7,55 %.

-- IMPACT METIER :
-- Cette baisse peut indiquer une diminution
-- du nombre de sinistres declares.
-- Il est necessaire de verifier cette tendance
-- avant de tirer une conclusion definitive.

-- DECISION PROPOSEE :
-- Comparer les resultats avec les autres indicateurs,
-- notamment les types de sinistres et les regions.
-- Verifier egalement la completude des donnees
-- pour les deux annees.
-------------------------------

-- =====================================================
-- CONTROLE 10.2 : NOMBRE DE SINISTRES PAR TYPE
-- =====================================================

-- QUESTION METIER :
-- Combien de sinistres sont enregistres par type ?

SELECT
    type_sinistre,
    COUNT(*) AS nb_sinistres
FROM fact_sinistre
GROUP BY type_sinistre
ORDER BY nb_sinistres DESC

-- RESULTAT OBTENU :
-- Plusieurs types de sinistres sont presents
-- avec des frequences tres differentes.
-- Des variantes de casse et d'orthographe
-- sont egalement visibles dans les resultats.
-- Exemple : Tempete, tempête et TEMPÊTE.

-- INTERPRETATION :
-- Certaines valeurs peuvent correspondre
-- au meme type de sinistre, mais sont stockees
-- sous des formes differentes.
-- Le comptage actuel les traite comme des valeurs
-- distinctes.

-- IMPACT METIER :
-- Les indicateurs par type de sinistre peuvent
-- etre fragmentes et ne pas refleter les volumes
-- reels de chaque categorie.
-- Les comparaisons entre categories peuvent
-- donc etre faussees.

-- DECISION PROPOSEE :
-- Identifier toutes les variantes de libelle.
-- Definir une nomenclature de reference.
-- Standardiser les valeurs apres verification
-- des donnees sources.
-- Recalculer les indicateurs apres nettoyage.


-- ============================================
-- CONTROLE 10.2 BIS : STANDARDISATION DES TYPES
-- ============================================

-- QUESTION METIER :
-- Combien de sinistres sont enregistres
-- par type apres standardisation des libelles ?

SELECT
    LOWER(TRIM(type_sinistre)) AS type_sinistre_normalise,
    COUNT(*) AS nb_sinistres
FROM fact_sinistre
GROUP BY LOWER(TRIM(type_sinistre))
ORDER BY nb_sinistres DESC;

------------------------------------------------------------

-- ==========================================
-- CONTROLE 10.3 : MONTANT MOYEN ESTIME PAR TYPE
-- ==========================================

-- QUESTION METIER :
-- Quel est le montant moyen estime
-- par type de sinistre ?

SELECT
    type_sinistre,
    AVG(montant_estime) AS montant_moyen,
    COUNT(*) AS nb_sinistres
FROM fact_sinistre
GROUP BY type_sinistre
ORDER BY montant_moyen DESC;


-- RESULTAT OBTENU :
-- Le montant moyen estime varie selon le type de sinistre.
-- Incendie : environ 27 058,80.
-- Inondation : environ 18 111,01.
-- Bris de glace : environ 13 351,68.
-- Tempete : environ 11 523,92.
-- Vol : environ 7 495,41.
-- Degat des eaux : environ 4 404,70.

-- INTERPRETATION :
-- Les montants moyens sont differents selon les types
-- de sinistres.
-- Les incendies presentent le montant moyen le plus eleve
-- parmi les principales categories affichees.
-- Des variantes de libelles restent presentes.

-- IMPACT METIER :
-- Les differences de montants peuvent influencer
-- l'evaluation du cout des sinistres.
-- Les libelles non standardises peuvent fragmenter
-- les indicateurs par categorie.

-- DECISION PROPOSEE :
-- Standardiser les types de sinistres apres verification.
-- Recalculer les moyennes apres nettoyage.
-- Comparer les montants moyens avec les volumes
-- et les montants totaux par categorie.



-- =====================================================
-- CONTROLE 10.2 BIS : STANDARDISATION DES TYPES
-- =====================================================

-- QUESTION METIER :
-- Combien de sinistres sont enregistres
-- par type apres standardisation des libelles ?

SELECT
    CASE
        WHEN LOWER(TRIM(type_sinistre)) LIKE 'temp_te'
            THEN 'Tempête'
        WHEN LOWER(TRIM(type_sinistre)) LIKE 'd_g_t des eaux'
            THEN 'Dégât des eaux'
        WHEN LOWER(TRIM(type_sinistre)) LIKE 'gr_le'
            THEN 'Grêle'
        WHEN LOWER(TRIM(type_sinistre)) = 'vol'
            THEN 'Vol'
        WHEN LOWER(TRIM(type_sinistre)) = 'incendie'
            THEN 'Incendie'
        WHEN LOWER(TRIM(type_sinistre)) = 'inondation'
            THEN 'Inondation'
        WHEN LOWER(TRIM(type_sinistre)) = 'bris de glace'
            THEN 'Bris de glace'
        WHEN LOWER(TRIM(type_sinistre))
             IN ('responsabilité civile', 'responsabilite civile')
            THEN 'Responsabilité civile'
        ELSE INITCAP(LOWER(TRIM(type_sinistre)))
    END AS type_sinistre_standardise,

    COUNT(*) AS nb_sinistres

FROM fact_sinistre

GROUP BY 1
ORDER BY nb_sinistres DESC;

-- RESULTAT OBTENU :
-- 8 types de sinistres apres standardisation.
-- Degat des eaux : 3 746
-- Vol : 2 196
-- Grele : 1 608
-- Tempete : 1 546
-- Bris de glace : 1 466
-- Responsabilite civile : 900
-- Incendie : 628
-- Inondation : 400

-- INTERPRETATION :
-- Plusieurs variantes d'ecriture ont ete regroupees.
-- Les types de sinistres sont maintenant plus faciles
-- a comparer.

-- IMPACT METIER :
-- Sans standardisation, les indicateurs par type
-- de sinistre peuvent etre fragmentes.
-- Cela peut fausser les comparaisons et le reporting.

-- DECISION PROPOSEE :
-- Conserver cette regle de standardisation.
-- Verifier les valeurs restantes avant de valider
-- definitivement la nomenclature.
-------------------------------------------------------------

-- =====================================================
-- CONTROLE 10.3 : MONTANT MOYEN ESTIME PAR TYPE
-- =====================================================

-- QUESTION METIER :
-- Quel est le montant moyen estime
-- par type de sinistre ?

SELECT
    CASE
        WHEN LOWER(TRIM(type_sinistre)) LIKE 'temp_te'
            THEN 'Tempête'
        WHEN LOWER(TRIM(type_sinistre)) LIKE 'd_g_t des eaux'
            THEN 'Dégât des eaux'
        WHEN LOWER(TRIM(type_sinistre)) LIKE 'gr_le'
            THEN 'Grêle'
        WHEN LOWER(TRIM(type_sinistre)) = 'vol'
            THEN 'Vol'
        WHEN LOWER(TRIM(type_sinistre)) = 'incendie'
            THEN 'Incendie'
        WHEN LOWER(TRIM(type_sinistre)) = 'inondation'
            THEN 'Inondation'
        WHEN LOWER(TRIM(type_sinistre)) = 'bris de glace'
            THEN 'Bris de glace'
        WHEN LOWER(TRIM(type_sinistre))
             IN ('responsabilité civile', 'responsabilite civile')
            THEN 'Responsabilité civile'
        ELSE INITCAP(LOWER(TRIM(type_sinistre)))
    END AS type_sinistre_standardise,

    ROUND(AVG(montant_estime), 2) AS montant_moyen,
    COUNT(*) AS nb_sinistres

FROM fact_sinistre

GROUP BY 1
ORDER BY montant_moyen DESC;


-- RESULTAT OBTENU :
-- Incendie : 26 732,65 € (628 sinistres)
-- Inondation : 18 111,01 € (400 sinistres)
-- Bris de glace : 13 223,03 € (1 466 sinistres)
-- Tempête : 11 355,55 € (1 546 sinistres)
-- Vol : 7 452,78 € (2 196 sinistres)
-- Dégât des eaux : 4 385,14 € (3 746 sinistres)
-- Grêle : 3 333,38 € (1 608 sinistres)
-- Responsabilité civile : 2 600,03 € (900 sinistres)

-- INTERPRETATION :
-- L'incendie presente le montant moyen estime le plus eleve :
-- 26 732,65 € par sinistre.
-- La responsabilite civile presente le montant moyen le plus faible :
-- 2 600,03 € par sinistre.
-- Les degats des eaux representent le plus grand nombre de sinistres :
-- 3 746 cas.

-- IMPACT METIER :
-- Les montants moyens varient fortement selon le type de sinistre.
-- Ces differences peuvent influencer l'evaluation des risques
-- et la prevision des indemnisations.

-- DECISION PROPOSEE :
-- Examiner les sinistres incendie et inondation,
-- dont les montants moyens estimes sont les plus eleves.
-- Verifier les valeurs manquantes avant de valider les indicateurs.
-----------------------------------------------------------------------

-- =====================================================
-- CONTROLE 10.4 : NOMBRE DE SINISTRES PAR REGION
-- =====================================================

-- QUESTION METIER :
-- Combien de sinistres sont enregistres par region ?

SELECT
    region_sinistre,
    COUNT(*) AS nb_sinistres

FROM fact_sinistre

GROUP BY region_sinistre

ORDER BY nb_sinistres DESC;

-- RESULTAT OBTENU :
-- Occitanie : 1 870 sinistres
-- Provence-Alpes-Côte d'Azur : 1 646
-- Grand Est : 1 539
-- Auvergne-Rhône-Alpes : 1 400
-- Normandie : 1 179
-- Nouvelle-Aquitaine : 882
-- Hauts-de-France : 784
-- Bourgogne-Franche-Comté : 773
-- Pays de la Loire : 762
-- Bretagne : 748
-- Île-de-France : 464
-- Centre-Val de Loire : 383
-- Région manquante : 60

-- INTERPRETATION :
-- L'Occitanie presente le plus grand nombre de sinistres :
-- 1 870 cas.
-- Le Centre-Val de Loire presente le plus petit nombre
-- parmi les regions renseignees : 383 cas.
-- 60 sinistres n'ont pas de region renseignee.

-- IMPACT METIER :
-- Les volumes de sinistres varient selon les regions.
-- Les 60 localisations manquantes peuvent limiter
-- la precision des analyses geographiques.

-- DECISION PROPOSEE :
-- Verifier les 60 sinistres sans region renseignee.
-- Comparer les volumes regionaux avec le nombre de contrats
-- et le portefeuille d'assures avant de tirer des conclusions.
-------------------------------------------------------------------

-- =====================================================
-- CONTROLE 10.5 : NOMBRE DE SINISTRES PAR STATUT
-- =====================================================

-- QUESTION METIER :
-- Combien de sinistres sont enregistres par statut ?

SELECT
    statut_sinistre,
    COUNT(*) AS nb_sinistres

FROM fact_sinistre

GROUP BY statut_sinistre

ORDER BY nb_sinistres DESC;

-- =====================================================
-- CONTROLE 10.5 : NOMBRE DE SINISTRES PAR STATUT
-- =====================================================

-- QUESTION METIER :
-- Combien de sinistres sont enregistres par statut ?

SELECT
    statut_sinistre,
    COUNT(*) AS nb_sinistres
FROM public.fact_sinistre
GROUP BY statut_sinistre
ORDER BY nb_sinistres DESC;


-- RESULTAT OBTENU :
-- Clôturé : 4 850 sinistres
-- En cours : 2 460 sinistres
-- Expertisé : 2 400 sinistres
-- Refusé : 1 800 sinistres
-- Déclaré : 980 sinistres
-- Total : 12 490 sinistres


-- INTERPRETATION :
-- Le statut "Clôturé" est le plus fréquent,
-- avec 4 850 sinistres.
-- 2 460 sinistres sont encore en cours.
-- 1 800 sinistres ont été refusés.
-- 980 sinistres sont au stade "Déclaré".


-- IMPACT METIER :
-- Les sinistres en cours peuvent nécessiter
-- un suivi opérationnel.
-- Le nombre de refus justifie une analyse
-- complémentaire des motifs de refus.


-- DECISION PROPOSEE :
-- Analyser les délais de traitement des sinistres.
-- Examiner les motifs de refus.
-- Vérifier la cohérence des statuts.
-------------------------------------------------------------

-- =====================================================
-- CONTROLE 10.6 : MONTANT TOTAL DES INDEMNISATIONS
-- =====================================================

-- QUESTION METIER :
-- Quel est le montant total des indemnisations ?

SELECT
    ROUND(SUM(montant_indemnise), 2)
        AS montant_total_indemnisations
FROM fact_indemnisation;

-- RESULTAT OBTENU :
-- Montant total des indemnisations :
-- 57 602 664,10 euros


-- INTERPRETATION :
-- Le montant total des indemnisations enregistre
-- dans la base de donnees est de 57 602 664,10 euros.
-- Ce montant correspond a la somme des paiements
-- enregistres dans la table fact_indemnisation.


-- IMPACT METIER :
-- Cet indicateur permet d'evaluer le volume financier
-- des indemnisations enregistrees.
-- Il constitue une reference pour le suivi financier
-- et le controle des paiements.


-- DECISION PROPOSEE :
-- Comparer le montant des indemnisations avec
-- les montants estimes des sinistres.
-- Verifier les paiements et les eventuelles valeurs
-- manquantes avant de valider les indicateurs.
----------------------------------------------------------------

-- =====================================================
-- CONTROLE 10.7 : MONTANT MOYEN DES INDEMNISATIONS
-- =====================================================

-- QUESTION METIER :
-- Quel est le montant moyen des indemnisations ?

SELECT
    ROUND(AVG(montant_indemnise), 2)
        AS montant_moyen_indemnisation
FROM fact_indemnisation;


-- RESULTAT OBTENU :
-- Montant moyen des indemnisations :
-- 4 147,06 euros


-- INTERPRETATION :
-- Le montant moyen d'une indemnisation enregistree
-- est de 4 147,06 euros.
-- Il s'agit d'une moyenne calculee sur les
-- enregistrements de la table fact_indemnisation.


-- IMPACT METIER :
-- Cet indicateur permet d'evaluer le montant moyen
-- des paiements enregistres.
-- La moyenne peut etre influencee par des
-- indemnisations exceptionnellement elevees.


-- DECISION PROPOSEE :
-- Comparer la moyenne avec la mediane.
-- Analyser les montants extremes.
-- Verifier les eventuelles valeurs manquantes
-- avant de valider les conclusions.
------------------------------------------------------

-- =====================================================
-- CONTROLE 10.8 : NOMBRE DE CONTRATS PAR FORMULE
-- =====================================================

-- QUESTION METIER :
-- Combien de contrats existe-t-il par formule ?

SELECT
    formule,
    COUNT(*) AS nb_contrats
FROM dim_contrat
GROUP BY formule
ORDER BY nb_contrats DESC;

-- RESULTAT OBTENU :
-- Formule Essentielle : 12 800 contrats
-- Formule Confort : 12 800 contrats
-- Formule Premium : 6 400 contrats
-- Total : 32 000 contrats


-- INTERPRETATION :
-- Les formules Essentielle et Confort
-- comptent chacune 12 800 contrats.
-- La formule Premium compte 6 400 contrats.
-- Elle represente 20 % des contrats.
-- Les formules Essentielle et Confort
-- representent chacune 40 % des contrats.


-- IMPACT METIER :
-- La repartition des contrats permet d'identifier
-- les formules les plus souscrites.
-- La formule Premium est moins representee
-- que les deux autres formules.


-- DECISION PROPOSEE :
-- Analyser les primes annuelles par formule.
-- Comparer la rentabilite des differentes formules.
-- Etudier les possibilites de developpement
-- de la formule Premium.
---------------------------------------------------------------

-- =====================================================
-- CONTROLE 11.1 : DONNEES PERSONNELLES - RGPD et minimisation
-- =====================================================

-- QUESTION METIER :
-- Quelles donnees personnelles sont presentes dans dim_assure ?

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'dim_assure'
ORDER BY ordinal_position;

-- RESULTAT OBTENU :
-- La table dim_assure contient 11 colonnes.
-- Elle comprend des donnees directement identifiantes :
-- nom, prenom et email.
-- Elle contient egalement la date de naissance,
-- le sexe, les informations geographiques,
-- la date d'entree et le statut de l'assure.
-- L'identifiant assure_id permet de relier
-- les informations d'un meme assure.


-- INTERPRETATION :
-- Plusieurs colonnes contiennent des donnees personnelles.
-- Certaines sont necessaires a la gestion des contrats,
-- mais ne sont pas forcement utiles au reporting.
-- L'identifiant assure_id ne garantit pas l'anonymat.


-- IMPACT METIER :
-- L'utilisation de donnees personnelles non necessaires
-- augmente les risques lies a la confidentialite
-- et a la protection des donnees.


-- DECISION PROPOSEE :
-- Identifier les colonnes necessaires aux indicateurs.
-- Limiter l'utilisation des noms et des emails.
-- Privilegier les donnees agregees pour les tableaux de bord.
------------------------------------------------------------------

-- =====================================================
-- CONTROLE 11.2 : DONNEES NECESSAIRES AU REPORTING
-- =====================================================

-- QUESTION METIER :
-- Quelles donnees sont reellement necessaires
-- au futur reporting ?

SELECT
    COUNT(*) AS nb_assures,
    COUNT(DISTINCT assure_id) AS nb_assures_uniques,
    COUNT(DISTINCT ville) AS nb_villes,
    COUNT(DISTINCT region) AS nb_regions
FROM dim_assure;

-- RESULTAT OBTENU :
-- 25 040 assures sont enregistres.
-- Les 25 040 identifiants sont uniques.
-- Les donnees couvrent 60 villes et 36 regions.


-- INTERPRETATION :
-- Aucun doublon d'identifiant assure_id n'est detecte.
-- Les informations geographiques permettent
-- de realiser des analyses par ville et par region.
-- L'unicite de l'identifiant ne garantit pas
-- l'absence de doublons de personnes.


-- IMPACT METIER :
-- Les analyses peuvent s'appuyer sur les identifiants
-- pour compter les assures.
-- Les donnees geographiques permettent de comparer
-- la repartition des assures entre les territoires.


-- DECISION PROPOSEE :
-- Conserver assure_id pour les analyses necessaires.
-- Privilegier les indicateurs agreges par territoire.
-- Ne pas exposer les noms et les emails dans le reporting.
-- Verifier les besoins metier avant de conserver
-- les autres donnees personnelles.
----------------------------------------------------------------

-- =====================================================
-- CONTROLE 11.3 : COLONNES A CONSERVER
-- =====================================================

-- QUESTION METIER :
-- Quelles colonnes doivent etre conservees ?

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'dim_assure'
ORDER BY ordinal_position;

-- RESULTAT OBTENU :
-- La table dim_assure contient 11 colonnes.
-- Elle contient un identifiant, des donnees personnelles,
-- des informations geographiques et des dates.
-- Elle contient egalement le statut de l'assure.


-- INTERPRETATION :
-- Toutes les colonnes ne sont pas necessaires
-- pour les analyses metier.
-- Certaines informations peuvent etre utilisees
-- pour les indicateurs agreges.
-- Les noms et les emails sont des donnees personnelles.


-- IMPACT METIER :
-- L'utilisation de donnees personnelles non necessaires
-- augmente les risques lies a la confidentialite.
-- Un reporting avec des donnees agregees limite
-- l'exposition des informations individuelles.


-- DECISION PROPOSEE :
-- Conserver les colonnes necessaires aux indicateurs.
-- Utiliser les informations geographiques pour les analyses
-- par ville, departement et region.
-- Limiter l'acces aux noms, prenoms et emails.
-- Justifier la conservation des autres colonnes
-- selon les besoins metier.
-------------------------------------------------------------------

-- =====================================================
-- CONTROLE 11.4 : COLONNES A TRANSFORMER
-- =====================================================

-- QUESTION METIER :
-- Quelles colonnes pourraient etre transformees ?

SELECT
    COUNT(*) AS nb_assures,
    COUNT(date_naissance) AS nb_dates_naissance,
    COUNT(date_entree) AS nb_dates_entree,
    COUNT(ville) AS nb_villes_renseignees,
    COUNT(departement) AS nb_departements_renseignes,
    COUNT(region) AS nb_regions_renseignees
FROM dim_assure;

-- RESULTAT OBTENU :
-- 25 040 assures sont enregistres.
-- 24 540 dates de naissance sont renseignees.
-- 500 dates de naissance sont manquantes.
-- Les autres colonnes controlees sont renseignees
-- pour les 25 040 enregistrements.


-- INTERPRETATION :
-- Les donnees geographiques sont renseignees.
-- La date de naissance est manquante
-- pour environ 2 % des assures.
-- Cette absence limite certaines analyses demographiques.


-- IMPACT METIER :
-- Les donnees geographiques peuvent etre utilisees
-- pour les analyses territoriales.
-- Les analyses par age doivent tenir compte
-- des dates de naissance manquantes.


-- DECISION PROPOSEE :
-- Calculer l'age a partir de la date de naissance
-- uniquement lorsque cette date est disponible.
-- Ne pas remplacer les dates manquantes par des valeurs
-- inventees.
-- Documenter les limites des indicateurs demographiques.
-------------------------------------------------------------------

-- =====================================================
-- CONTROLE 11.5 : DONNEES A NE PAS EXPOSER
-- =====================================================

-- QUESTION METIER :
-- Quelles colonnes ne devraient pas etre exposees dans le reporting ?

SELECT
    COUNT(*) AS nb_assures,
    COUNT(nom) AS nb_noms,
    COUNT(prenom) AS nb_prenoms,
    COUNT(email) AS nb_emails,
    COUNT(DISTINCT email) AS nb_emails_uniques
FROM dim_assure;

-- RESULTAT OBTENU :
-- 25 040 noms et prenoms sont renseignes.
-- 24 283 adresses email sont renseignees.
-- 757 adresses email sont manquantes.
-- 24 185 adresses email sont uniques.
-- Des adresses email sont partagees entre plusieurs lignes.


-- INTERPRETATION :
-- Les noms et prenoms sont renseignes pour tous les assures.
-- Certaines adresses email sont absentes.
-- Certaines adresses email apparaissent plusieurs fois.
-- Un email partage ne signifie pas necessairement
-- qu'il existe un doublon d'assure.


-- IMPACT METIER :
-- L'exposition des noms, prenoms et emails augmente
-- les risques lies a la confidentialite.
-- Les emails manquants et partages peuvent limiter
-- certaines analyses individuelles.


-- DECISION PROPOSEE :
-- Ne pas exposer les noms, prenoms et emails
-- dans les tableaux de bord generaux.
-- Utiliser des indicateurs agreges lorsque cela suffit.
-- Verifier les emails partages avant de conclure
-- a l'existence de doublons.
-------------------------------------------------------------

-- =====================================================
-- CONTROLE 12.1 : PRINCIPALES ANOMALIES IDENTIFIEES
-- =====================================================

-- QUESTION METIER :
-- Quelles sont les principales anomalies identifiees ?

SELECT
    COUNT(*) AS nb_assures,
    COUNT(DISTINCT assure_id) AS nb_assures_uniques,
    COUNT(*) - COUNT(date_naissance)
        AS nb_dates_naissance_manquantes,
    COUNT(*) - COUNT(email)
        AS nb_emails_manquants,
    COUNT(email) - COUNT(DISTINCT email)
        AS nb_emails_non_uniques
FROM dim_assure;

-- RESULTAT OBTENU :
-- 25 040 assures et 25 040 identifiants uniques.
-- 500 dates de naissance manquantes.
-- 757 emails manquants.
-- 98 emails en exces par rapport au nombre d'emails uniques.

-- INTERPRETATION :
-- Aucun doublon d'identifiant assure_id n'est detecte.
-- Certaines dates de naissance et adresses email sont manquantes.
-- Des adresses email sont partagees ou repetees.

-- IMPACT METIER :
-- Les donnees manquantes peuvent limiter certaines analyses.
-- Les emails repetes doivent etre verifies avant toute conclusion.
-- Les noms et emails doivent etre proteges dans le reporting.

-- DECISION PROPOSEE :
-- Verifier les emails repetes.
-- Documenter les donnees manquantes.
-- Limiter l'exposition des donnees personnelles.
------------------------------------------------------------

-- =====================================================
-- CONTROLE 12.2 : RISQUES POUR LES ANALYSES
-- =====================================================

-- QUESTION METIER :
-- Quels risques les donnees manquantes peuvent-elles provoquer dans les analyses ?

SELECT
    COUNT(*) AS nb_assures,
    COUNT(date_naissance) AS nb_dates_naissance_renseignees,
    COUNT(*) - COUNT(date_naissance)
        AS nb_dates_naissance_manquantes,
    COUNT(ville) AS nb_villes_renseignees,
    COUNT(*) - COUNT(ville)
        AS nb_villes_manquantes,
    COUNT(region) AS nb_regions_renseignees,
    COUNT(*) - COUNT(region)
        AS nb_regions_manquantes
FROM dim_assure;

-- RESULTAT OBTENU :
-- 25 040 assures.
-- 500 dates de naissance manquantes.
-- Aucune ville ni region manquante.

-- INTERPRETATION :
-- Les donnees geographiques sont completes.
-- Les dates de naissance sont manquantes pour 500 assures.
-- Les analyses demographiques peuvent etre incompletes.

-- IMPACT METIER :
-- Les donnees geographiques permettent des analyses territoriales.
-- Les dates manquantes peuvent limiter les analyses par age.

-- DECISION PROPOSEE :
-- Conserver les donnees geographiques.
-- Verifier les dates de naissance manquantes.
-- Ne pas remplacer les valeurs manquantes par des dates inventees.
--------------------------------------------------------------------------

-- =====================================================
-- CONTROLE 12.3 : DONNEES EXPLOITABLES
-- =====================================================

-- QUESTION METIER :
-- Quelles donnees peuvent etre utilisees pour le reporting ?

SELECT
    COUNT(*) AS nb_assures,
    COUNT(sexe) AS nb_sexes_renseignes,
    COUNT(date_entree) AS nb_dates_entree_renseignees,
    COUNT(statut_assure) AS nb_statuts_renseignes,
    COUNT(departement) AS nb_departements_renseignes,
    COUNT(region) AS nb_regions_renseignees
FROM dim_assure;

-- RESULTAT OBTENU :
-- 25 040 assures.
-- Toutes les colonnes controlees sont renseignees.

-- INTERPRETATION :
-- Les champs analyses ne presentent aucune valeur NULL.
-- Les donnees sont completes pour ces indicateurs.

-- IMPACT METIER :
-- Les donnees permettent des analyses par sexe,
-- statut et zone geographique.
-- La completude ne garantit pas l'exactitude des valeurs.

-- DECISION PROPOSEE :
-- Conserver les champs utiles au reporting.
-- Verifier la coherence des valeurs.
-- Limiter l'exposition des donnees personnelles.

-------------------------------------------------------------------------

-- =====================================================
-- CONTROLE 12.4 : TRAITEMENTS AVANT REPORTING
-- =====================================================

-- QUESTION METIER :
-- Quels traitements recommandez-vous avant la mise en reporting ?

SELECT
    COUNT(*) AS nb_assures,
    COUNT(date_naissance) AS nb_dates_naissance_renseignees,
    COUNT(*) - COUNT(date_naissance)
        AS nb_dates_naissance_manquantes,
    COUNT(email) AS nb_emails_renseignes,
    COUNT(*) - COUNT(email)
        AS nb_emails_manquants,
    COUNT(DISTINCT LOWER(TRIM(email)))
        AS nb_emails_distincts,
    COUNT(*) FILTER (
        WHERE email IS NOT NULL
          AND TRIM(email) = ''
    ) AS nb_emails_vides
FROM dim_assure;


-- RESULTAT OBTENU :
-- 25 040 assures dans la table.
-- 500 dates de naissance manquantes.
-- 757 emails manquants (NULL).
-- 24 283 emails renseignes.
-- 24 185 emails distincts apres normalisation.
-- 0 email vide ('').

-- INTERPRETATION :
-- Les donnees contiennent des valeurs manquantes.
-- Les emails peuvent presenter des doublons.
-- Les valeurs manquantes ne doivent pas etre
-- remplacees par des donnees inventees.

-- IMPACT METIER :
-- Les dates de naissance manquantes limitent
-- les analyses demographiques par age.
-- Les emails manquants limitent certains contacts.
-- Les doublons potentiels peuvent fausser
-- certaines analyses du nombre de contacts.

-- DECISION PROPOSEE :
-- Conserver les identifiants assure_id.
-- Normaliser les emails avec LOWER et TRIM.
-- Verifier les emails en doublon avant toute correction.
-- Conserver les valeurs manquantes comme telles.
-- Limiter l'exposition des donnees personnelles.
-- Privilegier les indicateurs agreges dans le reporting.
--------------------------------------------------------------------

-- ================================================
-- CONTROLE 12.5 : POINTS NECESSITANT UNE INVESTIGATION
-- ================================================

-- QUESTION METIER :
-- Quels points necessitent encore une investigation ?

SELECT
    COUNT(*) AS nb_assures,

    COUNT(DISTINCT assure_id)
        AS nb_assures_uniques,

    COUNT(*) - COUNT(date_naissance)
        AS nb_dates_naissance_manquantes,

    COUNT(*) - COUNT(email)
        AS nb_emails_manquants,

    COUNT(DISTINCT LOWER(TRIM(email)))
        AS nb_emails_distincts,

    COUNT(*) FILTER (
        WHERE email IS NOT NULL
          AND TRIM(email) <> ''
          AND email NOT LIKE '%@%.%'
    ) AS nb_emails_format_suspect

FROM dim_assure;

-- RESULTAT OBTENU :
-- 25 040 assures uniques.
-- 500 dates de naissance manquantes.
-- 757 emails manquants.
-- 24 185 emails distincts apres normalisation.
-- 0 email au format suspect selon le controle effectue.

-- INTERPRETATION :
-- Les principales anomalies concernent les donnees manquantes.
-- Des emails partages ou dupliques restent a verifier.
-- Le controle du format ne garantit pas la validite des emails.

-- IMPACT METIER :
-- Les donnees manquantes peuvent limiter certaines analyses.
-- Les doublons potentiels peuvent fausser les indicateurs.
-- Les donnees personnelles doivent etre protegees.

-- DECISION PROPOSEE :
-- Verifier les emails repetes entre plusieurs assures.
-- Identifier l'origine des dates de naissance manquantes.
-- Confirmer les besoins metier concernant les emails.
-- Documenter les limites des donnees avant le reporting.
------------------------------------------------------------------------


-- =====================================================
-- BRIEF 8 : DIAGNOSTIC FINAL
-- Projet : Assurisk
-- Sujet : Qualite des donnees, risques et RGPD
-- =====================================================

-- 1. PRINCIPALES ANOMALIES IDENTIFIEES
--
-- La table dim_assure contient 25 040 assures.
-- 500 dates de naissance sont manquantes.
-- 757 adresses email sont manquantes.
-- 24 185 emails distincts apres normalisation.
-- Aucun email au format suspect selon notre controle.
--
-- L'unicite des identifiants assure_id a ete verifiee.
-- Aucun doublon d'identifiant n'a ete detecte.

-- 2. RISQUES POUR LES ANALYSES
--
-- Les dates de naissance manquantes limitent
-- les analyses demographiques par age.
-- Les emails manquants limitent certains usages
-- lies a la communication avec les assures.
-- Les emails repetes peuvent fausser les analyses
-- du nombre de contacts uniques.
-- Le controle du format ne garantit pas la validite
-- reelle des adresses email.

-- 3. DONNEES EXPLOITABLES
--
-- Les identifiants assure_id peuvent servir
-- au comptage des assures.
-- Les donnees geographiques peuvent etre utilisees
-- pour les analyses territoriales.
-- Les dates de naissance peuvent etre utilisees
-- lorsqu'elles sont renseignees et pertinentes.
-- Les indicateurs agreges sont a privilegier
-- dans les tableaux de bord.

-- 4. TRAITEMENTS RECOMMANDES
--
-- Normaliser les emails avec LOWER et TRIM.
-- Verifier les emails repetes entre plusieurs assures.
-- Investiguer l'origine des dates manquantes.
-- Conserver les valeurs manquantes sans inventer
-- de donnees de remplacement.
-- Limiter l'utilisation des noms, prenoms et emails.
-- Documenter les limites des indicateurs produits.

-- 5. POINTS NECESSITANT UNE INVESTIGATION
--
-- Comprendre pourquoi 500 dates de naissance manquent.
-- Determiner si les 757 emails manquants sont acceptables
-- au regard des besoins metier.
-- Verifier les emails partages ou dupliques.
-- Confirmer les regles de gestion applicables
-- avant la mise en reporting.

-- CONCLUSION
--
-- La base est exploitable pour plusieurs analyses,
-- sous reserve de documenter les limites identifiees. 
-- Les donnees manquantes et les emails repetes
-- doivent etre examines avant de valider les indicateurs.
-- La minimisation des donnees personnelles doit etre
-- appliquee tout au long du processus de reporting.













