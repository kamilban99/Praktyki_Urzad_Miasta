from qgis.core import QgsProject, QgsVectorLayer, QgsApplication, QgsFeature
import os

# & "C:\Program Files\QGIS 3.32.0\apps\Python39\python.exe" c:/Users/praktyka1/Desktop/praktyki_2024/city_hall_plan/graph2.py

# Initialize QGIS Application (non-GUI mode)
QgsApplication.setPrefixPath("C:/OSGeo4W64/apps/qgis", True)  # Update the path based on your installation
qgs = QgsApplication([], False)
qgs.initQgis()

# Load the QGIS project
project = QgsProject.instance()
project_path = r"C:\Dane\Korekta-pietro1.qgz"  # Use a raw string to handle backslashes
project.read(project_path)

# Iterate over the layers in the project
for layer in project.mapLayers().values():
    if isinstance(layer, QgsVectorLayer):  # Check if it's a vector layer
        print(f"Layer name: {layer.name()}")
        print(f"Layer CRS: {layer.crs().authid()}")

        # Get field names
        field_names = layer.fields().names()
        print(f"Field names: {field_names}")

        # Iterate over features (rooms) in the layer
        for feature in layer.getFeatures():
            geom = feature.geometry()
            attrs = feature.attributes()

            # Print attributes with names
            for field_name, attr_value in zip(field_names, attrs):
                print(f"{field_name}: {attr_value}")

            

            print("----")

# Exit QGIS Application
qgs.exitQgis()