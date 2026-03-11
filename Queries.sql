USE [FanHub];
GO

-- CONSULTA 1: Clasificación de Ganancias
-- Columnas: Nickname, Categoria, Total Suscriptores Activos, Monto Facturado, Clasificación
SELECT 
    u.nickname,
    c.nombre AS Categoria,
    (SELECT COUNT(*) 
     FROM Suscripcion s 
     INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
     WHERE n.idCreador = cr.idUsuario 
       AND s.estado = 'Activa') AS [Total Suscriptores Activos],
    ISNULL((
        SELECT SUM(f.monto_total)
        FROM Factura f
        INNER JOIN Suscripcion s ON f.idSuscripcion = s.id
        INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
        WHERE n.idCreador = cr.idUsuario
          AND f.fecha_emision >= DATEADD(month, -1, GETDATE())
    ), 0) AS [Monto Facturado],
    dbo.fn_clasificar_ingreso(ISNULL((
        SELECT SUM(f.monto_total)
        FROM Factura f
        INNER JOIN Suscripcion s ON f.idSuscripcion = s.id
        INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
        WHERE n.idCreador = cr.idUsuario
          AND f.fecha_emision >= DATEADD(month, -1, GETDATE())
    ), 0)) AS Clasificacion
FROM Creador cr
INNER JOIN Usuario u ON cr.idUsuario = u.id
INNER JOIN Categoria c ON cr.idCategoria = c.id
ORDER BY [Monto Facturado] DESC;
GO

-- CONSULTA 2: Viralidad por Categoría
-- Columnas: Nombre Categoría, Título Publicación, Creador, Puntaje Máximo
WITH PuntajesPorPublicacion AS (
    SELECT 
        p.id,
        p.titulo,
        p.idCreador,
        cat.id AS idCategoria,
        cat.nombre AS NombreCategoria,
        u.nickname AS Creador,
        ((SELECT COUNT(*) FROM UsuarioReaccionPublicacion WHERE idPublicacion = p.id) * 1.5 +
         (SELECT COUNT(*) FROM Comentario WHERE idPublicacion = p.id) * 3) AS Puntaje
    FROM Publicacion p
    INNER JOIN Creador cr ON p.idCreador = cr.idUsuario
    INNER JOIN Usuario u ON cr.idUsuario = u.id
    INNER JOIN Categoria cat ON cr.idCategoria = cat.id
),
MaximosPorCategoria AS (
    SELECT 
        idCategoria,
        MAX(Puntaje) AS PuntajeMaximo
    FROM PuntajesPorPublicacion
    GROUP BY idCategoria
)
SELECT 
    pp.NombreCategoria AS [Nombre Categoría],
    pp.titulo AS [Título Publicación],
    pp.Creador,
    pp.Puntaje AS [Puntaje Máximo]
FROM PuntajesPorPublicacion pp
INNER JOIN MaximosPorCategoria mc 
    ON pp.idCategoria = mc.idCategoria 
    AND pp.Puntaje = mc.PuntajeMaximo
ORDER BY pp.NombreCategoria;
GO

-- CONSULTA 3: Análisis de Dominios de Correo
-- Columnas: Dominio, Cantidad Usuarios
SELECT 
    SUBSTRING(email, CHARINDEX('@', email) + 1, LEN(email)) AS Dominio,
    COUNT(*) AS [Cantidad Usuarios]
FROM Usuario
GROUP BY SUBSTRING(email, CHARINDEX('@', email) + 1, LEN(email))
HAVING COUNT(*) > 10
ORDER BY [Cantidad Usuarios] DESC;
GO

-- CONSULTA 4: Promedio de Retención (Churn)
-- Columnas: Nickname Creador, Nombre Nivel, Promedio Días
SELECT 
    u.nickname AS [Nickname Creador],
    n.nombre AS [Nombre Nivel],
    AVG(DATEDIFF(day, s.fecha_inicio, s.fecha_fin)) AS [Promedio Días]
FROM Suscripcion s
INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
INNER JOIN Creador c ON n.idCreador = c.idUsuario
INNER JOIN Usuario u ON c.idUsuario = u.id
WHERE s.estado = 'Cancelada'
GROUP BY u.nickname, n.nombre, n.orden
ORDER BY n.orden;
GO

-- CONSULTA 5: Tiempo y Peso de Contenido (Gaming)
-- Columnas: Nickname, Tiempo Total Formateado, Estimación GB
SELECT 
    u.nickname,
    CONCAT(
        SUM(v.duracion_seg) / 3600, 'h ',
        (SUM(v.duracion_seg) % 3600) / 60, 'm'
    ) AS [Tiempo Total Formateado],
    ROUND(SUM(
        CASE v.resolucion
            WHEN '4K' THEN (v.duracion_seg / 60.0) * 0.5
            WHEN '1080p' THEN (v.duracion_seg / 60.0) * 0.1
            ELSE (v.duracion_seg / 60.0) * 0.05
        END
    ), 2) AS [Estimación GB]
