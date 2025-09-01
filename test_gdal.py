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