CREATE OR REPLACE VIEW `prod-organize-arizon-4e1c0a83.geofiles.az_precincts_geo AS(
	
	SELECT
		ST_GEOGFROMTEXT(WKT) AS GEOMETRY -- you must name it "GEOMETRY" for Looker to categorize it correctly as Geospatial data
		, COUNTY
		, PCTNUM --this is a field I have created with a python script so I can have an exact match by precinct since AZ precinct names are inconsistent accross VAN/Voterfiles
		, PRECINCTNA -- human readable precinct name
	
	FROM `prod-organize-arizon-4e1c0a83.geofiles.az_precincts`
)