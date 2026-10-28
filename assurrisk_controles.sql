-- Brief 8 "AssurRisk" -- 
------------------------------------------------

-- ================================================
-- 1. EXPLORER LA BASE
-- ================================================

-- 1.1: Quelles sont les tables de dimensions ?

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name LIKE 'dim_%'
ORDER BY table_name;

-- COMMENTAIRE :
-- Les tables dont le nom commence par dim_ sont identifiées
-- comme tables de dimensions dans le modèle AssurRisk.
-- REPONSE :
-- Les tables de dimensions sont :
-- dim_assure : informations sur les assurés.
-- dim_agence : informations sur les agences.
-- dim_garantie : informations sur les garanties.
-- dim_contrat : informations sur les contrats.
------------------------------------------------------------

-- 1.2: Quelles sont les tables de faits ?

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name LIKE 'fact\_%' ESCAPE '\'
ORDER BY table_name;

-- RESULTAT OBTENU :
-- Deux tables de faits ont ete identifiees :
-- fact_indemnisation et fact_sinistre.
--
-- INTERPRETATION :
-- fact_sinistre contient les donnees relatives
-- aux sinistres.
-- fact_indemnisation contient les donnees relatives
-- aux indemnisations.
--
-- CONCLUSION :
-- Les deux tables de faits ont ete identifiees
-- dans le schema public.
------------------------------------------------------------


-- 1.3: Quelle est la table d'association ?

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name = 'contrat_garantie';

-- RESULTAT OBTENU :
-- Une table d'association a ete identifiee :
-- contrat_garantie, dans le schema public.
--
-- INTERPRETATION :
-- Cette table permet d'associer les contrats
-- aux garanties.
--
-- CONCLUSION :
-- La table d'association est contrat_garantie.
------------------------------------------------------------

-- 1.4 : Quelles sont les clés primaires et les clés étrangères ?

SELECT
    tc.table_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS table_referencee,
    ccu.column_name AS colonne_referencee
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
    AND tc.constraint_type = 'FOREIGN KEY'
WHERE tc.table_schema = 'public'
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY
    tc.table_name,
    tc.constraint_type,
    kcu.column_name;

-- RESULTAT OBTENU :
-- Les cles primaires et les cles etrangeres
-- declarees dans le schema public ont ete identifiees.
-- La table contrat_garantie possede une cle primaire
-- composee de contrat_id et garantie_id.
--
-- INTERPRETATION :
-- Les cles primaires identifient les enregistrements.
-- Les cles etrangeres definissent les relations
-- entre les tables.
--
-- CONCLUSION :
-- Les contraintes de cles primaires et etrangeres
-- sont identifiees dans le schema public.
-- Leur existence ne garantit pas a elle seule
-- la coherence de toutes les donnees metier.
------------------------------------------------------------

-- 1.5 : Comment les tables sont-elles reliees entre elles ?

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
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY
    tc.table_name,
    kcu.column_name;

-- RESULTAT OBTENU :
-- Huit cles etrangeres ont ete identifiees.
--
-- INTERPRETATION :
-- Les contrats sont relies aux assures et aux agences.
-- La table contrat_garantie relie les contrats
-- aux garanties.
-- Les sinistres sont relies aux contrats, aux agences
-- et aux garanties.
-- Les indemnisations sont reliees aux sinistres.
--
-- CONCLUSION :
-- Les relations entre les tables sont definies
-- par huit cles etrangeres dans le schema public.
------------------------------------------------------------

-- 1.6 : Quels sont les volumes de chaque table ?

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

-- RESULTAT OBTENU :
-- dim_agence : 25 lignes.
-- dim_assure : 25 040 lignes.
-- dim_contrat : 32 000 lignes.
-- dim_garantie : 12 lignes.
-- contrat_garantie : 89 600 lignes.
-- fact_sinistre : 12 490 lignes.
-- fact_indemnisation : 13 890 lignes.
--
-- INTERPRETATION :
-- La base contient sept tables.
-- Les volumes varient selon le role de chaque table.
-- La table contrat_garantie contient 89 600 lignes,
-- contre 32 000 lignes dans dim_contrat.
--
-- CONCLUSION :
-- Les volumes des sept tables ont ete controles.
------------------------------------------------------------

--  1.7 : Quelle période les données couvrent-elles ?


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

-- ================================================
--  2. Auditer la qualité des données
-- ================================================

-- 2.1: Existe-t-il des doublons ?

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

-- RESULTAT OBTENU :
-- 100 groupes de doublons potentiels ont ete detectes.
-- 200 lignes sont concernees.
-- 100 lignes seraient excedentaires si les doublons
-- etaient confirmes.
-- Le nombre maximal d'occurrences par groupe est de 2.

-- INTERPRETATION :
-- Les 100 groupes contiennent chacun deux lignes
-- presentant les memes valeurs pour les sept champs
-- utilises dans le controle.
-- Ces lignes constituent des doublons potentiels,
-- mais leur identite reelle n'est pas encore confirmee.

