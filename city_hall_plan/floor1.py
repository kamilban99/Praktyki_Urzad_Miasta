import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches

def draw_custom_grid_with_rectangles(rectangles, grid_shape):
    # Initialize an empty grid
    grid = np.full(grid_shape, '', dtype=object)
    
    # Plotting setup
    fig, ax = plt.subplots()
    
    # Fill the grid and draw rectangles
    for rect in rectangles:
        string, x1, y1, x2, y2, color = rect.values()
        
        # Fill the grid with the string for the current rectangle
        for i in range(y1, y2 + 1):
            for j in range(x1, x2 + 1):
                grid[i, j] = string
        
        # Draw rectangle borders and color the area
        rect_patch = patches.Rectangle((x1 - 0.5, y1 - 0.5), x2 - x1 + 1, y2 - y1 + 1, 
                                       linewidth=2, edgecolor='black', facecolor=color, alpha=0.3)
        ax.add_patch(rect_patch)
    
    # Add the grid lines
    ax.set_xticks(np.arange(-0.5, grid_shape[1], 1), minor=True)
    ax.set_yticks(np.arange(-0.5, grid_shape[0], 1), minor=True)
    ax.grid(which="minor", color="black", linestyle='-', linewidth=1.5)
    
    # Set tick labels
    ax.set_xticks(np.arange(0, grid_shape[1], 1))
    ax.set_yticks(np.arange(0, grid_shape[0], 1))
    ax.set_xticklabels(np.arange(0, grid_shape[1], 1))
    ax.set_yticklabels(np.arange(0, grid_shape[0], 1))
    
    # Display the grid values
    for y in range(grid_shape[0]):
        for x in range(grid_shape[1]):
            if grid[y, x]:
                ax.text(x, y, grid[y, x], ha='center', va='center', fontsize=10)
    
    # Set aspect ratio and invert y-axis for correct orientation
    ax.set_aspect('equal')
    plt.gca().invert_yaxis()
    
    # Show plot
    plt.show()

# Example usage with multiple rectangles
rectangles = [
    {"string": "e113", "x1": 0, "y1": 0, "x2": 4, "y2": 3, "color": "none"},
    {"string": "e114", "x1": 5, "y1": 0, "x2": 9, "y2": 3, "color": "none"},
    {"string": "e110", "x1": 5, "y1": 4, "x2": 7, "y2": 7, "color": "none"},
    {"string": "e109", "x1": 8, "y1": 4, "x2": 9, "y2": 7, "color": "none"},
    {"string": "d",    "x1": 5, "y1": 2, "x2": 7, "y2": 3, "color": "none"},
    {"string": "s",    "x1": 10, "y1": 0, "x2": 12, "y2": 3, "color": "#ccffcc"}, # Light green
    {"string": "k",    "x1": 10, "y1": 4, "x2": 12, "y2": 7, "color": "#cce6ff"}  # Light blue
]

grid_shape = (8, 13)  # Define the shape of the grid (rows, columns)
draw_custom_grid_with_rectangles(rectangles, grid_shape)