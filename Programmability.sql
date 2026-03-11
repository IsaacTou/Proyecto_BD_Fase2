USE [FanHub];
GO

-- Función 1: fn_calcular_impuesto
-- Descripción: Calcula el impuesto del 16% sobre un monto
CREATE OR ALTER FUNCTION fn_calcular_impuesto (
    @monto DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @impuesto DECIMAL(10,2);
    DECLARE @porcentaje_impuesto DECIMAL(3,2) = 0.16; -- 16% (parametrizable)
    
    SET @impuesto = @monto * @porcentaje_impuesto;
    
    RETURN @impuesto;
END;
GO

-- Función 2: fn_clasificar_ingreso
-- Descripción: Clasifica un monto en categorías Diamante/Oro/Plata
CREATE OR ALTER FUNCTION fn_clasificar_ingreso (
    @monto DECIMAL(10,2)
)
RETURNS NVARCHAR(10)
AS
BEGIN
    DECLARE @clasificacion NVARCHAR(10);
    
    SET @clasificacion = CASE 
        WHEN @monto > 1000 THEN 'Diamante'
        WHEN @monto >= 500 THEN 'Oro'
        ELSE 'Plata'
    END;
    
    RETURN @clasificacion;
END;
GO

-- Función 3: fn_calcular_reputacion
-- Descripción: Calcula el puntaje de reputación de un creador (0-100)
-- Fórmula: (Total Suscriptores * 0.5) + (Total Reacciones Último Mes * 0.1) + (Antigüedad Meses * 2)
CREATE OR ALTER FUNCTION fn_calcular_reputacion (
    @idCreador INT
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @puntaje DECIMAL(5,2) = 0;
    DECLARE @total_suscriptores INT = 0;
    DECLARE @reacciones_ultimo_mes INT = 0;
    DECLARE @antiguedad_meses INT = 0;
    DECLARE @fecha_primera_publicacion DATE;
    
    -- 1. Calcular total de suscriptores activos del creador
    SELECT @total_suscriptores = COUNT(DISTINCT s.idUsuario)
    FROM Suscripcion s
    INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
    WHERE n.idCreador = @idCreador
      AND s.estado = 'Activa';
    
    -- 2. Calcular reacciones a sus publicaciones en los últimos 30 días
    SELECT @reacciones_ultimo_mes = COUNT(ur.idUsuario)
    FROM UsuarioReaccionPublicacion ur
    INNER JOIN Publicacion p ON ur.idPublicacion = p.id
    WHERE p.idCreador = @idCreador
      AND ur.fecha_reaccion >= DATEADD(day, -30, GETDATE());
    
    -- 3. Calcular antigüedad en meses (desde su primera publicación)
    SELECT @fecha_primera_publicacion = MIN(p.fecha_publicacion)
    FROM Publicacion p
    WHERE p.idCreador = @idCreador;
    
    IF @fecha_primera_publicacion IS NOT NULL
    BEGIN
        SET @antiguedad_meses = DATEDIFF(month, @fecha_primera_publicacion, GETDATE());
        -- Asegurar que no sea negativo
        IF @antiguedad_meses < 0
            SET @antiguedad_meses = 0;
    END
    
    -- 4. Calcular puntaje según fórmula
    SET @puntaje = (@total_suscriptores * 0.5) + (@reacciones_ultimo_mes * 0.1) + (@antiguedad_meses * 2);
    
    -- 5. Limitar a máximo 100 puntos
    IF @puntaje > 100
        SET @puntaje = 100;
    
    RETURN @puntaje;
END;
GO

-- Stored Procedure: sp_crear_suscripcion
-- Descripción: Crea una nueva suscripción y genera su primera factura
CREATE OR ALTER PROCEDURE sp_crear_suscripcion
    @idUsuario INT,
    @idNivel INT,
    @idMetodoPago INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @idCreador INT;
    DECLARE @precio_actual DECIMAL(10,2);
    DECLARE @idSuscripcion INT;
    DECLARE @fecha_inicio DATE = GETDATE();
    DECLARE @fecha_renovacion DATE;
    DECLARE @fecha_fin DATE;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 1. Obtener información del nivel de suscripción
        SELECT 
            @idCreador = n.idCreador,
            @precio_actual = n.precio_actual
        FROM NivelSuscripcion n
        WHERE n.id = @idNivel;
        
        -- Validar que el nivel existe
        IF @idCreador IS NULL
        BEGIN
            RAISERROR('El nivel de suscripción especificado no existe.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- 2. Validar que el usuario no tenga ya una suscripción activa con este creador
        IF EXISTS (
            SELECT 1 
            FROM Suscripcion s
            INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
            WHERE s.idUsuario = @idUsuario 
              AND n.idCreador = @idCreador
              AND s.estado = 'Activa'
        )
        BEGIN
            RAISERROR('El usuario ya tiene una suscripción activa con este creador.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- 3. Validar que el método de pago pertenece al usuario
        IF NOT EXISTS (
            SELECT 1 
            FROM MetodoPago mp
            WHERE mp.id = @idMetodoPago 
              AND mp.idUsuario = @idUsuario
        )
        BEGIN
            RAISERROR('El método de pago no pertenece al usuario especificado.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- 4. Calcular fechas
        SET @fecha_renovacion = DATEADD(month, 1, @fecha_inicio);
        SET @fecha_fin = @fecha_renovacion; -- La suscripción termina en la fecha de renovación
        
        -- 5. Insertar la suscripción
        INSERT INTO Suscripcion (
            idUsuario,
            idNivel,
            fecha_inicio,
            fecha_renovacion,
            fecha_fin,
            estado,
            precio_pactado
        ) VALUES (
            @idUsuario,
            @idNivel,
            @fecha_inicio,
            @fecha_renovacion,
            @fecha_fin,
            'Activa',
            @precio_actual
        );
        
        -- Obtener el ID de la suscripción recién creada
        SET @idSuscripcion = SCOPE_IDENTITY();
        
        -- 6. Generar la primera factura (llamando al sp_generar_factura_pago)
        -- Nota: Este SP aún no existe, lo crearás después
        EXEC sp_generar_factura_pago @idSuscripcion;
        
        -- Si todo salió bien, confirmar la transacción
        COMMIT TRANSACTION;
        
        -- Devolver información de éxito
        SELECT 
            'Suscripción creada exitosamente' AS Mensaje,
            @idSuscripcion AS idSuscripcion,
            @idUsuario AS idUsuario,
            @idCreador AS idCreador,
            @precio_actual AS PrecioPactado,
            @fecha_inicio AS FechaInicio,
            @fecha_renovacion AS FechaRenovacion;
            
    END TRY
    BEGIN CATCH
        -- Si hay error, deshacer todo
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Devolver información del error
        SELECT 
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_SEVERITY() AS ErrorSeverity,
            ERROR_STATE() AS ErrorState;
            
    END CATCH
END;
GO

-- Stored Procedure: sp_dashboard_creador
-- Descripción: Devuelve 3 resultados: KPIs, fans activos y mejor publicación
CREATE OR ALTER PROCEDURE sp_dashboard_creador
    @idCreador INT,
    @fecha_inicio DATE,
    @fecha_fin DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Tabla 1: Resumen de KPIs
    SELECT 
        (SELECT ISNULL(SUM(f.monto_total), 0)
         FROM Factura f
         INNER JOIN Suscripcion s ON f.idSuscripcion = s.id
         INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
         WHERE n.idCreador = @idCreador
           AND f.fecha_emision BETWEEN @fecha_inicio AND @fecha_fin) AS TotalGanado,
        
        (SELECT COUNT(DISTINCT s.idUsuario)
         FROM Suscripcion s
         INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
         WHERE n.idCreador = @idCreador
           AND s.fecha_inicio BETWEEN @fecha_inicio AND @fecha_fin) AS TotalNuevosSubs;
   
    -- Tabla 2: Top 5 fans más activos
    SELECT TOP 5
        u.nickname,
        COUNT(DISTINCT c.id) AS TotalComentarios,
        COUNT(DISTINCT ur.idPublicacion) AS TotalReacciones,
        (COUNT(DISTINCT c.id) + COUNT(DISTINCT ur.idPublicacion)) AS TotalInteracciones
    FROM Usuario u
    LEFT JOIN Comentario c ON u.id = c.idUsuario
    LEFT JOIN UsuarioReaccionPublicacion ur ON u.id = ur.idUsuario
    WHERE EXISTS (
        SELECT 1 
        FROM Suscripcion s
        INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
        WHERE n.idCreador = @idCreador
          AND s.idUsuario = u.id
          AND s.estado = 'Activa'
    )
    GROUP BY u.id, u.nickname
    ORDER BY TotalInteracciones DESC;
    
    -- Tabla 3: Publicación con mejor rendimiento
    SELECT TOP 1
        p.id AS idPublicacion,
        p.titulo,
        p.fecha_publicacion,
        p.tipo_contenido,
        COUNT(DISTINCT c.id) AS TotalComentarios,
        COUNT(DISTINCT ur.idUsuario) AS TotalReacciones,
        (COUNT(DISTINCT c.id) + COUNT(DISTINCT ur.idUsuario)) AS TotalInteracciones
    FROM Publicacion p
    LEFT JOIN Comentario c ON p.id = c.idPublicacion
    LEFT JOIN UsuarioReaccionPublicacion ur ON p.id = ur.idPublicacion
    WHERE p.idCreador = @idCreador
      AND p.fecha_publicacion BETWEEN @fecha_inicio AND @fecha_fin
    GROUP BY p.id, p.titulo, p.fecha_publicacion, p.tipo_contenido
    ORDER BY TotalInteracciones DESC;
END;
GO

-- Stored Procedure: sp_publicar_con_etiquetas
-- Descripción: Crea una publicación y procesa etiquetas
CREATE OR ALTER PROCEDURE sp_publicar_con_etiquetas
    @idCreador INT,
    @titulo NVARCHAR(60),
    @fecha_publicacion DATETIME2,
    @es_publica BIT,
    @tipo_contenido VARCHAR(6),
    -- Parámetros específicos según tipo
    @duracion_seg INT = NULL,
    @resolucion VARCHAR(5) = NULL,
    @url_stream VARCHAR(100) = NULL,
    @contenido_html NVARCHAR(MAX) = NULL,
    @resumen_gratuito VARCHAR(500) = NULL,
    @ancho INT = NULL,
    @alto INT = NULL,
    @formato VARCHAR(30) = NULL,
    @alt_text NVARCHAR(255) = NULL,
    @url_imagen VARCHAR(100) = NULL,
    -- Etiquetas (separadas por comas)
    @etiquetas_texto NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @idPublicacion INT;
    DECLARE @nombre_etiqueta NVARCHAR(30);
    DECLARE @idEtiqueta INT;
    DECLARE @posicion INT;
    DECLARE @posicion_coma INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 1. Insertar la publicación
        INSERT INTO Publicacion (
            idCreador,
            titulo,
            fecha_publicacion,
            es_publica,
            tipo_contenido
        ) VALUES (
            @idCreador,
            @titulo,
            @fecha_publicacion,
            @es_publica,
            @tipo_contenido
        );
        
        SET @idPublicacion = SCOPE_IDENTITY();
        

        -- 2. Insertar en la tabla específica según tipo

        IF @tipo_contenido = 'VIDEO'
        BEGIN
            INSERT INTO Video (idPublicacion, duracion_seg, resolucion, url_stream)
            VALUES (@idPublicacion, @duracion_seg, @resolucion, @url_stream);
        END
        ELSE IF @tipo_contenido = 'TEXTO'
        BEGIN
            INSERT INTO Texto (idPublicacion, contenido_html, resumen_gratuito)
            VALUES (@idPublicacion, @contenido_html, @resumen_gratuito);
        END
        ELSE IF @tipo_contenido = 'IMAGEN'
        BEGIN
            INSERT INTO Imagen (idPublicacion, ancho, alto, formato, alt_text, url_imagen)
            VALUES (@idPublicacion, @ancho, @alto, @formato, @alt_text, @url_imagen);
        END
        

        -- 3. Procesar etiquetas

        SET @etiquetas_texto = LTRIM(RTRIM(@etiquetas_texto)) + ','; -- Agregar coma al final
        
        WHILE LEN(@etiquetas_texto) > 1
        BEGIN
            SET @posicion_coma = CHARINDEX(',', @etiquetas_texto);
            SET @nombre_etiqueta = LTRIM(RTRIM(SUBSTRING(@etiquetas_texto, 1, @posicion_coma - 1)));
            
            IF LEN(@nombre_etiqueta) > 0
            BEGIN
                -- Buscar si la etiqueta existe
                SELECT @idEtiqueta = id FROM Etiqueta WHERE nombre = @nombre_etiqueta;
                
                -- Si no existe, crearla
                IF @idEtiqueta IS NULL
                BEGIN
                    INSERT INTO Etiqueta (nombre) VALUES (@nombre_etiqueta);
                    SET @idEtiqueta = SCOPE_IDENTITY();
                END
                
                -- Insertar la relación publicación-etiqueta
                INSERT INTO PublicacionEtiqueta (idPublicacion, idEtiqueta)
                VALUES (@idPublicacion, @idEtiqueta);
            END
            
            -- Quitar la etiqueta procesada
            SET @etiquetas_texto = SUBSTRING(@etiquetas_texto, @posicion_coma + 1, LEN(@etiquetas_texto));
        END
        
        COMMIT TRANSACTION;
        
        SELECT 
            'Publicación creada exitosamente' AS Mensaje,
            @idPublicacion AS idPublicacion;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SELECT 
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

-- Stored Procedure: sp_generar_factura_pago
-- Descripción: Genera una factura para una suscripción
CREATE OR ALTER PROCEDURE sp_generar_factura_pago
    @idSuscripcion INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @idUsuario INT;
    DECLARE @idNivel INT;
    DECLARE @idCreador INT;
    DECLARE @precio_pactado DECIMAL(10,2);
    DECLARE @sub_total DECIMAL(10,2);
    DECLARE @monto_impuesto DECIMAL(10,2);
    DECLARE @monto_total DECIMAL(10,2);
    DECLARE @codigo_transaccion VARCHAR(32);
    DECLARE @fecha_actual DATETIME2 = GETDATE();
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 1. Obtener información de la suscripción
        SELECT 
            @idUsuario = s.idUsuario,
            @idNivel = s.idNivel,
            @precio_pactado = s.precio_pactado,
            @idCreador = n.idCreador
        FROM Suscripcion s
        INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
        WHERE s.id = @idSuscripcion;
        
        IF @idUsuario IS NULL
        BEGIN
            RAISERROR('La suscripción especificada no existe.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- 2. Calcular montos
        SET @sub_total = @precio_pactado;
        SET @monto_impuesto = dbo.fn_calcular_impuesto(@sub_total);
        SET @monto_total = @sub_total + @monto_impuesto;
        
        -- 3. Generar código de transacción: YYYYMMDD-idUsuario-idSuscripcion-idNivel-idCreador
        SET @codigo_transaccion = 
            CONVERT(VARCHAR(8), @fecha_actual, 112) + '-' + 
            CAST(@idUsuario AS VARCHAR) + '-' + 
            CAST(@idSuscripcion AS VARCHAR) + '-' + 
            CAST(@idNivel AS VARCHAR) + '-' + 
            CAST(@idCreador AS VARCHAR);
        
        -- 4. Insertar factura
        INSERT INTO Factura (
            idSuscripcion,
            codigo_transaccion,
            fecha_emision,
            sub_total,
            monto_impuesto,
            monto_total
        ) VALUES (
            @idSuscripcion,
            @codigo_transaccion,
            @fecha_actual,
            @sub_total,
            @monto_impuesto,
            @monto_total
        );
        
        COMMIT TRANSACTION;
        
        SELECT 
            'Factura generada exitosamente' AS Mensaje,
            SCOPE_IDENTITY() AS idFactura,
            @codigo_transaccion AS CodigoTransaccion,
            @monto_total AS MontoTotal;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SELECT 
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

-- Trigger 1: trg_AuditoriaPrecios
-- Descripción: Evita que el precio de un nivel aumente más del 50%
CREATE OR ALTER TRIGGER trg_AuditoriaPrecios
ON NivelSuscripcion
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Verificar si se actualizó la columna precio_actual
    IF UPDATE(precio_actual)
    BEGIN
        DECLARE @idNivel INT;
        DECLARE @precio_anterior DECIMAL(10,2);
        DECLARE @precio_nuevo DECIMAL(10,2);
        DECLARE @aumento_porcentaje DECIMAL(5,2);
        
        -- Recorrer los registros actualizados (puede ser múltiples)
        DECLARE cursor_precios CURSOR FOR
        SELECT 
            i.id,
            d.precio_actual AS precio_anterior,
            i.precio_actual AS precio_nuevo
        FROM inserted i
        INNER JOIN deleted d ON i.id = d.id;
        
        OPEN cursor_precios;
        FETCH NEXT FROM cursor_precios INTO @idNivel, @precio_anterior, @precio_nuevo;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Calcular porcentaje de aumento
            IF @precio_anterior > 0 -- Evitar división por cero
            BEGIN
                SET @aumento_porcentaje = ((@precio_nuevo - @precio_anterior) / @precio_anterior) * 100;
                
                -- Si el aumento es mayor al 50%, cancelar la operación
                IF @aumento_porcentaje > 50
                BEGIN
                    RAISERROR('No se permite aumentar el precio más del 50%%. Cambio cancelado.', 16, 1);
                    ROLLBACK TRANSACTION;
                    RETURN;
                END
            END
            
            FETCH NEXT FROM cursor_precios INTO @idNivel, @precio_anterior, @precio_nuevo;
        END
        
        CLOSE cursor_precios;
        DEALLOCATE cursor_precios;
    END
END;
GO

-- Trigger 2: trg_ProteccionMenores
-- Descripción: Evita que menores de edad se suscriban a contenido NSFW
CREATE OR ALTER TRIGGER trg_ProteccionMenores
ON Suscripcion
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @idUsuario INT;
    DECLARE @idNivel INT;
    DECLARE @idCreador INT;
    DECLARE @es_nsfw BIT;
    DECLARE @fecha_nacimiento DATE;
    DECLARE @edad INT;
    
    -- Recorrer los registros a insertar
    DECLARE cursor_insert CURSOR FOR
    SELECT 
        i.idUsuario,
        i.idNivel
    FROM inserted i;
    
    OPEN cursor_insert;
    FETCH NEXT FROM cursor_insert INTO @idUsuario, @idNivel;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 1. Obtener el creador y si es NSFW
        SELECT 
            @idCreador = n.idCreador,
            @es_nsfw = c.es_nsfw
        FROM NivelSuscripcion n
        INNER JOIN Creador c ON n.idCreador = c.idUsuario
        WHERE n.id = @idNivel;
        
        -- 2. Si el contenido es NSFW, verificar edad del usuario
        IF @es_nsfw = 1
        BEGIN
            -- Obtener fecha de nacimiento del usuario
            SELECT @fecha_nacimiento = fecha_nacimiento
            FROM Usuario
            WHERE id = @idUsuario;
            
            -- Calcular edad
            SET @edad = DATEDIFF(YEAR, @fecha_nacimiento, GETDATE());
            -- Ajuste fino (si aún no ha cumplido años este año)
            IF DATEADD(YEAR, @edad, @fecha_nacimiento) > GETDATE()
                SET @edad = @edad - 1;
            
            -- Si es menor de 18, cancelar
            IF @edad < 18
            BEGIN
                RAISERROR('Contenido restringido por edad. El usuario debe ser mayor de 18 años.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END
        END
        
        FETCH NEXT FROM cursor_insert INTO @idUsuario, @idNivel;
    END
    
    CLOSE cursor_insert;
    DEALLOCATE cursor_insert;
    
    -- Si todo está bien, insertar los registros
    INSERT INTO Suscripcion (idUsuario, idNivel, fecha_inicio, fecha_renovacion, fecha_fin, estado, precio_pactado)
    SELECT 
        i.idUsuario,
        i.idNivel,
        i.fecha_inicio,
        i.fecha_renovacion,
        i.fecha_fin,
        i.estado,
        i.precio_pactado
    FROM inserted i;
END;
GO

-- Trigger 3: trg_ValidarEdadUsuario (VERSIÓN CORREGIDA)
-- Descripción: Evita que se registren usuarios menores de 13 años
CREATE OR ALTER TRIGGER trg_ValidarEdadUsuario
ON Usuario
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fecha_limite DATE;
    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    -- Calcular la fecha mínima de nacimiento (hoy - 13 años)
    SET @fecha_limite = DATEADD(YEAR, -13, @hoy);

    -- Validar que TODOS los usuarios insertados sean > 13 años
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE fecha_nacimiento > @fecha_limite
    )
    BEGIN
        RAISERROR('Error: El usuario debe ser mayor de 13 años para registrarse.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Si pasa la validación, insertar los registros normalmente
    INSERT INTO Usuario (
        email,
        password_hash,
        nickname,
        fecha_registro,
        fecha_nacimiento,
        pais,
        esta_activo
    )
    SELECT
        i.email,
        i.password_hash,
        i.nickname,
        i.fecha_registro,
        i.fecha_nacimiento,
        i.pais,
        i.esta_activo
    FROM inserted i;
END;
GO


-- PRUEBAS DE FUNCIONES

--PRINT '=== FUNCIÓN: fn_calcular_impuesto ===';
--SELECT dbo.fn_calcular_impuesto(100.00) AS Impuesto; -- Debe dar 16.00
--GO

--PRINT '=== FUNCIÓN: fn_clasificar_ingreso ===';
--SELECT dbo.fn_clasificar_ingreso(1500.00) AS Clasificacion; -- Debe dar Diamante
--SELECT dbo.fn_clasificar_ingreso(750.00) AS Clasificacion;  -- Debe dar Oro
--SELECT dbo.fn_clasificar_ingreso(250.00) AS Clasificacion;  -- Debe dar Plata
--GO

--PRINT '=== FUNCIÓN: fn_calcular_reputacion ===';
--SELECT dbo.fn_calcular_reputacion(1) AS Reputacion; -- Depende de los datos
--GO

--
---- PRUEBAS DE TRIGGERS
--
--PRINT '=== TRIGGER: trg_AuditoriaPrecios ===';
--PRINT 'Intentando aumentar precio al 100% (DEBE FALLAR):';
--UPDATE NivelSuscripcion SET precio_actual = precio_actual * 2 WHERE id = 1;
--GO

--PRINT 'Intentando aumentar precio al 30% (DEBE FUNCIONAR):';
--UPDATE NivelSuscripcion SET precio_actual = precio_actual * 1.3 WHERE id = 1;
--GO

--PRINT '=== TRIGGER: trg_ProteccionMenores ===';
--PRINT 'Intentando suscribir usuario a contenido NSFW (DEBE VALIDAR EDAD):';
--INSERT INTO Suscripcion (idUsuario, idNivel, fecha_inicio, fecha_renovacion, fecha_fin, estado, precio_pactado)
--VALUES (1, 1, GETDATE(), DATEADD(month,1,GETDATE()), DATEADD(month,1,GETDATE()), 'Activa', 10.00);
--GO

---- 1. ¿Hay al menos 250 usuarios? (A. Usuarios)
--SELECT COUNT(*) AS TotalUsuarios FROM Usuario;

---- 2. ¿Aprox. el 10% son creadores? (A. Usuarios)
--SELECT 'Usuarios Fans' AS Tipo, COUNT(*) FROM Usuario WHERE id NOT IN (SELECT idUsuario FROM Creador)
--UNION ALL
--SELECT 'Usuarios Creadores', COUNT(*) FROM Creador;

---- 3. ¿Mínimo 20 creadores y al menos 5 NSFW? (B. Creadores)
--SELECT COUNT(*) AS TotalCreadores FROM Creador;
--SELECT COUNT(*) AS CreadoresNSFW FROM Creador WHERE es_nsfw = 1;

---- 4. ¿Cada creador tiene entre 1 y 3 niveles? (C. Niveles)
--SELECT idCreador, COUNT(*) AS CantNiveles
--FROM NivelSuscripcion
--GROUP BY idCreador
--ORDER BY CantNiveles DESC; -- Revisa que ningún valor sea <1 o >3

---- 5. ¿Mínimo 800 publicaciones distribuidas? (D. Contenido)
--SELECT COUNT(*) AS TotalPublicaciones FROM Publicacion;
--SELECT tipo_contenido, COUNT(*) AS Cantidad FROM Publicacion GROUP BY tipo_contenido;

---- 6. ¿Mínimo 500 suscripciones? (E. Suscripciones)
--SELECT COUNT(*) AS TotalSuscripciones FROM Suscripcion;

---- 7. ¿Mínimo 1500 reacciones? (F. Interacciones)
--SELECT COUNT(*) AS TotalReacciones FROM UsuarioReaccionPublicacion;
---- ¿Mínimo 1000 comentarios?
--SELECT COUNT(*) AS TotalComentarios FROM Comentario;

---- 8. ¿Al menos 50 etiquetas? (H. Etiquetas)
--SELECT COUNT(*) AS TotalEtiquetas FROM Etiqueta;
--GO

---- Verificar creadores NSFW (mínimo 5)
--SELECT COUNT(*) AS [Creadores NSFW] FROM Creador WHERE es_nsfw = 1;

---- Verificar niveles por creador (1-3 cada uno)
--SELECT idCreador, COUNT(*) AS [Niveles]
--FROM NivelSuscripcion
--GROUP BY idCreador
--ORDER BY [Niveles] DESC;

---- Verificar publicaciones (mínimo 800)
--SELECT COUNT(*) AS [Total Publicaciones] FROM Publicacion;

---- Verificar distribución de tipos
--SELECT tipo_contenido, COUNT(*) AS Cantidad
--FROM Publicacion
--GROUP BY tipo_contenido;

---- Verificar suscripciones (mínimo 500)
--SELECT COUNT(*) AS [Total Suscripciones] FROM Suscripcion;

---- Verificar reacciones (mínimo 1500)
--SELECT COUNT(*) AS [Total Reacciones] FROM UsuarioReaccionPublicacion;

---- Verificar comentarios (mínimo 1000)
--SELECT COUNT(*) AS [Total Comentarios] FROM Comentario;

---- Verificar etiquetas (mínimo 50)
--SELECT COUNT(*) AS [Total Etiquetas] FROM Etiqueta;
