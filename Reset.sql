USE FanHub;
GO

PRINT 'Iniciando borrado de tablas...';
GO

-- Función auxiliar para borrar solo si existe
IF OBJECT_ID('PublicacionEtiqueta', 'U') IS NOT NULL DROP TABLE PublicacionEtiqueta;
IF OBJECT_ID('UsuarioReaccionPublicacion', 'U') IS NOT NULL DROP TABLE UsuarioReaccionPublicacion;
IF OBJECT_ID('Factura', 'U') IS NOT NULL DROP TABLE Factura;
IF OBJECT_ID('Suscripcion', 'U') IS NOT NULL DROP TABLE Suscripcion;
IF OBJECT_ID('Comentario', 'U') IS NOT NULL DROP TABLE Comentario;
IF OBJECT_ID('Video', 'U') IS NOT NULL DROP TABLE Video;
IF OBJECT_ID('Texto', 'U') IS NOT NULL DROP TABLE Texto;
IF OBJECT_ID('Imagen', 'U') IS NOT NULL DROP TABLE Imagen;
IF OBJECT_ID('Publicacion', 'U') IS NOT NULL DROP TABLE Publicacion;
IF OBJECT_ID('MetodoPago', 'U') IS NOT NULL DROP TABLE MetodoPago;
IF OBJECT_ID('NivelSuscripcion', 'U') IS NOT NULL DROP TABLE NivelSuscripcion;
IF OBJECT_ID('Creador', 'U') IS NOT NULL DROP TABLE Creador;
IF OBJECT_ID('TipoReaccion', 'U') IS NOT NULL DROP TABLE TipoReaccion;
IF OBJECT_ID('Etiqueta', 'U') IS NOT NULL DROP TABLE Etiqueta;
IF OBJECT_ID('Usuario', 'U') IS NOT NULL DROP TABLE Usuario;
IF OBJECT_ID('Categoria', 'U') IS NOT NULL DROP TABLE Categoria;
GO

PRINT 'Todas las tablas han sido eliminadas correctamente';
GO