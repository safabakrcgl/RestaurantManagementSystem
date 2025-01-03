CREATE DATABASE Restaurant

-- Main categories table (Drinks, Food)
CREATE TABLE MainCategories (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(50) NOT NULL,
);

INSERT INTO MainCategories(Name)
VALUES ('Foods');

select * from MainCategories

-- Subcategories table (Grills, Soups, etc.)
CREATE TABLE SubCategories (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    MainCategoryID INT REFERENCES MainCategories(ID),
    Name NVARCHAR(50) NOT NULL,
);

INSERT INTO SubCategories(MAINCATEGORYID, NAME)
VALUES (2,'Kahveler');

select * from SubCategories

-- Ingredients/Supplies table
CREATE TABLE Ingredients (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Quantity DECIMAL(10, 2),
    Unit NVARCHAR(20) NOT NULL, -- grams, pieces, liters etc.
);


SELECT * FROM MenuItems

-- Insert necessary ingredients first
INSERT INTO Ingredients (Name, Quantity, Unit) VALUES 
('Minced Meat', 10000, 'grams'),
('Salt', 5000, 'grams'),
('Black Pepper', 1000, 'grams'),
('Water', 100, 'liters');

-- Menu items table
CREATE TABLE MenuItems (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    SubCategoryID INT REFERENCES SubCategories(ID),
    Name NVARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    Description NVARCHAR(MAX),
    IsAvailable BIT DEFAULT 1,
);

INSERT INTO MenuItems (SubCategoryID, Name, Price, Description) VALUES
(1, 'Grilled Meatballs', 10.99, 'Delicious grilled meatballs made with minced meat and spices'),
(1, 'Chicken Wings', 12.99, 'Juicy grilled chicken wings seasoned to perfection'),
(2, 'Tomato Soup', 5.99, 'Freshly made tomato soup served with croutons');



select *
from MenuItems;


-- Recipe requirements table
CREATE TABLE RecipeRequirements (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    MenuItemID INT REFERENCES MenuItems(ID),
    IngredientID INT REFERENCES Ingredients(ID),
    RequiredQuantity DECIMAL(10,2) NOT NULL,
    Unit NVARCHAR(20) NOT NULL
);

-- Recipe Requirements
INSERT INTO RecipeRequirements (MenuItemID, IngredientID, RequiredQuantity, Unit) VALUES
(1, 1, 200, 'grams'), -- Grilled Meatballs require 200 grams of minced meat
(1, 2, 5, 'grams'),   -- Grilled Meatballs require 5 grams of salt
(1, 3, 2, 'grams'),   -- Grilled Meatballs require 2 grams of black pepper
(3, 4, 200, 'liters');-- Tomato Soup requires 0.5 liters of water


select * from RecipeRequirements


-- Restaurant tables
CREATE TABLE RestaurantTables (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    TableNumber INT UNIQUE NOT NULL,
    Capacity INT NOT NULL,
    Status NVARCHAR(20) DEFAULT 'Available' -- Available, Occupied, Reserved
);

-- Restaurant Tables
INSERT INTO RestaurantTables (TableNumber, Capacity) VALUES
(1, 4),
(2, 2),
(3, 6);


select * from RestaurantTables



-- Orders table
CREATE TABLE Orders (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    TableID INT REFERENCES RestaurantTables(ID),
    OrderStatus NVARCHAR(20) DEFAULT 'Pending', -- Pending, Preparing, Served, Completed, Cancelled
    TotalAmount DECIMAL(10,2) DEFAULT 0,
);


-- Orders
INSERT INTO Orders (TableID)
VALUES (1), (2),(3);

select * from Ingredients



-- Order items table
CREATE TABLE OrderItems (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT REFERENCES Orders(ID),
    MenuItemID INT REFERENCES MenuItems(ID),
    Quantity INT NOT NULL,
    Status NVARCHAR(20) DEFAULT 'Pending', -- Pending, Preparing, Served
);

ALTER TABLE OrderItems
ADD UnitPrice DECIMAL(10, 2);

UPDATE OrderItems
SET UnitPrice = MI.Price
FROM OrderItems OI
JOIN MenuItems MI ON OI.MenuItemID = MI.ID;

ALTER TABLE OrderItems
ADD TotalPrice AS (Quantity * UnitPrice);

SELECT
    OI.ID AS OrderItemID,
    OI.OrderID,
    OI.MenuItemID,
    MI.Name AS MenuItemName,
    OI.Quantity,
    OI.UnitPrice,
    OI.TotalPrice
FROM OrderItems OI
JOIN MenuItems MI ON OI.MenuItemID = MI.ID;


-- Order Items
INSERT INTO OrderItems (OrderID, MenuItemID, Quantity, UnitPrice) VALUES
(1, 1, 2, 10.99), -- 2 Grilled Meatballs
(2, 3, 1, 5.99);  -- 1 Tomato Soup


select  * from  OrderItems

CREATE OR ALTER TRIGGER TR_CheckMenuItemAvailability
ON RecipeRequirements
AFTER INSERT, UPDATE
AS
BEGIN
    -- Get all affected MenuItems from the inserted records
    DECLARE @AffectedMenuItems TABLE (MenuItemID INT);

    -- Insert the affected MenuItems into the @AffectedMenuItems table variable
    INSERT INTO @AffectedMenuItems (MenuItemID)
    SELECT DISTINCT MenuItemID FROM inserted;

    -- Update MenuItems.IsAvailable based on ingredient availability
    UPDATE MenuItems
    SET IsAvailable = CASE
        WHEN EXISTS (
            SELECT 1
            FROM RecipeRequirements rr
            JOIN Ingredients i ON rr.IngredientID = i.ID
            WHERE rr.MenuItemID = MenuItems.ID
            AND (i.Quantity < rr.RequiredQuantity  -- Check if any required ingredient is insufficient
                OR i.Unit != rr.Unit)             -- Or if units don't match
        ) THEN 0 -- If any ingredient is unavailable, set IsAvailable to 0 (false)
        ELSE 1 -- If all ingredients are available, set IsAvailable to 1 (true)
    END
    WHERE ID IN (SELECT MenuItemID FROM @AffectedMenuItems);

    -- OPTIONAL: You can log or output messages if needed to debug or track trigger actions
    -- PRINT 'Trigger executed successfully!';
END;

SELECT m.ID, m.Name, m.IsAvailable,
       i.Name as IngredientName, i.Quantity as AvailableQuantity,
       rr.RequiredQuantity as RequiredQuantity
FROM MenuItems m
JOIN RecipeRequirements rr ON m.ID = rr.MenuItemID
JOIN Ingredients i ON rr.IngredientID = i.ID;