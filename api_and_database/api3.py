from flask import Flask, jsonify, request
import requests
import json
import os

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False

id_max = 2694

# Function to fetch detailed information for a specific ID
def fetch_detail(id):
    detail_url = f'https://api.szczecin.bazawitkac.pl/Public/Organization/Get/{id}'
    response = requests.get(detail_url)
    response.raise_for_status()
    return response.json()

@app.route('/fetch_all', methods=['GET'])
def fetch_all():
    try:
        # Fetch details for each ID
        a = request.args.get('a', type=int)
        b = request.args.get('b', type=int)
        details = []
        for id in range(a,min(id_max+1,b+1)):
            try:
                detail = fetch_detail(id)
                details.append(detail)
            except requests.exceptions.RequestException as e:
                details.append({'id': id, 'error': str(e)})
                
        filename = f"results_{a}_{b}.json"
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(details, f, ensure_ascii=False, indent=4)
            
        return jsonify(details)

    except requests.exceptions.RequestException as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)