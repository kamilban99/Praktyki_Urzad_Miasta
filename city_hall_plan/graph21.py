from qgis.core import QgsProject, QgsVectorLayer, QgsApplication, QgsWkbTypes
import networkx as nx
import os

# Initialize QGIS Application (non-GUI mode)
QgsApplication.setPrefixPath("C:/OSGeo4W64/apps/qgis", True)  # Update this path
qgs = QgsApplication([], False)
qgs.initQgis()

# Load the QGIS project
project = QgsProject.instance()
project_path = r"C:\Dane\Korekta-pietro1.qgz"  # Update with your QGZ file path
project.read(project_path)

# Create a graph
G = nx.Graph()

# Iterate over the layers in the project
for layer in project.mapLayers().values():
    if isinstance(layer, QgsVectorLayer):
        print(f"Layer name: {layer.name()}")

        # Get field names for potential attributes
        field_names = layer.fields().names()

        # Iterate over features (rooms, walls) in the layer
        for feature in layer.getFeatures():
            geom = feature.geometry()

            if geom is not None and not geom.isEmpty():
                geom_type = geom.wkbType()

                if geom_type == QgsWkbTypes.Polygon:
                    # For polygon geometry (e.g., rooms)
                    exterior_coords = geom.asPolygon()[0]
                    for i in range(len(exterior_coords) - 1):
                        node1 = tuple(exterior_coords[i])
                        node2 = tuple(exterior_coords[i + 1])
                        G.add_edge(node1, node2)
                
                elif geom_type == QgsWkbTypes.LineString:
                    # For line geometry (e.g., walls)
                    line_coords = geom.asPolyline()
                    for i in range(len(line_coords) - 1):
                        node1 = tuple(line_coords[i])
                        node2 = tuple(line_coords[i + 1])
                        G.add_edge(node1, node2)
                
                elif geom_type == QgsWkbTypes.MultiPolygon:
                    # For MultiPolygon geometry (if applicable)
                    for polygon in geom.asMultiPolygon():
                        exterior_coords = polygon[0]
                        for i in range(len(exterior_coords) - 1):
                            node1 = tuple(exterior_coords[i])
                            node2 = tuple(exterior_coords[i + 1])
                            G.add_edge(node1, node2)
                
                elif geom_type == QgsWkbTypes.MultiLineString:
                    # For MultiLineString geometry (if applicable)
                    for line in geom.asMultiPolyline():
                        for i in range(len(line) - 1):
                            node1 = tuple(line[i])
                            node2 = tuple(line[i + 1])
                            G.add_edge(node1, node2)

# Exit QGIS Application
qgs.exitQgis()
# Print basic information about the graph
print(f"Number of nodes: {G.number_of_nodes()}")
print(f"Number of edges: {G.number_of_edges()}")

# Visualize the graph (optional, requires matplotlib)
import matplotlib.pyplot as plt

pos = {node: node for node in G.nodes()}  # Use node coordinates as positions
nx.draw(G, pos, with_labels=False, node_size=10, edge_color='black')
plt.show()