-- IMPACT METIER :
-- Ces doublons potentiels peuvent surestimer le nombre
-- de sinistres et fausser les indicateurs, notamment
-- les volumes et les montants moyens par type de sinistre.

-- DECISION PROPOSEE :
-- Verifier les identifiants sinistre_id et les autres
-- informations disponibles pour chaque groupe.
-- Ne supprimer aucune ligne avant confirmation.
-- Documenter les doublons confirmes et definir
-- une regle de traitement adaptee.
------------------------------------------------------------

-- 2.2: Existe-t-il des incoherences de dates ?

SELECT
    sinistre_id,
    contrat_id,
    date_survenance,
    date_declaration,
    type_sinistre
FROM public.fact_sinistre
WHERE date_declaration < date_survenance
ORDER BY date_survenance;

-- RESULTAT OBTENU :
-- 80 sinistres presentent une date de declaration
-- anterieure a la date de survenance.
-- L'ecart maximal observe est de 14 jours.

-- INTERPRETATION :
-- Ces enregistrements presentent une incoherence
-- chronologique apparente entre la survenance
-- et la declaration du sinistre.
-- Une verification des dates sources est necessaire.

-- IMPACT METIER :
-- Ces incoherences peuvent fausser le calcul
-- des delais de declaration et les indicateurs
-- relatifs au traitement des sinistres.

-- DECISION PROPOSEE :
-- Investiguer les 80 enregistrements concernes.
-- Verifier les dates dans les sources disponibles.
-- Ne modifier aucune date sans justification.
-- Documenter les anomalies confirmees.
------------------------------------------------------------

-- 2.3: Certains sinistres sont-ils lies a des contrats non actifs ?

SELECT
    c.statut_contrat,
    COUNT(*) AS nb_sinistres
FROM public.fact_sinistre AS s
JOIN public.dim_contrat AS c
    ON s.contrat_id = c.contrat_id
WHERE c.statut_contrat <> 'actif'
GROUP BY c.statut_contrat
ORDER BY nb_sinistres DESC;

-- RESULTAT OBTENU :
-- 70 sinistres sont associes a des contrats resilies.
-- 30 sinistres sont associes a des contrats expires.
-- Total : 100 sinistres associes a des contrats
-- dont le statut est different de 'actif'.

-- INTERPRETATION :
-- Le statut actuel du contrat ne permet pas de conclure
-- que le sinistre n'etait pas couvert au moment
-- de sa survenance.
-- Une verification des dates de couverture est necessaire.

-- CONCLUSION :
-- 100 sinistres necessitent une verification
-- de la validite de la couverture a la date du sinistre.
------------------------------------------------------------

-- 2.4: Certaines localisations sont-elles manquantes ou inutilisables ?

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'fact_sinistre'
ORDER BY ordinal_position;


-- Combien de sinistres ont une localisation manquante ou inexploitable ?

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

-- 2.5: Existe-t-il des montants nuls, negatifs ou aberrants ?
-- Etape 1 : identifier les colonnes de montants.

SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
      'fact_sinistre',
      'fact_indemnisation'
  )
  AND (
      column_name ILIKE '%montant%'
      OR column_name ILIKE '%franchise%'
      OR column_name ILIKE '%indemnis%'
  )
ORDER BY table_name, ordinal_position;


-- Existe-t-il des montants nuls, negatifs ou aberrants ?
-- Controle des montants nuls et negatifs.

SELECT
    'fact_sinistre' AS table_name,
    'montant_estime' AS colonne,
    COUNT(*) AS nb_total,
    COUNT(*) FILTER (
        WHERE montant_estime = 0
    ) AS nb_nuls,
    COUNT(*) FILTER (
        WHERE montant_estime < 0
    ) AS nb_negatifs,
    MIN(montant_estime) AS montant_min,
    MAX(montant_estime) AS montant_max
FROM public.fact_sinistre

UNION ALL

SELECT
    'fact_sinistre',
    'franchise',
    COUNT(*),
    COUNT(*) FILTER (WHERE franchise = 0),
    COUNT(*) FILTER (WHERE franchise < 0),
    MIN(franchise),
    MAX(franchise)
FROM public.fact_sinistre

UNION ALL

SELECT
    'fact_indemnisation',
    'montant_indemnise',
    COUNT(*),
    COUNT(*) FILTER (WHERE montant_indemnise = 0),
    COUNT(*) FILTER (WHERE montant_indemnise < 0),
    MIN(montant_indemnise),
    MAX(montant_indemnise)
FROM public.fact_indemnisation;

-- RESULTAT OBTENU :
-- montant_estime :
-- 10 montants nuls, 15 montants negatifs.
-- Minimum : -4 995 ; maximum : 1 350 000.
--
-- franchise :
-- 900 montants nuls, aucun montant negatif.
-- Minimum : 0 ; maximum : 500.
--
-- montant_indemnise :
-- 5 montants nuls, 5 montants negatifs.
-- Minimum : -500 ; maximum : 500 000.

