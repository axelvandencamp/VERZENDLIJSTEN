---------------------------------------------------
-- SET VARIABLES
--
-- opladen upld file "S:\Ledenadministratie\Databeheer\Upld\nazendingen opvolging utf8.csv"
-- - aanmaak: _AV_temp_nazendingenopvolging
-- - manueel opladen data in _AV_temp_nazendingenopvolging
-- - NULL-values overschrijven met 0
-- opladen lijsten verwerking nieuwe leden
-- - totaal lijst van huidig jaar nemen; kolommen "lidnummer", "type_lid", "aanmaak_datum" behouden
-- - aanmaak: _AV_nieuwleden
--
-- INSERT nieuw gevonden lidnummers
-- UPDATE 1
-- UPDATE 2
---------------------------------------------------
--=================================================================
--SET VARIABLES: "vz_blad1", "vz_blad2", "npblad" invullen!!
DROP TABLE IF EXISTS _AV_myvar;
CREATE TEMP TABLE _AV_myvar 
	(startdatum DATE, einddatum DATE, vz_blad1 DATE, vz_blad2 DATE, publ_blad DATE, npblad integer);
INSERT INTO _AV_myvar VALUES('2020-01-01', '2021-12-31',	--start- en einddatum
				'2020-02-10', '2020-12-31',	-- datum verzending tijdschrift NPBlad1 en -NPBlad2
				'2020-03-16',			-- datum dat het blad ter beschikking was voor WPK
				1); 				-- NPblad1 of NPblad2
SELECT * FROM _AV_myvar;
--====================================================================
-- aanmaak: 
DROP TABLE IF EXISTS _AV_temp_nazendingenopvolging;
CREATE TABLE _AV_temp_nazendingenopvolging 
	(lidnummer text, npblad1 integer, npblad2 integer, toevoeging date);
-- MANUEEL OPLADEN: "S:\Ledenadministratie\Databeheer\Upld\nazendingen opvolging utf8.csv"
SELECT * FROM _AV_temp_nazendingenopvolging;
-- NULL values op "0" zetten
UPDATE _AV_temp_nazendingenopvolging SET npblad1 = 0 WHERE COALESCE(_AV_temp_nazendingenopvolging.npblad1,0) = 0;
UPDATE _AV_temp_nazendingenopvolging SET npblad2 = 0 WHERE COALESCE(_AV_temp_nazendingenopvolging.npblad2,0) = 0;
--====================================================================
-- aanmaak _AV_temp_nieuweleden
--====================================================================
-- aanmaak: 
DROP TABLE IF EXISTS _AV_temp_nieuweleden;
CREATE TABLE _AV_temp_nieuweleden 
	(lidnummer text, type_lid text, aanmaak_datum text);
-- MANUEEL OPLADEN: lokaal klaarzetten is OK (Ledenadministratie)
SELECT lidnummer, type_lid, to_date(aanmaak_datum,'dd/mm/yyyy') FROM _AV_temp_nieuweleden;
--====================================================================
-- INSERT _AV_temp_nieuweleden
-- - lidnummer voor npblad
--====================================================================
INSERT INTO _AV_temp_nazendingenopvolging
	(
	SELECT	DISTINCT p.membership_nbr lidnummer,
		1 npblad1,
		CASE WHEN v.npblad = 1 THEN 0
			 WHEN v.npblad = 2 THEN 1 END npblad2,
		now()::date toevoeging
	FROM 	_av_myvar v, res_partner p
		JOIN _AV_temp_nieuweleden tn ON tn.lidnummer = p.membership_nbr
	WHERE 	p.active = 't' AND COALESCE(p.deceased,'f') = 'f' AND p.membership_state IN ('paid','invoiced','free')
		AND to_date(tn.aanmaak_datum,'dd/mm/yyyy') < v.publ_blad
		AND NOT(p.membership_nbr IN (SELECT lidnummer FROM _AV_temp_nazendingenopvolging tnop) )
	);
--====================================================================
-- INSERT _AV_temp_nieuweleden
-- - lidnummer na npblad
--====================================================================
INSERT INTO _AV_temp_nazendingenopvolging
	(
	SELECT	DISTINCT p.membership_nbr lidnummer,
		1 npblad1,
		CASE WHEN v.npblad = 1 THEN 0
			 WHEN v.npblad = 2 THEN 1 END npblad2,
		now()::date -1 toevoeging
	FROM 	_av_myvar v, res_partner p
		JOIN _AV_temp_nieuweleden tn ON tn.lidnummer = p.membership_nbr
	WHERE 	p.active = 't' AND COALESCE(p.deceased,'f') = 'f' AND p.membership_state IN ('paid','invoiced','free')
		AND to_date(tn.aanmaak_datum,'dd/mm/yyyy') >= v.publ_blad
		AND NOT(p.membership_nbr IN (SELECT lidnummer FROM _AV_temp_nazendingenopvolging tnop) )
	);
--====================================================================
-- INSERT recente leden huidige toestand
--====================================================================
INSERT INTO _AV_temp_nazendingenopvolging
	(
	SELECT	DISTINCT p.membership_nbr lidnummer,
		CASE WHEN v.npblad = 1 THEN 1 END npblad1,
		CASE WHEN v.npblad = 1 THEN 0
			 WHEN v.npblad = 2 THEN 1 END npblad2,
		now()::date toevoeging
	FROM 	_av_myvar v, res_partner p
	WHERE 	p.active = 't' AND COALESCE(p.deceased,'f') = 'f' AND p.membership_state IN ('paid','invoiced','free')
		AND NOT(p.membership_nbr IN (SELECT lidnummer FROM _AV_temp_nazendingenopvolging) )
	);
--====================================================================
-- UPDATE 1: van recente lijst huidige toestand
--====================================================================
UPDATE _AV_temp_nazendingenopvolging
SET npblad1 = 1, npblad2 = 0, toevoeging = now()::date
FROM _av_myvar v
WHERE v.npblad = 1 AND _AV_temp_nazendingenopvolging.npblad1 = 0 
	AND _AV_temp_nazendingenopvolging.lidnummer IN (SELECT p.membership_nbr FROM	res_partner p
							WHERE p.active = 't' AND COALESCE(p.deceased,'f') = 'f'
							  AND p.membership_state IN ('paid','invoiced','free'));


		
--=============================================================================
