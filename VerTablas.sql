USE FanHub;
GO

-- =============================================
-- VER TODAS LAS TABLAS CON SU CONTENIDO
-- =============================================

DECLARE @tabla VARCHAR(100);
DECLARE @sql NVARCHAR(MAX);

DECLARE cursor_tablas CURSOR FOR
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

OPEN cursor_tablas;
FETCH NEXT FROM cursor_tablas INTO @tabla;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '==========================================';
    PRINT 'TABLA: ' + @tabla;
    PRINT '==========================================';
    
    SET @sql = 'SELECT * FROM ' + QUOTENAME(@tabla);
    EXEC sp_executesql @sql;
    
    PRINT '';
    FETCH NEXT FROM cursor_tablas INTO @tabla;
END

CLOSE cursor_tablas;
DEALLOCATE cursor_tablas;
GO