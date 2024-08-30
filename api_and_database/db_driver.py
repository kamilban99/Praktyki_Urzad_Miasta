import pyodbc
import json

DB_SERVER = '111.111.26.141,1433'
DB_NAME = 'Praktyka'
DB_USER = 'praktyka1'
DB_PASS = 'praktyka1'
DB_DRIVER = '{ODBC Driver 18 for SQL Server}'
DB_TRUST_CERT = 'yes'
DB_TIMEOUT = 300

def createDbConnection():
    try:
        sql_server=DB_SERVER
        sql_database=DB_NAME
        connection = pyodbc.connect(
            f"DRIVER={DB_DRIVER};"
            f"SERVER={sql_server};"
            f"DATABASE={sql_database};"
            f"UID={DB_USER};"
            f"PWD={DB_PASS};"
            f"TrustServerCertificate={DB_TRUST_CERT};"
            f"Timeout={DB_TIMEOUT};"
        )
        return connection
    except Exception as e:
        print(f"Error connecting to the database: {e}")
        return None

def createTable():
    connection = createDbConnection()
    if connection is None:
        return

    try:
        cursor = connection.cursor()
        drop_query = "DROP TABLE organizacje_pozarządowe"
        cursor.execute(drop_query)
        cursor.commit()
        # Example CREATE TABLE query
        create_table_query = """
        CREATE TABLE organizacje_pozarządowe (
            id INT PRIMARY KEY,
            name VARCHAR(255),
            legalForm VARCHAR(255),
            address_terc VARCHAR(50),
            address_province VARCHAR(50),
            address_district VARCHAR(50),
            address_commune VARCHAR(50),
            address_simc VARCHAR(50),
            address_city VARCHAR(50),
            address_postcode VARCHAR(50),
            address_street VARCHAR(100),
            address_buildingAndFlatNumber VARCHAR(50),
            hasSameAddress BIT,
            benefitZones TEXT,
            aims TEXT
        );
        """
        cursor.execute(create_table_query)
        connection.commit()
        print("Table created successfully.")
    except Exception as e:
        print(f"Error executing query: {e}")

    finally:
        cursor.close()
        connection.close()


def readJsonFile(file_path, iter):
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            data = json.load(file)
        return data
    except Exception as e:
        print(f"Error reading JSON file: {e}")
        return None

def insertJsonData(json_list):
    connection = createDbConnection()
    if connection is None:
        return

    try:
        cursor = connection.cursor()
        truncate_query = "TRUNCATE TABLE organizacje_pozarządowe"
        if(iter == 1):
            cursor.execute(truncate_query)
            cursor.commit

        # Adjusted INSERT query to match the new schema
        insert_query = """
        INSERT INTO organizacje_pozarządowe (
            id, name, legalForm, address_terc, address_province, address_district, 
            address_commune, address_simc, address_city, address_postcode, 
            address_street, address_buildingAndFlatNumber, hasSameAddress, 
            benefitZones, aims
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        for json_data in  json_list:
            # Extract fields from the JSON object
            id = json_data.get('id')
            name = json_data.get('name')
            legal_form = json_data.get('legalForm')
            address = json_data.get('address', {})
            address_terc = address.get('terc')
            address_province = address.get('province')
            address_district = address.get('district')
            address_commune = address.get('commune')
            address_simc = address.get('simc')
            address_city = address.get('city')
            address_postcode = address.get('postcode')
            address_street = address.get('street')
            address_building_and_flat_number = address.get('buildingAndFlatNumber')
            has_same_address = json_data.get('hasSameAddress', False)  # Default to False if not present
            benefit_zones = ', '.join(json_data.get('benefitZones', []))  # Convert list to comma-separated string
            aims = json_data.get('aims')    

            # Execute the insert query with parameters
            cursor.execute(insert_query, (
                id, name, legal_form, address_terc, address_province, address_district,
                address_commune, address_simc, address_city, address_postcode,
                address_street, address_building_and_flat_number, has_same_address,
                benefit_zones, aims
            ))

            # Commit the transaction
            connection.commit()

        print("Data inserted successfully.")

    except Exception as e:
        print(f"Error executing query: {e}")

    finally:
        # Close the cursor and connection
        cursor.close()
        connection.close()


createTable()
iter = 1
max_id = 2694
start_id = 2
end_id = 101
while(end_id < max_id):
    json_data = readJsonFile(f'results_{start_id}_{end_id}.json',iter)
    insertJsonData(json_data)
    start_id += 100
    end_id += 100
    iter += 1

json_data = readJsonFile(f'results_{start_id}_{max_id}.json',iter)
insertJsonData(json_data)
    