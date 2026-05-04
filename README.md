

I use GDAL to get shapefiles into BigQuery in WKT format so I can make maps in Looker Studio. Here is what you'll need to do to get going.

### Step 1
We're going to use [GDAL](https://gdal.org/en/stable/) which is a translator library for geospatial data formats. This will allow us to start with basically any type of geospatial file format, but I'll use shapefiles in this demo. 

We need to create a virtual environment to isolate dependencies.

```zsh
python3 -m venv .venv
```

Then we'll activate the virtual environment with the following command:
```zsh
source .venv/bin/activate
```

We will see the name of our virtual environment in our terminal when this is successfully activated like so:
```zsh
(.venv) cmarikos@MacBookAir geo-precincts %
```

Next, install the library:
```zsh
pip install GDAL
```

### Step 2
Ensure GDAL is installed correctly in your virtual environment:
```zsh
pip install gdal
```

### Step 3
Make sure GDAL is installed correctly by running this verification script:

```python
# print the following error if GDAL is not installed correctly
try:
    from osgeo import gdal
except ImportError:
    print("Error: GDAL library is not installed or not found in your PYTHONPATH.")
    exit(1)

# Print the GDAL version information
print("GDAL Version:", gdal.VersionInfo())

# List available GDAL drivers
driver_count = gdal.GetDriverCount()
print("Number of GDAL Drivers installed:", driver_count)
for i in range(driver_count):
    driver = gdal.GetDriver(i)
    print(f"{i}: {driver.ShortName} - {driver.LongName}")
```

### Step 4
Now that our virtual environment is setup and we have GDAL installed correctly, we can convert a shapefile. Add a shapefile to your project folder.

I'm adding a file called `2024 AZ Voting Precincts v2.shp` (I have added the .cpg, .dbf, .prj, .qmd, .shp, and .shx files).

Now that we have our files in the correct folder we can employ the GDAL shapefile conversion function to create a WKT field in a CSV.

Now in your terminal run the following:
```zsh
ogr2ogr -f "CSV" az_precincts.csv "2024 AZ Voting Precincts v2.shp" -lco GEOMETRY=AS_WKT
```

This will create a CSV file called `az_precincts.csv` that contains a column called **WKT** with geospatial data that we can upload to BigQuery.

### Step 5
Now that we have our `az_precincts.csv` we need to upload them to BigQuery. Review how to upload CSV files to BigQuery [in this guide](https://cloud.google.com/bigquery/docs/loading-data-cloud-storage-csv).

Now that our file is loaded to BigQuery we have to recategorize your WKT data type as Geospatial data. I do this by creating a view with the `ST_GEOGFROMTEXT()` function applied to my WKT column.

##### Important note
Your column containing Geospatial data must be named **"GEOMETRY"** for Looker to accept it as Geospatial data.

Here is a code sample of my view:
```SQL
CREATE OR REPLACE VIEW `prod-organize-arizon-4e1c0a83.geofiles.az_precincts_geo` AS (
    
    SELECT
        ST_GEOGFROMTEXT(WKT) AS GEOMETRY -- you must name it "GEOMETRY" for Looker to categorize it correctly
        , COUNTY
        , PCTNUM -- field created with python for exact precinct matching
        , PRECINCTNA -- human readable precinct name
    
    FROM `prod-organize-arizon-4e1c0a83.geofiles.az_precincts`
)
```

##### Note on the geospatial data type in BigQuery
Looker doesn't join map data well so we have to join columns we want within BigQuery. Our GEOMETRY column data type can't be grouped. In order to create map features that utilize aggregation, you'll need to create a CTE then join to the table creating geometry.

```SQL
CREATE OR REPLACE VIEW `prod-organize-arizon-4e1c0a83.rich_christina_proj.sr_by_pctnum_c4_2024` AS (

    WITH a AS (
        SELECT
            mc.pctnum
            , sq.SurveyQuestionName
            , sr.SurveyResponseName
            , COUNT(DISTINCT cs.VanID) as response_count
        
        FROM `prod-organize-arizon-4e1c0a83.ngpvan.CTARAA_ContactsSurveyResponses_VF` AS cs
        LEFT JOIN `prod-organize-arizon-4e1c0a83.ngpvan.CTARAA_SurveyQuestions` AS sq
            ON cs.SurveyQuestionID = sq.SurveyQuestionID
        LEFT JOIN `prod-organize-arizon-4e1c0a83.ngpvan.CTARAA_SurveyResponses` AS sr
            ON cs.SurveyResponseID = sr.SurveyResponseID
        FULL OUTER JOIN `prod-organize-arizon-4e1c0a83.rich_christina_proj.modified_c4_precincts_2024` as mc
            ON cs.VanID = mc.VanID
        
        WHERE sq.Cycle ='2024'
            AND mc.countyname IN ('COCONINO','COCHISE','MOHAVE','PINAL','PIMA','YAVAPAI','YUMA')
        
        GROUP BY 1,2,3
    )
    
    SELECT
        pg.GEOMETRY
        , pg.COUNTY
        , pg.PRECINCTNA
        , pg.LEGISLATIV
        , pg.CONGRESSIO
        , a.SurveyQuestionName
        , a.SurveyResponseName
        , a.response_count
    
    FROM `prod-organize-arizon-4e1c0a83.geofiles.az_precincts_geo` AS pg
    LEFT JOIN a
        ON pg.PCTNUM = a.pctnum  
    WHERE a.response_count IS NOT NULL
)
```