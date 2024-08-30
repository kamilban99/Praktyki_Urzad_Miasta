CREATE TABLE organizacje_pozarz¹dowe (
    id INT PRIMARY KEY,
    legalForm VARCHAR(255),
    address_terc VARCHAR(10),
    address_province VARCHAR(50),
    address_district VARCHAR(50),
    address_commune VARCHAR(50),
    address_simc VARCHAR(10),
    address_city VARCHAR(50),
    address_postcode VARCHAR(10),
    address_street VARCHAR(100),
    address_buildingAndFlatNumber VARCHAR(10),
    hasSameAddress BIT,
    benefitZones TEXT,
    aims TEXT,
    name VARCHAR(255)
);