-- INTERPRETATION :
-- Les montants negatifs des sinistres et des indemnisations
-- doivent etre verifies.
-- Les franchises nulles peuvent etre legitimes selon
-- les conditions du contrat.
-- Les montants maximaux observes doivent etre examines
-- pour determiner s'ils sont coherents avec les garanties.

-- IMPACT METIER :
-- Les montants incorrects peuvent fausser les totaux,
-- les moyennes, les couts des sinistres et les indicateurs
-- de performance des indemnisations.

-- DECISION PROPOSEE :
-- Examiner les 15 montants estimes negatifs et les
-- 5 montants indemnises negatifs.
-- Verifier les 10 estimations nulles et les 5 indemnisations
-- nulles selon les regles metier.
-- Confirmer les montants eleves avant toute correction.
-- Ne pas supprimer ni modifier les valeurs sans justification.
------------------------------------------------------------


-- 2.6: Existe-t-il des libelles non standardises ?
-- Etape 1 : identifier les colonnes textuelles.

SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
      'fact_sinistre',
      'fact_indemnisation',
      'dim_assure',
      'dim_agence',
      'dim_garantie',
      'dim_contrat'
  )
  AND data_type IN (
      'text',
      'character varying',
      'character'
  )
ORDER BY table_name, ordinal_position;


-- Existe-t-il des libelles non standardises ?
-- Controle des espaces et de la casse.

SELECT
    'fact_sinistre' AS table_name,
    'type_sinistre' AS colonne,
    type_sinistre AS valeur,
    COUNT(*) AS nb_occurrences
FROM public.fact_sinistre
GROUP BY type_sinistre
HAVING type_sinistre <> TRIM(type_sinistre)
    OR type_sinistre <> LOWER(type_sinistre)

UNION ALL

SELECT
    'fact_sinistre',
    'cause_sinistre',
    cause_sinistre,
    COUNT(*)
FROM public.fact_sinistre
GROUP BY cause_sinistre
HAVING cause_sinistre <> TRIM(cause_sinistre)
    OR cause_sinistre <> LOWER(cause_sinistre)

UNION ALL

SELECT
    'fact_sinistre',
    'statut_sinistre',
    statut_sinistre,
    COUNT(*)
FROM public.fact_sinistre
GROUP BY statut_sinistre
HAVING statut_sinistre <> TRIM(statut_sinistre)
    OR statut_sinistre <> LOWER(statut_sinistre)

UNION ALL

SELECT
    'fact_indemnisation',
    'statut_paiement',
    statut_paiement,
    COUNT(*)
FROM public.fact_indemnisation
GROUP BY statut_paiement
HAVING statut_paiement <> TRIM(statut_paiement)
    OR statut_paiement <> LOWER(statut_paiement)

UNION ALL

SELECT
    'fact_indemnisation',
    'mode_paiement',
    mode_paiement,
    COUNT(*)
FROM public.fact_indemnisation
GROUP BY mode_paiement
HAVING mode_paiement <> TRIM(mode_paiement)
    OR mode_paiement <> LOWER(mode_paiement)

UNION ALL

SELECT
    'dim_garantie',
    'categorie',
    categorie,
    COUNT(*)
FROM public.dim_garantie
GROUP BY categorie
HAVING categorie <> TRIM(categorie)
    OR categorie <> LOWER(categorie)

ORDER BY table_name, colonne, valeur;

-- RESULTAT OBTENU :
-- La requete retourne 51 lignes de resultats.
-- Plusieurs variantes de casse sont observees dans
-- le champ type_sinistre.
-- Exemples :
-- 'BRIS DE GLACE' : 8 occurrences.
-- 'Bris de glace' : 1 450 occurrences.
-- 'DÉGÂT DES EAUX' : 8 occurrences.
-- 'Dégât des Eaux' : 9 occurrences.
-- 'Dégât des eaux' : 3 720 occurrences.
-- 'Dégâts des eaux' : 9 occurrences.
-- 'TEMPÊTE' : 9 occurrences.
-- 'Tempete' : 8 occurrences.
-- 'Tempête' : 1 520 occurrences.

-- INTERPRETATION :
-- Plusieurs variantes d'ecriture peuvent correspondre
-- a une meme categorie de sinistre.
-- Les differences de casse, d'accents et de formulation
-- peuvent fragmenter les categories dans les analyses.
-- Les 51 lignes retournees ne representent pas
-- necessairement 51 anomalies distinctes.

-- IMPACT METIER :
-- Les regroupements par type de sinistre peuvent etre
-- incomplets ou difficiles a comparer.
-- Les indicateurs par categorie peuvent etre fausses.

-- DECISION PROPOSEE :
-- Definir un referentiel de libelles standardises.
-- Identifier les variantes correspondant a une meme categorie.
-- Valider les correspondances avant toute correction.
-- Conserver les valeurs originales pour assurer la tracabilite.
------------------------------------------------------------


