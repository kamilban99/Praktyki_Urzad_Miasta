import plotly.graph_objects as go
import networkx as nx

# Create a NetworkX graph
G = nx.Graph()

# Add nodes with attributes
G.add_node('A', size=30, color='red', shape='circle')
G.add_node('B', size=50, color='blue', shape='square')

# Add edges
G.add_edge('A', 'B')

# Generate positions for nodes
pos = nx.spring_layout(G)

# Initialize lists for trace data
x_nodes, y_nodes, text_nodes, sizes, colors, shapes = [], [], [], [], [], []

# Extract node attributes
for node in G.nodes:
    x, y = pos[node]
    size = G.nodes[node].get('size', 20)
    color = G.nodes[node].get('color', 'lightblue')
    shape = G.nodes[node].get('shape', 'circle')  # Default to circle if not specified
    
    x_nodes.append(x)
    y_nodes.append(y)
    text_nodes.append(node)
    sizes.append(size)
    colors.append(color)
    shapes.append(shape)

# Create node trace
node_trace = go.Scatter(
    x=x_nodes,
    y=y_nodes,
    text=text_nodes,
    mode='markers+text',
    textposition='bottom center',
    marker=dict(
        size=sizes,
        color=colors,
        symbol=shapes  # Set symbols based on shape
    )
)

# Create the figure
fig = go.Figure()

# Add node traces
fig.add_trace(node_trace)

# Initialize edge trace as lists
edge_trace_x = []
edge_trace_y = []

# Populate edge_trace with edge data
for edge in G.edges:
    x0, y0 = pos[edge[0]]
    x1, y1 = pos[edge[1]]
    edge_trace_x.extend([x0, x1, None])  # Use extend to add elements to the list
    edge_trace_y.extend([y0, y1, None])  # Use extend to add elements to the list

# Create edge trace
edge_trace = go.Scatter(
    x=edge_trace_x,
    y=edge_trace_y,
    line=dict(width=0.5, color='#888'),
    hoverinfo='none',
    mode='lines'
)

fig.add_trace(edge_trace)

# Update layout
fig.update_layout(showlegend=False, xaxis=dict(showgrid=False, zeroline=False),
                  yaxis=dict(showgrid=False, zeroline=False))

fig.show()
