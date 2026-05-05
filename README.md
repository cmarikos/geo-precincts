I use GDAL to get shapefiles into BigQuery in WKT format so I can make maps in Looker Studio. The uses for this library are as broad as your imagination. Here is what you'll need to do to get going.

### Step 1: Create a Virtual Environment
We use a virtual environment to isolate Python dependencies. Run these commands in your project root:

```zsh
python3 -m venv .venv
source .venv/bin/activate
```

Once activated, your terminal prompt will be prefixed with `(.venv)`.

### Step 2: Install GDAL
To use GDAL on a Mac, you need two things: the system binaries (for the command line tools) and the Python bindings (for your scripts).

**1. Install the System Binaries (The "Engine"):**
```zsh
brew install gdal
```

**2. Install the Python Bindings (The "Steering Wheel"):**
```zsh
pip install GDAL
```

### Step 3: Verify Installation
Run this script to ensure the library is linked correctly and `ogr2ogr` is available:

```zsh
# Verify command line tools
ogr2ogr --version

# Verify Python bindings
python3 -c "from osgeo import gdal; print('GDAL Version:', gdal.VersionInfo())"
```

### Step 4: Convert Shapefile to CSV (WKT)
Add your TIGER/Line shapefile components (`tl_2025_us_state.shp`, `.shx`, `.dbf`, etc.) to your project folder. We will use `ogr2ogr` to convert the spatial data into a CSV containing a **Well-Known Text (WKT)** column.

In your terminal, run the following:
```zsh
ogr2ogr -f "CSV" us_states.csv "tl_2025_us_state.shp" -lco GEOMETRY=AS_WKT
```

This creates `us_states.csv` with a column called **WKT** containing the geospatial boundaries for US States.

### Step 5: BigQuery Upload & Geometry Conversion
Upload your `us_states.csv` to BigQuery. This is basically only useable as a workflow from BigQuery to Data Studio. Once loaded, you must convert the WKT string into a GEOGRAPHY type using a view.

##### Important note
Your column containing Geospatial data must be named **"GEOMETRY"** for Looker Studio to accept it as Geospatial data.

```SQL
CREATE OR REPLACE VIEW `your-project.your_dataset.us_states_geo` AS (
    SELECT
        ST_GEOGFROMTEXT(WKT) AS GEOMETRY -- Must be named "GEOMETRY"
        , STATEFP   -- State FIPS code
        , STUSPS    -- State Abbreviation (e.g., AZ, CA)
        , NAME      -- State Name
        , ALAND     -- Land Area
    FROM `your-project.your_dataset.us_states_raw`
)
```

### Note on Geospatial Data in BigQuery
Looker Studio doesn't handle spatial joins well, so you should perform aggregations in BigQuery using a CTE before joining to your geometry.

```SQL
CREATE OR REPLACE VIEW `your-project.your_dataset.state_metrics_map` AS (
    WITH state_data AS (
        SELECT
            state_code
            , COUNT(*) as total_records
            , AVG(some_value) as average_metric
        FROM `your-project.your_dataset.your_data_table`
        GROUP BY 1
    )
    
    SELECT
        sg.GEOMETRY
        , sg.NAME
        , sd.total_records
        , sd.average_metric
    FROM `your-project.your_dataset.us_states_geo` AS sg
    LEFT JOIN state_data AS sd
        ON sg.STUSPS = sd.state_code  
    WHERE sd.total_records IS NOT NULL
)
```
