SELECT * FROM MenuItems

DBCC CHECKIDENT ('SubCategories', RESEED, 0);


select  * from  MainCategories
select  * from  MenuItems


-- Recipe Requirements
INSERT INTO RecipeRequirements (MenuItemID, IngredientID, RequiredQuantity, Unit) VALUES
(1, 1, 200, 'grams'), -- Grilled Meatballs require 200 grams of minced meat
(1, 2, 5, 'grams'),   -- Grilled Meatballs require 5 grams of salt
(1, 3, 2, 'grams'),   -- Grilled Meatballs require 2 grams of black pepper
(3, 4, 200, 'liters')-- Tomato Soup requires 0.5 liters of water






INSERT INTO RecipeRequirements (MenuItemID, IngredientID, RequiredQuantity, Unit) VALUES
(2,2, 4470, 'grams');

-- First, let's add a unique constraint if it doesn't exist


CREATE OR ALTER TRIGGER TR_ValidateAndProcessOrder
ON OrderItems
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Prevent recursion
    IF TRIGGER_NESTLEVEL() > 1
        RETURN;

    -- Use a temp table to process the inserted rows
    SELECT DISTINCT OrderID, MenuItemID, Quantity, UnitPrice
    INTO #TempInsert
    FROM inserted;

    -- Validate ingredient availability
    IF EXISTS (
        SELECT 1
        FROM #TempInsert i
        JOIN RecipeRequirements rr ON rr.MenuItemID = i.MenuItemID
        JOIN Ingredients ing ON ing.ID = rr.IngredientID
        WHERE (ing.Quantity - (rr.RequiredQuantity * i.Quantity)) < 0
    )
    BEGIN
        DROP TABLE #TempInsert;
        RAISERROR ('Cannot process order: Insufficient ingredient quantity available!', 16, 1);
        RETURN;
    END

    -- Begin transaction
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Insert the order items
        INSERT INTO OrderItems (OrderID, MenuItemID, Quantity, UnitPrice)
        SELECT OrderID, MenuItemID, Quantity, UnitPrice
        FROM #TempInsert;

        -- Update ingredient quantities
        UPDATE ing
        SET ing.Quantity = ing.Quantity - (rr.RequiredQuantity * i.Quantity)
        FROM Ingredients ing
        JOIN RecipeRequirements rr ON ing.ID = rr.IngredientID
        JOIN #TempInsert i ON rr.MenuItemID = i.MenuItemID;

        -- Update MenuItems availability
        UPDATE mi
        SET IsAvailable =
            CASE WHEN EXISTS (
                SELECT 1
                FROM RecipeRequirements rr
                JOIN Ingredients i ON rr.IngredientID = i.ID
                WHERE rr.MenuItemID = mi.ID
                AND (i.Quantity < rr.RequiredQuantity)
            ) THEN 0
            ELSE 1
            END
        FROM MenuItems mi
        WHERE EXISTS (
            SELECT 1
            FROM RecipeRequirements rr
            WHERE rr.MenuItemID = mi.ID
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH

    -- Clean up
    IF OBJECT_ID('tempdb..#TempInsert') IS NOT NULL
        DROP TABLE #TempInsert;
END;

select * from OrderItems

-- Test: Place a new order
INSERT INTO OrderItems (OrderID, MenuItemID, Quantity, UnitPrice)
VALUES (1, 1, 1, 10.99);  -- Order 2 Grilled Meatballs

-- Check updated ingredient quantities
SELECT i.Name, i.Quantity, i.Unit
FROM Ingredients i;

-- Check menu item availability
SELECT m.Name, m.IsAvailable
FROM MenuItems m;


SELECT m.ID, m.Name, m.IsAvailable,
       i.Name as IngredientName, i.Quantity as AvailableQuantity,
       rr.RequiredQuantity as RequiredQuantity, i.Unit as Unit, rr.Unit as requiredUnit
FROM MenuItems m
JOIN RecipeRequirements rr ON m.ID = rr.MenuItemID
JOIN Ingredients i ON rr.IngredientID = i.ID;




INSERT INTO RecipeRequirements (MenuItemID, IngredientID, RequiredQuantity, Unit)
VALUES (4,5, 50, 'grams' ),
       (4,6,10,'grams')

select * from   MenuItems
select * from   RecipeRequirements

GO
CREATE OR ALTER TRIGGER TR_SumRecipeRequirements
ON RecipeRequirements
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Eğer aynı MenuItemID ve IngredientID kombinasyonu varsa, miktarları topla
    MERGE RecipeRequirements AS target
    USING inserted AS source
    ON target.MenuItemID = source.MenuItemID 
    AND target.IngredientID = source.IngredientID
    
    WHEN MATCHED THEN
        UPDATE SET RequiredQuantity = target.RequiredQuantity + source.RequiredQuantity
    
    WHEN NOT MATCHED THEN
        INSERT (MenuItemID, IngredientID, RequiredQuantity, Unit)
        VALUES (source.MenuItemID, source.IngredientID, source.RequiredQuantity, source.Unit);
END;
GO

DROP TRIGGER [TR_CheckMenuItemAvailability];

SELECT *
FROM sys.triggers


select * from RecipeRequirements
