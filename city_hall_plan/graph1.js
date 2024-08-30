// Assuming `graphData` is your JSON object containing nodes and edges
import cytoscape from "cytoscape";
fetch('graph.json')
  .then(response => response.json())
  .then(graphData => {
    cy.json({ elements: graphData });
  });

var cy = cytoscape({
  container: document.getElementById('cy'),
  elements: graph, // Directly use JSON data
  style: [
    {
      selector: 'node',
      style: {
        'background-color': '#0074D9',
        'label': 'data(id)'
      }
    },
    {
      selector: 'edge',
      style: {
        'width': 2,
        'line-color': '#999',
        'target-arrow-color': '#999',
        'target-arrow-shape': 'arrow'
      }
    }
  ],
  layout: {
    name: 'grid'
  }
});