-- 2.7: Certaines indemnisations sont-elles incoherentes avec le sinistre associe ?

-- Controle des indemnisations par sinistre.

SELECT
    s.sinistre_id,
    s.montant_estime,
    s.franchise,
    SUM(i.montant_indemnise) AS montant_total_indemnise,
    SUM(i.montant_indemnise)
        - (s.montant_estime - s.franchise)
        AS ecart_estimation
FROM public.fact_sinistre AS s
JOIN public.fact_indemnisation AS i
    ON s.sinistre_id = i.sinistre_id
GROUP BY
    s.sinistre_id,
    s.montant_estime,
    s.franchise
HAVING SUM(i.montant_indemnise)
       > (s.montant_estime - s.franchise)
ORDER BY ecart_estimation DESC;

-- RESULTAT OBTENU :
-- 837 sinistres présentent un montant total indemnisé supérieur au montant estimé moins la franchise.
-- Les écarts les plus importants concernent les sinistres 88, 87, 86, 85 et 68.
-- L'écart maximal observé est de 499 554,05 € pour le sinistre 88.

-- INTERPRETATION :
-- Les montants indemnisés dépassent les montants estimés après déduction de la franchise.
-- Ces écarts peuvent indiquer des anomalies de données ou une règle de calcul différente.
-- Les montants les plus élevés nécessitent une vérification prioritaire.

-- IMPACT METIER :
-- Des indemnisations incohérentes peuvent fausser les indicateurs financiers et le calcul du coût des sinistres.
-- Elles peuvent également entraîner des erreurs dans le reporting.

-- DECISION PROPOSEE :
-- Vérifier en priorité les cinq sinistres présentant les écarts les plus élevés.
-- Contrôler les règles de calcul des indemnisations et des franchises.
-- Ne pas corriger les montants avant d'avoir confirmé les anomalies.
----------------------------------------------------------------------------------------

-- 2.8: Existe-t-il des anomalies dans les données des assurés ?
-- OBJECTIF : identifier les champs manquants ou potentiellement incorrects.

SELECT
    COUNT(*) AS nb_total_assures,

    COUNT(*) FILTER (
        WHERE nom IS NULL OR TRIM(nom) = ''
    ) AS noms_manquants,

    COUNT(*) FILTER (
        WHERE prenom IS NULL OR TRIM(prenom) = ''
    ) AS prenoms_manquants,

    COUNT(*) FILTER (
        WHERE email IS NULL OR TRIM(email) = ''
    ) AS emails_manquants,

    COUNT(*) FILTER (
        WHERE email IS NOT NULL
          AND TRIM(email) <> ''
          AND email NOT LIKE '%_@_%._%'
    ) AS emails_potentiellement_invalides,

    COUNT(*) FILTER (
        WHERE sexe IS NULL OR TRIM(sexe) = ''
    ) AS sexes_manquants,

    COUNT(*) FILTER (
        WHERE ville IS NULL OR TRIM(ville) = ''
    ) AS villes_manquantes,

    COUNT(*) FILTER (
        WHERE region IS NULL OR TRIM(region) = ''
    ) AS regions_manquantes,

    COUNT(*) FILTER (
        WHERE statut_assure IS NULL
           OR TRIM(statut_assure) = ''
    ) AS statuts_manquants

FROM public.dim_assure;

-- RESULTAT OBTENU :
-- Nombre total d'assurés : 25 040.
-- Emails manquants : 757.
-- Noms, prénoms, sexes, villes, régions et statuts manquants : 0.
-- Emails potentiellement invalides : 0.

-- INTERPRETATION :
-- Les données des assurés sont globalement complètes pour les champs contrôlés.
-- Toutefois, 757 assurés ne disposent pas d'adresse email renseignée.
-- Aucun email potentiellement invalide n'a été détecté selon le contrôle effectué.

-- IMPACT METIER :
-- L'absence d'email peut compliquer la communication avec certains assurés.
-- Elle peut limiter l'envoi de notifications et le suivi des dossiers.

-- DECISION PROPOSEE :
-- Vérifier si l'adresse email est obligatoire pour tous les assurés.
-- Compléter les emails manquants à partir de sources fiables lorsque cela est possible.
-- Ne pas inventer ni modifier les coordonnées sans vérification.
-----------------------------------------------------------------------------------------------------

-- =====================================================
-- POUR CHAQUE ANOMALIE DETECTEE
-- Combien de lignes sont concernees ?
-- =====================================================

SELECT
    'Dates de declaration incoherentes' AS anomalie,
    COUNT(*) AS nb_lignes
FROM public.fact_sinistre
WHERE date_declaration < date_survenance

UNION ALL

SELECT
    'Localisation : ville manquante',
    COUNT(*)
