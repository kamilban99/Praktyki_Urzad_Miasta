import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from collections import defaultdict
from shapely.geometry import LineString, Polygon, Point
from shapely.affinity import translate
import time
array = defaultdict(lambda: defaultdict(set))
doors = defaultdict(lambda: defaultdict(list))

def load_and_process_csv(file_path):
    # Load CSV file into a DataFrame
    df = pd.read_csv(file_path, delimiter=';', header=None)
    
    # Replace NaN values (from empty cells) with '0'
    df = df.fillna('0')
    
    # Convert DataFrame to 2D array (list of lists)
    array = df.values.tolist()
    
    # Convert list of lists to NumPy array (optional)
    np_array = np.array(array)
    
    return np_array

def prefix(s):
    if('-' in s):
        return s[:s.index("-")]
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

def create_graph(array):
    graph = {}
    x_max, y_max = array.shape

    for x in range(x_max):
        for y in range(y_max):
            sign = array[x,y]
            if(sign != '0'):
                graph[(x,y)] = []

    for x in range(x_max):
        for y in range(y_max):
            sign = array[x, y]
            if sign != '0':
                neighbors = get_neighbors(x, y, x_max, y_max)
                for nx, ny in neighbors:
                    neighbor_sign = array[nx, ny]
                    if '-' in sign and '-' in neighbor_sign and sign != neighbor_sign or prefix(sign) == prefix(neighbor_sign):
                        graph[(x, y)].append((nx, ny))
    return graph

files = ['f2test.csv', 'f3test.csv']
# Example usage
file_path = 'f3test.csv'
csv_data = load_and_process_csv(file_path)
csv_data = np.repeat(np.repeat(csv_data, 2, axis=0), 2, axis=1)

def trace_polygon(component):
    """Trace the polygon for a given component by visiting unvisited vertices with odd counts."""
    directions = [(-1, 0), (0, 1), (1, 0), (0, -1)]  # Right, Down, Left, Up (clockwise)
    polygon = []
    vertices = set(array[component].keys())
    #print(component)
    #print("component:", array[component])
    #print("vertices:", vertices)
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

def plot(polygons, doors, graph, grid_shape):
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
    for polygon_data in polygons:
        
        name, polygon = polygon_data
        
        shapely_polygon = Polygon(polygon)
        buffered_polygon = shapely_polygon.buffer(epsilon)
        #print(shapely_polygon)
        #print(buffered_polygon)
        xs, ys = zip(*list(buffered_polygon.exterior.coords))

        pref = name[0]
        color = color_mapping.get(pref, 'gray')
        plt.plot(ys, xs, linestyle='-', linewidth=2, color = color)
        centroid_x, centroid_y = compute_centroid(buffered_polygon)
        plt.text(centroid_y, centroid_x, name, fontsize=14, ha='center', va='center', color='black')

    for key1, inner_dict in doors.items():
        for key2, pairs in inner_dict.items():
            # Create a line representing the door
            door_line = LineString(pairs)
            # Shorten the door
            shortened_door = shorten_line(door_line, shorten_factor)
            # Buffer the shortened door to create a small polygon (rectangle)
            buffered_door = shortened_door.buffer(door_buffer, cap_style=2)
            # Extract the exterior coordinates of the buffered door
            door_xs, door_ys = zip(*list(buffered_door.exterior.coords))
            # Plot the buffered door
            plt.plot(door_ys, door_xs, linestyle='-', linewidth=4, color='brown')

    for (x, y), neighbors in graph.items():
        for nx, ny in neighbors:
            plt.plot([y+0.5, ny+0.5], [x+0.5, nx+0.5], color='black')  # Draw the connections

    plt.gca().set_xlim(-0.5, grid_shape[1] + 0.5)
    plt.gca().set_ylim(grid_shape[0] + 0.5, -0.5)  # Set y-axis from top to bottom
    plt.title("Room")
    plt.gca().set_aspect('equal', adjustable='box')
    plt.show()


count = []
# Step 2: Prepare the vertices array
rows, cols = csv_data.shape

for x in range(rows):
    for y in range(cols):
        sign = prefix(csv_data[x,y])
        if sign != '0':
            if(x == 0 or prefix(csv_data[x-1,y]) != sign):
                array[sign][(x,y)].add((x,y+1))
                array[sign][(x,y+1)].add((x,y))
            if(x == rows - 1 or prefix(csv_data[x+1,y]) != sign): 
                array[sign][(x+1,y)].add((x+1,y+1))
                array[sign][(x+1,y+1)].add((x+1,y))
            if(y == 0 or prefix(csv_data[x,y-1]) != sign): 
                array[sign][(x,y)].add((x+1,y))
                array[sign][(x+1,y)].add((x,y))
            if(y == cols - 1 or prefix(csv_data[x,y+1]) != sign): 
                array[sign][(x,y+1)].add((x+1,y+1))
                array[sign][(x+1,y+1)].add((x,y+1))
            #check for doors
            if('-' in csv_data[x,y]):
                if(x > 0 and '-' in csv_data[x-1,y] and csv_data[x,y] != csv_data[x-1,y]):
                    doors[sign][prefix(csv_data[x-1,y])].extend([(x,y), (x,y+1)])
                if(x < rows - 1 and '-' in csv_data[x+1,y] and csv_data[x,y] != csv_data[x+1,y]):
                    doors[sign][prefix(csv_data[x+1,y])].extend([(x+1,y), (x+1,y+1)])
                if(y > 0 and '-' in csv_data[x,y-1]and csv_data[x,y] != csv_data[x,y-1]):
                    doors[sign][prefix(csv_data[x,y-1])].extend([(x,y), (x+1,y)])
                if(y < cols - 1 and '-' in csv_data[x,y+1] and csv_data[x,y] != csv_data[x,y+1]):
                    doors[sign][prefix(csv_data[x,y+1])].extend([(x+1,y+1), (x,y+1)])
# Step 3: Trace polygons from the connected components
polygons = []
for component in array:
    polygon = trace_polygon(component)
    if polygon:
        polygons.append((component, polygon))

# Output the results
for i, polygon in enumerate(polygons, 1):
    print(f"Polygon {i}: {polygon}")

graph = create_graph(csv_data)

# Step 4: Visualize the polygons
plot(polygons, doors, graph, csv_data.shape)


