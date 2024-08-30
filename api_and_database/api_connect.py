from flask import Flask, jsonify, request
import requests
from bs4 import BeautifulSoup

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False

@app.route('/fetch', methods=['GET'])
def get_info():
    try:
        url = request.args.get('url')
        fields = request.args.get('fields')
        id_key = request.args.get('id_key')

        if not url:
            return jsonify({'error': 'URL parameter is required'}), 400

        if fields:
            fields = [field.strip() for field in fields.split(',')]
        else:
            fields = []

        response = requests.get(url)
        response.raise_for_status()
        response.encoding = 'utf-8'
        print(response.status_code)

        if response.headers.get('Content-Type') == 'application/json':
            data = response.json()
            
            if id_key:
                if isinstance(data, dict) and id_key in data:
                    ids = [item[id_key] for item in data.get('items', []) if id_key in item]
                    return jsonify({'ids': ids})
                else:
                    return jsonify({'error': 'ID key not found in the JSON data'}), 400

            if fields:
                result = {field: data.get(field, 'Field not found') for field in fields}
            else:
                result = data
            
            return jsonify(result)
        
        else:
            soup = BeautifulSoup(response.content, 'html.parser')

            def clean_text(text):
                cleaned_text = text.replace('\r\n', ' ').replace('\r', ' ').replace('\n', ' ')
                cleaned_text = ' '.join(cleaned_text.split())
                return cleaned_text

            result = {
                'title': soup.title.string.strip() if soup.title else 'No title',
                'paragraphs': [clean_text(p.get_text()) for p in soup.find_all('p')],
                'addresses': [clean_text(address.get_text()) for address in soup.find_all('address')]
            }

            return jsonify(result)
    
    except requests.exceptions.RequestException as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)