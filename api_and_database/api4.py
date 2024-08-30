import requests

def fetch_data(a, b):
    url = 'http://127.0.0.1:5000/fetch_all'
    params = {'a': a, 'b': b}
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()  # Will raise an HTTPError if the response status is 4xx, 5xx
        filename = f"results_{a}_{b}.json"
        with open(filename, 'w', encoding='utf-8') as file:
            file.write(response.text)
        print(f"Data fetched and saved to {filename}")
    except requests.exceptions.RequestException as e:
        print(f"An error occurred: {e}")

max_id = 2694
def main():
    start_id = 2
    end_id = 101
    while(end_id < max_id):
        fetch_data(start_id, end_id)
        start_id += 100
        end_id += 100
    fetch_data(end_id+1, max_id)
if __name__ == "__main__":
    fetch_data(2602, 2694)
    #main()