FROM Video v
INNER JOIN Publicacion p ON v.idPublicacion = p.id
INNER JOIN Creador cr ON p.idCreador = cr.idUsuario
INNER JOIN Usuario u ON cr.idUsuario = u.id
INNER JOIN Categoria cat ON cr.idCategoria = cat.id
WHERE cat.nombre = 'Gaming'
GROUP BY u.nickname
ORDER BY [Estimación GB] DESC;
GO

-- CONSULTA 6: Mapa de Calor Financiero
-- Columnas: País, Total Facturado, Share %
SELECT 
    u.pais,
    SUM(f.monto_total) AS [Total Facturado],
    CONCAT(
        ROUND(SUM(f.monto_total) * 100.0 / (SELECT SUM(monto_total) FROM Factura), 1),
        '%'
    ) AS [Share %]
FROM Usuario u
INNER JOIN Suscripcion s ON u.id = s.idUsuario
INNER JOIN Factura f ON s.id = f.idSuscripcion
GROUP BY u.pais
ORDER BY [Total Facturado] DESC;
GO

-- CONSULTA 7: Intereses Cruzados (Tecnología Y Fitness)
-- Columnas: Nickname Usuario, Gasto Total Histórico
SELECT 
    u.nickname AS [Nickname Usuario],
    SUM(f.monto_total) AS [Gasto Total Histórico]
FROM Usuario u
INNER JOIN Suscripcion s ON u.id = s.idUsuario
INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
INNER JOIN Creador cr ON n.idCreador = cr.idUsuario
INNER JOIN Categoria cat ON cr.idCategoria = cat.id
INNER JOIN Factura f ON s.id = f.idSuscripcion
WHERE cat.nombre IN ('Tecnología', 'Fitness')
GROUP BY u.id, u.nickname
HAVING 
    SUM(CASE WHEN cat.nombre = 'Tecnología' THEN 1 ELSE 0 END) > 0
    AND SUM(CASE WHEN cat.nombre = 'Fitness' THEN 1 ELSE 0 END) > 0
    AND SUM(f.monto_total) > 140
ORDER BY [Gasto Total Histórico] DESC;
GO

-- CONSULTA 8: Generaciones
-- Columnas: Generación, Cantidad Usuarios Activos, Gasto Promedio Mensual
SELECT 
    CASE 
        WHEN YEAR(u.fecha_nacimiento) > 2000 THEN 'Gen Z'
        WHEN YEAR(u.fecha_nacimiento) BETWEEN 1981 AND 2000 THEN 'Millennials'
        ELSE 'Gen X'
    END AS Generación,
    COUNT(DISTINCT u.id) AS [Cantidad Usuarios Activos],
    AVG(s.precio_pactado) AS [Gasto Promedio Mensual]
FROM Usuario u
INNER JOIN Suscripcion s ON u.id = s.idUsuario
WHERE s.estado = 'Activa'
GROUP BY 
    CASE 
        WHEN YEAR(u.fecha_nacimiento) > 2000 THEN 'Gen Z'
        WHEN YEAR(u.fecha_nacimiento) BETWEEN 1981 AND 2000 THEN 'Millennials'
        ELSE 'Gen X'
    END;
GO

-- CONSULTA 9: Creadores Polémicos (Ratio > 2.0)
-- Columnas: Nickname, Cantidad Posts Evaluados, Ratio Promedio
WITH PublicacionStats AS (
    SELECT 
        p.idCreador,
        p.id AS idPublicacion,
        ISNULL((SELECT COUNT(*) FROM Comentario c WHERE c.idPublicacion = p.id), 0) AS TotalComentarios,
        ISNULL((SELECT COUNT(*) FROM UsuarioReaccionPublicacion ur WHERE ur.idPublicacion = p.id), 0) AS TotalReacciones
    FROM Publicacion p
),
CreadorStats AS (
    SELECT 
        ps.idCreador,
        COUNT(DISTINCT ps.idPublicacion) AS CantidadPosts,
        AVG(
            CASE 
                WHEN ps.TotalReacciones > 0 
                THEN CAST(ps.TotalComentarios AS FLOAT) / CAST(ps.TotalReacciones AS FLOAT)
                ELSE NULL  -- Evita división por cero
            END
        ) AS RatioPromedio
    FROM PublicacionStats ps
    GROUP BY ps.idCreador
)
SELECT 
    u.nickname,
    cs.CantidadPosts AS [Cantidad Posts Evaluados],
    cs.RatioPromedio AS [Ratio Promedio]
