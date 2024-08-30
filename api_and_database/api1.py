from flask import Flask, jsonify
import requests
from requests.exceptions import RequestException, ConnectionError, Timeout, HTTPError
from bs4 import BeautifulSoup

app = Flask(__name__)

# Replace this URL with the correct API endpoint that returns HTML content
API_URL = "https://api.dane.gov.pl/1.4/datasets/3167,osuwiska?lang=pl"

@app.route('/get-ids', methods=['GET'])
def get_ids_from_html():
    try:
        # Make a GET request to the API
        response = requests.get(API_URL, timeout=10)
        response.raise_for_status()  # Raise an HTTPError for bad responses (4xx or 5xx)
        
        # Parse the HTML content
        soup = BeautifulSoup(response.content, 'html.parser')
        print(soup)
        # Assuming the IDs are within elements with a specific class or tag, e.g., <div class="resource-id">ID</div>
        ids = [element.text for element in soup.find_all(class_='resource-id')]
        
        if ids:
            return jsonify({'ids': ids}), 200
        else:
            return jsonify({'error': 'No IDs found in the HTML content'}), 404
    
    except ConnectionError:
        return jsonify({'error': 'Failed to connect to the API server'}), 503
    except Timeout:
        return jsonify({'error': 'The request to the API server timed out'}), 504
    except HTTPError as http_err:
        return jsonify({'error': f'HTTP error occurred: {http_err}'}), response.status_code
    except RequestException as req_err:
        return jsonify({'error': f'An error occurred: {req_err}'}), 500

if __name__ == '__main__':
    app.run(debug=True)