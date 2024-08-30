import numpy as np
import pandas as pd
import json
import matplotlib.pyplot as plt
from collections import defaultdict
from shapely.geometry import LineString, Polygon, Point, mapping
from shapely.affinity import translate
import time
array = defaultdict(lambda: defaultdict(set))
doors = defaultdict(lambda: defaultdict(list))

#TODO LIST:
#TODO algorytm w Excelu, który ułatwia kreowanie pięter
#TODO 

#argumenty wstępne
global_eps = 0.125 # najlepiej ułamek postaci 1 / (2^k), przesuwa elementy na piętrze o epsilon
double_csv = 0 #czy podwajamy elementy w wejściowym pliku csv
files = ['f2.csv','f3.csv'] # pliki do przetworzenia, powinny być tego samego wymiaru

def load_and_process_csv(file_paths):
    """Load multiple CSV files representing different floors."""
    floors = []
    for file_path in file_paths:
        df = pd.read_csv(file_path, delimiter=';', header=None)
        df = df.fillna('0')
        df = df.astype(str)
        floor_prefix = file_path[:2]
        df = df.applymap(lambda x: floor_prefix + x if x != '0' else x)
        np_array = np.array(df.values.tolist())
        if (double_csv): np_array = np.repeat(np.repeat(np_array, 2, axis=0), 2, axis=1)  # Upscale for finer grid
        floors.append((floor_prefix, np_array))
    return floors

def prefix(s):
    """dla drzwi otrzymuje tylko pokój"""
    if('-' in s):
        return s[:s.index("-")]
    if('!' in s):
        return s[:s.index("!")]
    return s

def shorten_line(line, reduction_factor=0.2):
    """Shorten the line by a given factor."""

    # Calculate new points that are closer to the midpoint
    new_start = line.interpolate(reduction_factor, normalized=True)
    new_end = line.interpolate(1 - reduction_factor, normalized=True)

    return LineString([new_start, new_end])

def get_neighbors(x, y, max_x, max_y):
    """Get the neighboring coordinates (up, down, left, right) while checking bounds."""
    neighbors = []
    if x > 0:
        neighbors.append((x-1, y))
    if x < max_x - 1:
        neighbors.append((x+1, y))
    if y > 0:
        neighbors.append((x, y-1))
    if y < max_y - 1:
        neighbors.append((x, y+1))
    return neighbors

def create_graph(floors):
    """Tworzy cały graf połączeń między pokojami, korytarzami i schodami"""
    #TODO połączyć schody
    graph = {}
    for i, floor in enumerate(floors,1):
        floor_prefix, array = floor
        x_max, y_max = array.shape
        eps = i*global_eps
        for x in range(x_max):
            for y in range(y_max):
                sign = array[x,y]
                if(sign != '0'):
                    graph[(x+eps, y+eps)] = []

        for x in range(x_max):
            for y in range(y_max):
                sign = array[x, y]
                if('!' in sign): #przypadek schody
                    if (sign[-2:] > floor_prefix):
                        graph[(x+eps,y+eps)].append((x+eps+global_eps, y+eps+global_eps))
                    else:
                        graph[(x+eps,y+eps)].append((x+eps-global_eps, y+eps-global_eps))
                if sign != '0':
                    neighbors = get_neighbors(x, y, x_max, y_max)
                    for nx, ny in neighbors:
                        neighbor_sign = array[nx, ny]
                        if '-' in sign and '-' in neighbor_sign and sign != neighbor_sign or prefix(sign) == prefix(neighbor_sign):
                            graph[(x+eps, y+eps)].append((nx+eps, ny+eps))

    return graph

def trace_polygon(i,component):
    """Trace the polygon for a given component by visiting unvisited vertices"""
    directions = [(-1, 0), (0, 1), (1, 0), (0, -1)]  # Right, Down, Left, Up (clockwise)
    polygon = []
    vertices = set(array[component].keys())
    eps = i*global_eps
    start = min(vertices)
    current = start
    visited = set([start])
    polygon.append(start)
    last_directions = (0,0)
    while True:
        x, y = current
        found_next = False
        for dx, dy in directions:
            nx, ny = x + dx, y + dy
            next_vertex = (nx, ny)
            if next_vertex in array[component][current] and next_vertex not in visited:
                visited.add(next_vertex)
                if(last_directions != (dx,dy) and last_directions != (0,0)):
                    polygon.append(current)
                found_next = True
                last_directions = (dx,dy)
                current = next_vertex
        if(current == start):
            break
        if not found_next:
            visited.discard(start)

    polygon.append(start)  # Close the polygon
    return polygon