FROM CreadorStats cs
INNER JOIN Creador cr ON cs.idCreador = cr.idUsuario
INNER JOIN Usuario u ON cr.idUsuario = u.id
WHERE cs.RatioPromedio > 2.0
ORDER BY cs.RatioPromedio DESC;
GO

-- CONSULTA 10: Ranking de Creadores (Reputación)
-- Columnas: Nickname, Total Suscriptores, Puntaje Reputación
SELECT 
    u.nickname,
    (SELECT COUNT(DISTINCT s.idUsuario)
     FROM Suscripcion s
     INNER JOIN NivelSuscripcion n ON s.idNivel = n.id
     WHERE n.idCreador = cr.idUsuario AND s.estado = 'Activa') AS [Total Suscriptores],
    dbo.fn_calcular_reputacion(cr.idUsuario) AS [Puntaje Reputación]
FROM Creador cr
INNER JOIN Usuario u ON cr.idUsuario = u.id
WHERE cr.es_nsfw = 0
  AND EXISTS (
      SELECT 1 FROM Publicacion p 
      WHERE p.idCreador = cr.idUsuario 
        AND p.tipo_contenido IN ('VIDEO', 'IMAGEN')
  )
ORDER BY [Puntaje Reputación] DESC;
GO

-- CONSULTA 11: Usuarios "Lurkers"
-- Columnas: Nickname, Fecha Última Suscripción, Monto Gastado
SELECT 
    u.nickname,
    COALESCE(MAX(s.fecha_renovacion), MAX(s.fecha_inicio)) AS [Fecha Última Suscripción],
    ISNULL(SUM(f.monto_total), 0) AS [Monto Gastado]
FROM Usuario u
INNER JOIN Suscripcion s ON u.id = s.idUsuario
LEFT JOIN Factura f ON s.id = f.idSuscripcion
WHERE s.estado = 'Activa'
  AND NOT EXISTS (SELECT 1 FROM Comentario c WHERE c.idUsuario = u.id)
  AND NOT EXISTS (SELECT 1 FROM UsuarioReaccionPublicacion ur WHERE ur.idUsuario = u.id)
GROUP BY u.nickname
ORDER BY [Monto Gastado] DESC;
GO

-- CONSULTA 12: Tendencias (Tags) - Top 3
-- Columnas: Nombre Etiqueta, Cantidad Publicaciones
SELECT TOP 3
    e.nombre AS [Nombre Etiqueta],
    COUNT(*) AS [Cantidad Publicaciones]
FROM Etiqueta e
INNER JOIN PublicacionEtiqueta pe ON e.id = pe.idEtiqueta
INNER JOIN Publicacion p ON pe.idPublicacion = p.id
WHERE p.fecha_publicacion >= DATEADD(month, -1, GETDATE())
GROUP BY e.nombre
ORDER BY [Cantidad Publicaciones] DESC;
GO

-- CONSULTA 13: Cobertura Total de Reacciones
-- Columnas: Nickname, Total Reacciones Realizadas
SELECT 
    u.nickname,
    COUNT(*) AS [Total Reacciones Realizadas]
FROM Usuario u
INNER JOIN UsuarioReaccionPublicacion ur ON u.id = ur.idUsuario
WHERE u.id IN (
    SELECT ur2.idUsuario
    FROM UsuarioReaccionPublicacion ur2
    GROUP BY ur2.idUsuario
    HAVING COUNT(DISTINCT ur2.idTipoReaccion) = (SELECT COUNT(*) FROM TipoReaccion)
)
GROUP BY u.nickname
ORDER BY [Total Reacciones Realizadas] DESC;
GO

-- CONSULTA 14: Reporte de Nómina (Liquidación)
-- Columnas: Nombre Banco, Cuenta Bancaria, Beneficiario, Total Facturado, Comisión, Neto
SELECT 
    cr.banco_nombre AS [Nombre Banco],
    cr.banco_cuenta AS [Cuenta Bancaria],
    u.nickname AS Beneficiario,
    SUM(f.monto_total) AS [Total Facturado],
    SUM(f.monto_total) * 0.20 AS [Comisión FanHub],
    SUM(f.monto_total) * 0.80 AS [Monto a Transferir]
FROM Creador cr
INNER JOIN Usuario u ON cr.idUsuario = u.id
INNER JOIN NivelSuscripcion n ON cr.idUsuario = n.idCreador
INNER JOIN Suscripcion s ON n.id = s.idNivel
INNER JOIN Factura f ON s.id = f.idSuscripcion
WHERE s.estado = 'Activa'
  AND MONTH(f.fecha_emision) = MONTH(GETDATE())
  AND YEAR(f.fecha_emision) = YEAR(GETDATE())
GROUP BY cr.banco_nombre, cr.banco_cuenta, u.nickname
ORDER BY [Monto a Transferir] DESC;
GO