FROM public.fact_sinistre
WHERE ville_sinistre IS NULL
   OR TRIM(ville_sinistre) = ''

UNION ALL

SELECT
    'Localisation : departement manquant',
    COUNT(*)
FROM public.fact_sinistre
WHERE departement_sinistre IS NULL
   OR TRIM(departement_sinistre) = ''

UNION ALL

SELECT
    'Localisation : region manquante',
    COUNT(*)
FROM public.fact_sinistre
WHERE region_sinistre IS NULL
   OR TRIM(region_sinistre) = ''

UNION ALL

SELECT
    'Localisation : coordonnees incompletes',
    COUNT(*)
FROM public.fact_sinistre
WHERE latitude IS NULL
   OR longitude IS NULL

UNION ALL

SELECT
    'Montants estimes negatifs',
    COUNT(*)
FROM public.fact_sinistre
WHERE montant_estime < 0

UNION ALL

SELECT
    'Franchises nulles',
    COUNT(*)
FROM public.fact_sinistre
WHERE franchise = 0

UNION ALL

SELECT
    'Indemnisations nulles',
    COUNT(*)
FROM public.fact_indemnisation
WHERE montant_indemnise = 0

UNION ALL

SELECT
    'Indemnisations negatives',
    COUNT(*)
FROM public.fact_indemnisation
WHERE montant_indemnise < 0

UNION ALL

SELECT
    'Dates de naissance manquantes',
    COUNT(*)
FROM public.dim_assure
WHERE date_naissance IS NULL

UNION ALL

SELECT
    'Emails manquants',
    COUNT(*)
FROM public.dim_assure
WHERE email IS NULL
   OR TRIM(email) = ''

ORDER BY nb_lignes DESC;

-- RESULTAT OBTENU :
-- Franchises nulles : 900 lignes.
-- Emails manquants : 757 lignes.
-- Dates de naissance manquantes : 500 lignes.
-- Dates de declaration incoherentes : 80 lignes.
-- Coordonnees incompletes : 60 lignes.
-- Regions manquantes : 60 lignes.
-- Villes manquantes : 40 lignes.
-- Departements manquants : 30 lignes.
-- Montants estimes negatifs : 15 lignes.
-- Indemnisations negatives : 5 lignes.
-- Indemnisations nulles : 5 lignes.

-- INTERPRETATION :
-- Les franchises nulles constituent l'anomalie
-- la plus frequente, avec 900 lignes.
-- Les emails et les dates de naissance manquants
-- peuvent limiter certaines analyses.
-- Les incoherences de dates necessitent une verification.
-- Les localisations incompletes peuvent limiter
-- les analyses geographiques.
-- Les montants negatifs ou nuls doivent etre examines
-- selon les regles de gestion applicables.
-- Une meme ligne peut presenter plusieurs anomalies.

-- IMPACT METIER :
-- Les donnees manquantes peuvent reduire la fiabilite
-- de certains indicateurs.
-- Les incoherences de dates peuvent fausser
-- les analyses chronologiques.
-- Les montants incorrects peuvent affecter
-- les indicateurs financiers.
-- Les localisations incompletes peuvent fausser
-- la repartition geographique des sinistres.

-- DECISION PROPOSEE :
-- Verifier les franchises nulles avant de les considerer
-- comme des anomalies confirmees.
-- Rechercher les dates et emails manquants
-- dans les sources fiables disponibles.
-- Investiguer les incoherences de dates
-- et les montants negatifs ou nuls.
-- Completer les localisations lorsque cela est possible.
-- Ne pas inventer de valeurs ni corriger sans verification.
-- Documenter les anomalies confirmees et les limites
-- des indicateurs produits.
------------------------------------------------------------------

-- Pourquoi ces anomalies peuvent-elles poser probleme ?

SELECT
    'Franchises nulles' AS anomalie,
    COUNT(*) AS nb_lignes,
    'Verifier les regles du contrat' AS risque
FROM public.fact_sinistre
WHERE franchise = 0

UNION ALL

SELECT
    'Emails manquants',
    COUNT(*),
    'Communication avec les assures limitee'
FROM public.dim_assure
WHERE email IS NULL OR TRIM(email) = ''

UNION ALL

SELECT
    'Dates de naissance manquantes',
    COUNT(*),
    'Analyses demographiques limitees'
FROM public.dim_assure
WHERE date_naissance IS NULL

UNION ALL

SELECT
    'Dates de declaration incoherentes',
    COUNT(*),
    'Delais de declaration potentiellement fausses'
FROM public.fact_sinistre
WHERE date_declaration < date_survenance

UNION ALL

SELECT
    'Coordonnees incompletes',
    COUNT(*),
    'Analyses geographiques incompletes'
FROM public.fact_sinistre
WHERE latitude IS NULL OR longitude IS NULL

UNION ALL

SELECT
    'Montants estimes negatifs',
    COUNT(*),
    'Indicateurs financiers potentiellement fausses'
FROM public.fact_sinistre
WHERE montant_estime < 0

