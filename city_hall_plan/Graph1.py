import networkx as nx
import matplotlib.pyplot as plt

import json
import xml.etree.ElementTree as ET
from pyvis.network import Network
G = nx.Graph()


def add_room(graph, number, fire_zone, type='Office', accessible=True):
    """
    Adds a room (node) to the graph with specified attributes.

    Parameters:
    - graph: The NetworkX graph object.
    - number: The room number (used to generate the name).
    - fire_zone: The fire zone of the room.
    - type: Type of the room (e.g., Office, Conference).
    - accessible: Whether the room is accessible or not.
    """
    #Automatically generate the name using the number and fire zone
    #name = int(f"{number}{ord(fire_zone.upper()) - ord('A') + 1}")
    name = (f"{number}{fire_zone}")
    #Add the node to the graph
    graph.add_node(name)
    
    # Add parameters to the node
    graph.nodes[name]["number"] = number
    graph.nodes[name]["fire_zone"] = fire_zone
    if type is not None:
        graph.nodes[name]["type"] = type
    if accessible is not None:
        graph.nodes[name]["accessible"] = accessible

def add_corridor(graph, number, fire_zone,type = 'Corridor', accessible = True):
    #name = int(f"{number}{ord(fire_zone.upper()) - ord('A') + 1}")
    name = (f"{number}{fire_zone}")
     # Add the node to the graph
    graph.add_node(name)
    
    # Add parameters to the node
    graph.nodes[name]["number"] = number
    graph.nodes[name]["fire_zone"] = fire_zone
    if type is not None:
        graph.nodes[name]["type"] = type
    if accessible is not None:
        graph.nodes[name]["accessible"] = accessible

def add_edge(graph, node1, node2, edge_type="Door", accessible=True):
    """
    Adds an edge between two nodes in the graph with specified attributes.

    Parameters:
    - graph: The NetworkX graph object.
    - node1: The name of the first node.
    - node2: The name of the second node.
    - edge_type: Type of the edge (e.g., Corridor, Staircase).
    - accessible: Whether the edge is accessible or not.
    """
    # Add the edge to the graph
    graph.add_edge(node1, node2)
    
    # Add parameters to the edge
    if edge_type is not None:
        graph.edges[node1, node2]["type"] = edge_type
    if accessible is not None:
        graph.edges[node1, node2]["accessible"] = accessible

def room_name(number, fire_zone):
    return (f"{number}{fire_zone}") #int(f"{number}{ord(fire_zone.upper()) - ord('A') + 1}")

def corridor_name(number, fire_zone):
    return (f"{number}{fire_zone}") #int(f"{number}{ord(fire_zone.upper()) - ord('A') + 1}")


G = nx.Graph()

for i in range(101,115):
    add_room(G, i, "E")

add_corridor(G, 1, "E")
add_corridor(G, 2, "E")

for i in range(101,108):
    add_edge(G,room_name(i,'E'), corridor_name(1, 'E'))

add_edge(G,room_name(110,'E'), corridor_name(2,'E'))

add_edge(G,corridor_name(1,'E'), corridor_name(2,'E'))

add_edge(G,room_name(109,'E'), room_name(110,'E'))
add_edge(G,room_name(110,'E'), room_name(111,'E'))
add_edge(G,room_name(110,'E'), room_name(112,'E'))
add_edge(G,room_name(110,'E'), room_name(113,'E'))
add_edge(G,room_name(110,'E'), room_name(114,'E'))
add_edge(G,room_name(108,'E'), room_name(109,'E'))

pos = nx.spring_layout(G)  # Position nodes using spring layout
nx.draw(G, pos, with_labels=True, node_color='lightblue', edge_color='gray', node_size=2000, font_size=10, font_weight='bold')

# Draw labels with attributes
node_labels = nx.get_node_attributes(G, 'type')
edge_labels = nx.get_edge_attributes(G, 'type')
#nx.draw_networkx_labels(G, pos, labels=node_labels, font_size=8, verticalalignment='center')
#nx.draw_networkx_edge_labels(G, pos, edge_labels=edge_labels, font_size=8)

plt.title('Graph Visualization')
plt.show()

def graph_to_json(graph):
    # Extract nodes and edges
    nodes = []
    edges = []

    for node, data in graph.nodes(data=True):
        node_info = {"id": node}
        node_info.update(data)
        nodes.append(node_info)

    for u, v, data in graph.edges(data=True):
        edge_info = {"source": u, "target": v}
        edge_info.update(data)
        edges.append(edge_info)

    # Create the JSON representation
    graph_json = {
        "nodes": nodes,
        "edges": edges
    }
    return json.dumps(graph_json, indent=2)

def save_graph_to_json_file(graph, file_path):
    graph_json = graph_to_json(graph)
    with open(file_path, 'w') as file:
        file.write(graph_json)

# Save to file
save_graph_to_json_file(G, 'graph.json')

nx.write_graphml(G, "graph.graphml")

net = Network(notebook = False)
net.from_nx(G)

node_types = {
    'Office': 'lightblue',
    'Corridor': 'lightgray'
}

for node in net.nodes: 
    node_type = node['type']
    node_color = node_types.get(node_type, 'lightblue')  # Default to lightblue if type is not found
    node['color'] = node_color
    node['label'] = str(node['label'])

#net.show_buttons()
net.show('graph.html', notebook=False)