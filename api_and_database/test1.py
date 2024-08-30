import requests
from bs4 import BeautifulSoup

url = "https://bip.um.szczecin.pl/UMSzczecinBIP/chapter_131445.asp"

headers = {
    "accept": "*/*",
    "accept-encoding": "gzip, deflate, br, zstd",
    "accept-language": "pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7",
    "origin": "https://bip.um.szczecin.pl",
    "referer": "https://bip.um.szczecin.pl/",
    "sec-ch-ua": '"Not)A;Brand";v="99", "Google Chrome";v="127", "Chromium";v="127"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"Windows"',
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "cross-site",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
}

response = requests.get(url, headers=headers)

# Check if the response is successful
if response.status_code == 200:
    # Parse the HTML content
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # Extract the information you need
    # For example, extract all text within paragraph tags
    paragraphs = soup.find_all('p')
    for p in paragraphs:
        print(p.get_text())
    
    # If you need to save the whole content as HTML
    with open('output.html', 'w', encoding='utf-8') as file:
        file.write(soup.prettify())
else:
    print(f"Failed to retrieve the page. Status code: {response.status_code}")