UNION ALL

SELECT
    'Indemnisations negatives',
    COUNT(*),
    'Verifier corrections et remboursements'
FROM public.fact_indemnisation
WHERE montant_indemnise < 0

UNION ALL

SELECT
    'Indemnisations nulles',
    COUNT(*),
    'Verifier le statut du sinistre'
FROM public.fact_indemnisation
WHERE montant_indemnise = 0

ORDER BY nb_lignes DESC;

-- RESULTAT OBTENU :
-- 900 franchises nulles.
-- 757 emails manquants.
-- 500 dates de naissance manquantes.
-- 80 dates de declaration incoherentes.
-- 60 dossiers avec des coordonnees incompletes.
-- 15 montants estimes negatifs.
-- 5 indemnisations negatives.
-- 5 indemnisations nulles.

-- INTERPRETATION :
-- Les franchises nulles ne sont pas necessairement des erreurs.
-- Elles doivent etre verifiees selon les regles des contrats.
-- Les emails et dates de naissance manquants limitent
-- certaines analyses et utilisations des donnees.
-- Les dates incoherentes peuvent fausser les analyses
-- des delais de declaration.
-- Les coordonnees incompletes limitent les analyses geographiques.
-- Les montants negatifs ou nuls necessitent une verification
-- des regles de gestion et des operations comptables.

-- IMPACT METIER :
-- Les anomalies peuvent fausser certains indicateurs.
-- Elles peuvent limiter les analyses demographiques,
-- geographiques et financieres.
-- Elles peuvent egalement compliquer le suivi des dossiers.

-- DECISION PROPOSEE :
-- Verifier les franchises nulles selon les contrats.
-- Rechercher les donnees manquantes dans les sources fiables.
-- Controler les dates de declaration incoherentes.
-- Examiner les montants negatifs et nuls.
-- Ne pas modifier les donnees sans justification.
-- Documenter les anomalies confirmees et les limites du reporting.
--------------------------------------------------------------------------

-- Quel impact peut-elle avoir sur une analyse ou un indicateur ?


SELECT
    'Franchises nulles' AS anomalie,
    COUNT(*) AS nb_lignes,
    'Indicateurs de cout potentiellement fausses'
        AS impact_potentiel
FROM public.fact_sinistre
WHERE franchise = 0

UNION ALL

SELECT
    'Emails manquants',
    COUNT(*),
    'Analyses de communication limitees'
FROM public.dim_assure
WHERE email IS NULL
   OR TRIM(email) = ''

UNION ALL

SELECT
    'Dates de naissance manquantes',
    COUNT(*),
    'Analyses demographiques incompletes'
FROM public.dim_assure
WHERE date_naissance IS NULL

UNION ALL

SELECT
    'Dates de declaration incoherentes',
    COUNT(*),
    'Indicateurs de delai potentiellement fausses'
FROM public.fact_sinistre
WHERE date_declaration < date_survenance

UNION ALL

SELECT
    'Coordonnees incompletes',
    COUNT(*),
    'Analyses geographiques incompletes'
FROM public.fact_sinistre
WHERE latitude IS NULL
   OR longitude IS NULL

UNION ALL

SELECT
    'Montants estimes negatifs',
    COUNT(*),
    'Indicateurs financiers potentiellement fausses'
FROM public.fact_sinistre
WHERE montant_estime < 0

UNION ALL

SELECT
    'Indemnisations negatives',
    COUNT(*),
    'Calcul des remboursements a verifier'
FROM public.fact_indemnisation
WHERE montant_indemnise < 0

UNION ALL

SELECT
    'Indemnisations nulles',
    COUNT(*),
    'Statut des indemnisations a verifier'
FROM public.fact_indemnisation
WHERE montant_indemnise = 0

ORDER BY nb_lignes DESC;

-- RESULTAT OBTENU :
-- 900 franchises nulles.
-- 757 emails manquants.
-- 500 dates de naissance manquantes.
-- 80 dates de declaration incoherentes.
-- 60 coordonnees geographiques incompletes.
-- 15 montants estimes negatifs.
-- 5 indemnisations negatives.
-- 5 indemnisations nulles.

-- INTERPRETATION :
-- Les franchises nulles peuvent modifier les indicateurs
-- de cout si elles ne correspondent pas aux regles des contrats.
-- Les emails manquants limitent certaines analyses
-- de communication avec les assures.
-- Les dates de naissance manquantes limitent les analyses
-- demographiques.
-- Les dates incoherentes peuvent fausser les calculs
-- des delais de declaration.
-- Les coordonnees incompletes limitent les analyses geographiques.
-- Les montants negatifs et les indemnisations nulles
-- necessitent une verification des regles de gestion.

-- IMPACT METIER :
-- Les anomalies peuvent fausser certains indicateurs financiers.
-- Elles peuvent limiter les analyses demographiques
-- et geographiques.
-- Elles peuvent egalement compliquer le suivi des dossiers
-- et l'analyse des remboursements.