def compute_centroid(polygon):
    """Compute the centroid of a polygon."""
    centroid = polygon.centroid
    return (centroid.x, centroid.y)

def plot(polygons,floor_labels, floor_num, doors, graph, grid_shape):
    """Plot the detected polygons and doors."""
    plt.figure(figsize=(8, 8))

    color_mapping = {
        'e': 'blue',
        'k': 'green',
        's': 'orange',
        # Add more mappings as needed
    }
    epsilon = -0.08 #helps with some space between rooms
    door_buffer = 0.02
    shorten_factor = 0.1  # Amount to shorten the door segments

    iter = 0
    fig, axs = plt.subplots(len(floor_num))
    for floor, eps in floor_num:
        for polygon_data in ( (floor_prefix,name,polygon) for floor_prefix, name, polygon in polygons if floor_prefix[:2] == floor):
            floor_prefix, name, polygon = polygon_data

            shapely_polygon = Polygon(polygon)
            buffered_polygon = shapely_polygon.buffer(epsilon)

            xs, ys = zip(*list(buffered_polygon.exterior.coords))

            pref = name[2]
            color = color_mapping.get(pref, 'gray')
            axs[iter].plot(ys, xs, linestyle='-', linewidth=2, color = color)
            centroid_x, centroid_y = compute_centroid(buffered_polygon)
            axs[iter].text(centroid_y, centroid_x, name[2:], fontsize=14, ha='center', va='center', color='black')

        for key1, inner_dict in doors.items():
            for key2, pairs in inner_dict.items():
                x,y = pairs [0]
                if x - eps == np.floor(x):
                # Create a line representing the door
                    door_line = LineString(pairs)
                    # Shorten the door
                    shortened_door = shorten_line(door_line, shorten_factor)
                    # Buffer the shortened door to create a small polygon (rectangle)
                    buffered_door = shortened_door.buffer(door_buffer, cap_style=2)
                    # Extract the exterior coordinates of the buffered door
                    door_xs, door_ys = zip(*list(buffered_door.exterior.coords))
                    # Plot the buffered door
                    axs[iter].plot(door_ys, door_xs, linestyle='-', linewidth=4, color='brown')

        for (x, y), neighbors in graph.items():
            if x - eps == np.floor(x):
                for nx, ny in neighbors:
                    if(nx - x == global_eps or ny - y == global_eps): #schody do góry
                        axs[iter].plot([y+0.5, ny+0.5], [x+0.5, nx+0.5], color='green')
                    elif x - nx == global_eps or y - ny == global_eps:
                        axs[iter].plot([y+0.5, ny+0.5], [x+0.5, nx+0.5], color='red')
                    else:
                        axs[iter].plot([y+0.5, ny+0.5], [x+0.5, nx+0.5], color='black')  # Draw the connections

        axs[iter].set_xlim(-0.5, grid_shape[1] + 0.5)
        axs[iter].set_ylim(grid_shape[0] + 0.5, -0.5)  # Set y-axis from top to bottom
        axs[iter].set_title(f"{floor}")
        axs[iter].set_aspect('equal', adjustable='box')
        iter += 1
    plt.show()