-- DECISION PROPOSEE :
-- Verifier les franchises nulles selon les contrats.
-- Rechercher les donnees manquantes dans les sources fiables.
-- Controler les dates incoherentes.
-- Examiner les montants negatifs et les indemnisations nulles.
-- Ne pas corriger les donnees sans justification.
-- Documenter les anomalies confirmees et les limites du reporting.
---------------------------------------------------------------------------------

-- Quelle décision proposez-vous : corriger, exclure, conserver ou investiguer davantage ?

SELECT
    'Franchises nulles' AS anomalie,
    900 AS nb_lignes,
    'Investiguer davantage' AS decision,
    'Verifier les regles des contrats' AS justification

UNION ALL

SELECT
    'Emails manquants',
    757,
    'Investiguer davantage',
    'Rechercher les emails dans les sources fiables'

UNION ALL

SELECT
    'Dates de naissance manquantes',
    500,
    'Investiguer davantage',
    'Verifier les sources disponibles'

UNION ALL

SELECT
    'Dates de declaration incoherentes',
    80,
    'Investiguer davantage',
    'Verifier les dates et les delais de declaration'

UNION ALL

SELECT
    'Coordonnees incompletes',
    60,
    'Investiguer davantage',
    'Verifier les informations geographiques'

UNION ALL

SELECT
    'Montants estimes negatifs',
    15,
    'Investiguer davantage',
    'Verifier les regles de calcul et les montants'

UNION ALL

SELECT
    'Indemnisations negatives',
    5,
    'Investiguer davantage',
    'Verifier les remboursements et les corrections'

UNION ALL

SELECT
    'Indemnisations nulles',
    5,
    'Investiguer davantage',
    'Verifier le statut des indemnisations'

ORDER BY nb_lignes DESC;

-- RESULTAT OBTENU :
-- 8 categories d'anomalies ont ete identifiees.
-- Chaque categorie dispose d'une decision proposee
-- et d'une justification.
-- Les decisions proposees sont toutes :
-- Investiguer davantage.

-- INTERPRETATION :
-- Les anomalies identifiees ne peuvent pas toutes etre
-- corrigees automatiquement.
-- Certaines valeurs manquantes necessitent une recherche
-- dans des sources fiables.
-- Les montants negatifs ou nuls doivent etre verifies
-- selon les regles de gestion.
-- Les franchises nulles ne sont pas necessairement
-- des erreurs.

-- IMPACT METIER :
-- Une correction injustifiee pourrait modifier
-- les indicateurs financiers et les analyses.
-- L'absence de verification peut maintenir des anomalies
-- dans les rapports.
-- Une investigation permet de fiabiliser les indicateurs
-- avant leur utilisation.

-- DECISION PROPOSEE :
-- Investiguer les anomalies avant toute correction.
-- Corriger uniquement les valeurs confirmees comme erronees.
-- Conserver les valeurs justifiees par les regles de gestion.
-- Exclure des analyses certaines donnees uniquement
-- si leur utilisation n'est pas pertinente ou fiable.
-- Documenter les decisions et conserver la tracabilite.
------------------------------------------------------------------------------



-- =====================================================
-- 3. Vérifier les relations entre les tables
-- =====================================================


-- 3.1: Chaque contrat reference-t-il un assure existant ?

SELECT
    COUNT(*) AS nb_contrats_total,
    COUNT(*) FILTER (
        WHERE a.assure_id IS NULL
    ) AS nb_contrats_sans_assure
FROM dim_contrat AS c
LEFT JOIN public.dim_assure AS a
    ON c.assure_id = a.assure_id;

-- RESULTAT OBTENU :
-- Nombre total de contrats : 32 000.
-- Contrats sans assure existant : 0.

-- INTERPRETATION :
-- Tous les contrats references correspondent
-- a un assure existant dans dim_assure.
-- Aucune reference invalide n'a ete detectee.

-- IMPACT METIER :
-- Les analyses reliant les contrats aux assures
-- peuvent s'appuyer sur cette relation.
-- Aucun contrat orphelin n'a ete identifie.

-- DECISION PROPOSEE :
-- Conserver cette relation.
-- Aucune correction n'est necessaire pour ce controle.
-- Maintenir ce controle lors des prochaines mises a jour.

----------------------------------------


-- 3.2: Chaque contrat reference-t-il une agence existante ?

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

-- 3.3 : Chaque sinistre reference-t-il un contrat existant ?

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

-- 3.5 : Chaque indemnisation reference-t-elle un sinistre existant ?

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


-- 3.6 : IMPACT DES RELATIONS INVALIDES

-- Quel serait l'impact d'une relation invalide sur une future analyse ?

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
-- 4. Produire des indicateurs de contrôle
-- =====================================================

-- 4.1: Combien de sinistres sont enregistres par annee ?

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

-- 4.2: Combien de sinistres sont enregistres par type ?

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
------------------------------------------------------------------

-- 4.3: Quel est le montant moyen estime par type de sinistre ?

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

-- 4.4: Combien de sinistres sont enregistres par region ?

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

-- 4.5: Combien de sinistres sont enregistres par statut ?

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

-- 4.6:  Quel est le montant total des indemnisations ?

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

-- 4.7: Quel est le montant moyen des indemnisations ?

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

-- 4.8: Combien de contrats existe-t-il par formule ?

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
-- 5. RGPD et minimisation
-- =====================================================

-- 5.1: Quelles donnees personnelles sont presentes dans dim_assure ?

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

-- 5.2: Quelles donnees sont reellement necessaires au futur reporting ?

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

-- 5.3: Quelles colonnes doivent etre conservees ?

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

-- 5.4: Quelles colonnes pourraient etre transformees ?

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

-- 5.5: Quelles colonnes ne devraient pas etre exposees dans le reporting ?

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
-- 6. Diagnostic final
-- =====================================================

-- 6.1:  Quelles sont les principales anomalies identifiees ?

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

-- 6.2: Quels risques les donnees manquantes peuvent-elles provoquer dans les analyses ?

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

-- 6.3: Quelles donnees peuvent etre utilisees pour le reporting ?

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

-- 6.4: Quels traitements recommandez-vous avant la mise en reporting ?

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

-- 6.5: Quels points necessitent encore une investigation ?

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
-- Projet : AssurRisk
-- Sujet : Qualité des données, risques et RGPD
-- =====================================================

-- 1. PRINCIPALES ANOMALIES IDENTIFIÉES
--
-- La base contient 7 tables principales.
-- Les cinq contrôles de relations réalisés
-- n'ont révélé aucune référence invalide.
--
-- La table dim_assure contient 25 040 assurés.
-- 500 dates de naissance sont manquantes.
-- 757 adresses email sont manquantes.
-- 24 185 emails distincts après normalisation.
-- Aucun email au format suspect selon notre contrôle.
--
-- Des doublons potentiels et des incohérences de dates
-- ont été détectés dans les données des sinistres.
-- Des montants négatifs et des libellés non standardisés
-- nécessitent également une vérification.
--
-- 2. RISQUES POUR LES ANALYSES
--
-- Les dates de naissance manquantes limitent
-- les analyses démographiques par âge.
-- Les emails manquants limitent certains usages
-- liés à la communication avec les assurés.
-- Les emails répétés peuvent fausser les analyses
-- du nombre de contacts uniques.
-- Les incohérences de dates peuvent fausser
-- les indicateurs de délais de déclaration.
-- Les anomalies de montants peuvent affecter
-- les indicateurs financiers et les remboursements.
-- Les libellés non standardisés peuvent fragmenter
-- les catégories dans les analyses.
--
-- 3. DONNÉES EXPLOITABLES
--
-- Les identifiants assure_id peuvent servir
-- au comptage des assurés.
-- Les relations entre les tables contrôlées
-- peuvent être utilisées pour les analyses.
-- Les données géographiques peuvent servir
-- aux analyses territoriales, avec des limites
-- pour les localisations manquantes.
-- Les indicateurs agrégés sont à privilégier
-- dans les tableaux de bord.
--
-- 4. TRAITEMENTS RECOMMANDÉS
--
-- Normaliser les emails avec LOWER et TRIM.
-- Vérifier les emails répétés entre plusieurs assurés.
-- Investiguer l'origine des dates manquantes.
-- Vérifier les doublons potentiels et les dates incohérentes.
-- Examiner les montants négatifs et les indemnisations nulles.
-- Standardiser les libellés après validation.
-- Ne pas inventer de valeurs de remplacement.
-- Ne corriger que les erreurs confirmées.
-- Limiter l'utilisation des noms, prénoms et emails.
-- Documenter les limites des indicateurs produits.
--
-- 5. POINTS NÉCESSITANT UNE INVESTIGATION
--
-- Comprendre pourquoi 500 dates de naissance manquent.
-- Déterminer si les 757 emails manquants sont acceptables
-- au regard des besoins métier.
-- Vérifier les emails partagés ou dupliqués.
-- Confirmer les doublons potentiels dans les sinistres.
-- Vérifier les incohérences de dates et les montants suspects.
-- Contrôler les règles de calcul des indemnisations.
-- Confirmer les règles de gestion avant la mise en reporting.
--
-- CONCLUSION
--
-- La base AssurRisk est exploitable pour plusieurs analyses,
-- sous réserve de vérifier les anomalies identifiées
-- et de documenter les limites des données.
--
-- Les indicateurs financiers, démographiques et géographiques
-- doivent être interprétés avec prudence.
--
-- Les corrections doivent être réalisées uniquement
-- après vérification des données sources et des règles métier.
--
-- La minimisation des données personnelles doit être
-- appliquée tout au long du processus de reporting.
--
-- =====================================================