floors = load_and_process_csv(files)
floor_labels = set()
floor_num = set()
polygons = []
# Step 2: Prepare the vertices array
for i,floor in enumerate(floors,1):
    floor_pref, csv_data = floor
    eps = i*global_eps
    floor_num.add((floor_pref[:2],eps))
    rows, cols = csv_data.shape
    for x in range(rows):
        for y in range(cols):
            sign = prefix(csv_data[x,y])
            if sign != '0':
                if(x == 0 or prefix(csv_data[x-1,y]) != sign):
                    array[sign][(x+eps,y+eps)].add((x+eps,y+1+eps))
                    array[sign][(x+eps,y+eps+1)].add((x+eps,y+eps))
                if(x == rows - 1 or prefix(csv_data[x+1,y]) != sign):
                    array[sign][(x+1+eps,y+eps)].add((x+1+eps,y+1+eps))
                    array[sign][(x+1+eps,y+1+eps)].add((x+1+eps,y+eps))
                if(y == 0 or prefix(csv_data[x,y-1]) != sign):
                    array[sign][(x+eps,y+eps)].add((x+1+eps,y+eps))
                    array[sign][(x+1+eps,y+eps)].add((x+eps,y+eps))
                if(y == cols - 1 or prefix(csv_data[x,y+1]) != sign):
                    array[sign][(x+eps,y+1+eps)].add((x+1+eps,y+1+eps))
                    array[sign][(x+1+eps,y+1+eps)].add((x+eps,y+1+eps))
                #check for doors
                if('-' in csv_data[x,y]):
                    if(x > 0 and '-' in csv_data[x-1,y] and csv_data[x,y] != csv_data[x-1,y]):
                        doors[sign][prefix(csv_data[x-1,y])].extend([(x+eps,y+eps), (x+eps,y+1+eps)])
                    if(x < rows - 1 and '-' in csv_data[x+1,y] and csv_data[x,y] != csv_data[x+1,y]):
                        doors[sign][prefix(csv_data[x+1,y])].extend([(x+1+eps,y+eps), (x+1+eps,y+1+eps)])
                    if(y > 0 and '-' in csv_data[x,y-1]and csv_data[x,y] != csv_data[x,y-1]):
                        doors[sign][prefix(csv_data[x,y-1])].extend([(x+eps,y+eps), (x+1+eps,y+eps)])
                    if(y < cols - 1 and '-' in csv_data[x,y+1] and csv_data[x,y] != csv_data[x,y+1]):
                        doors[sign][prefix(csv_data[x,y+1])].extend([(x+eps,y+1+eps), (x+1+eps,y+1+eps)])
    # Step 3: Trace polygons from the connected components
    for component in array:
        if(component not in floor_labels):
            floor_labels.add(component)
            polygon = trace_polygon(i,component)
            if polygon:
                polygons.append((floor_pref, component, polygon))
            # print(floor_pref, component,polygon)

# Output the results
for i, polygon in enumerate(polygons, 1):
    print(f"Polygon {i}: {polygon}")

graph = create_graph(floors)

def create_combined_geojson(polygons, graph, doors):
    features = []

    # Add polygon features
    for floor_prefix, name, polygon in polygons:
        shapely_polygon = Polygon(polygon)
        feature = {
            "type": "Feature",
            "geometry": mapping(shapely_polygon),
            "properties": {
                "type": "room",
                "name": name,
                "floor": floor_prefix
            }
        }
        features.append(feature)
    
    # Add graph (line) features
    for (x, y), neighbors in graph.items():
        for nx, ny in neighbors:
            linestring = LineString([(y, x), (ny, nx)])
            feature = {
                "type": "Feature",
                "geometry": mapping(linestring),
                "properties": {
                    "type": "connection",
                    "connection": f"({x}, {y}) -> ({nx}, {ny})"
                }
            }
            features.append(feature)
    
    # Add door features
    for room_from, inner_dict in doors.items():
        for room_to, points in inner_dict.items():
            linestring = LineString(points)
            feature = {
                "type": "Feature",
                "geometry": mapping(linestring),
                "available": True,
                "properties": {
                    "type": "door",
                    "from": room_from,
                    "to": room_to
                }
            }
            features.append(feature)

    # Create the combined GeoJSON FeatureCollection
    geojson = {
        "type": "FeatureCollection",
        "features": features
    }

    return geojson

# Create the combined GeoJSON
combined_geojson = create_combined_geojson(polygons, graph, doors)

# Save to a file
with open("combined.geojson", "w") as f:
    json.dump(combined_geojson, f, indent=2)


# Step 4: Visualize the polygons
plot(polygons, floor_labels, floor_num, doors, graph, csv_data.shape)


