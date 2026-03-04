
CREATE TABLE Usuario (
    id INT IDENTITY(1,1) PRIMARY KEY,
    email VARCHAR(320) NOT NULL CHECK (email LIKE '%_@__%.__%'),
    password_hash VARCHAR(60) NOT NULL,
    nickname VARCHAR(50) NOT NULL UNIQUE,
    fecha_registro DATETIME2 NOT NULL DEFAULT GETDATE(),
    fecha_nacimiento DATE NOT NULL,
    pais VARCHAR(50) NOT NULL,
    esta_activo BIT NOT NULL
);

CREATE TABLE Categoria (
    id INT PRIMARY KEY NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    descripcion VARCHAR(320) NOT NULL
);

CREATE TABLE Creador (
    idUsuario INT PRIMARY KEY NOT NULL,
    biografia VARCHAR(320) NOT NULL,
    banco_nombre VARCHAR(50) NOT NULL,
    banco_cuenta VARCHAR(50) NOT NULL,
    es_nsfw BIT NOT NULL,
    idCategoria INT NOT NULL,
    FOREIGN KEY (idUsuario) REFERENCES  Usuario(id),
    FOREIGN KEY (idCategoria) REFERENCES Categoria(id)
);

CREATE TABLE MetodoPago (
    id INT IDENTITY(1,1),
    idUsuario INT NOT NULL,
    ultimos_4_digitos CHAR(4) NOT NULL,
    marca VARCHAR(30) NOT NULL,
    titular VARCHAR(30) NOT NULL,
    fecha_expiracion DATE NOT NULL,
    es_predeterminado BIT NOT NULL,
    PRIMARY KEY (id,idUsuario),
    FOREIGN KEY (idUsuario) REFERENCES Usuario(id)
);

CREATE TABLE NivelSucripcion (
    id INT IDENTITY(1,1) PRIMARY KEY,
    idCreador INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    descripcion VARCHAR(320) NOT NULL,
    precio_actual DECIMAL(10,2) NOT NULL CHECK (precio_actual >= 0),
    esta_activo BIT NOT NULL,
    orden TINYINT NOT NULL,
    FOREIGN KEY (idCreador) REFERENCES Creador(idUsuario)
);

CREATE TABLE Suscripcion (
    id INT IDENTITY(1,1) PRIMARY KEY,
    idUsuario INT NOT NULL,
    idNivel INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_renovacion DATE,
    fecha_fin DATE NOT NULL,
    estado VARCHAR(9) NOT NULL CHECK (estado IN ('Activa', 'Cancelada', 'Vencida')),
    precio_pactado DECIMAL(10,2) NOT NULL CHECK (precio_pactado >= 0),
    FOREIGN KEY(idUsuario) REFERENCES Usuario(id),
    FOREIGN KEY(idNivel) REFERENCES NivelSucripcion(id)
);

CREATE TABLE Factura (
    id INT IDENTITY (1,1) PRIMARY KEY,
    idSuscripcion INT NOT NULL,
    codigo_transaccion VARCHAR(32) NOT NULL,
    fecha_emision DATETIME2 NOT NULL,
    sub_total DECIMAL(10,2) NOT NULL CHECK (sub_total >= 0),
    monto_impuesto DECIMAL(10,2) NOT NULL CHECK (monto_impuesto >= 0),
    monto_total DECIMAL(10,2) NOT NULL CHECK (monto_total >= 0),
    FOREIGN KEY (idSuscripcion) REFERENCES Suscripcion(id)
);

CREATE TABLE Publicacion (
    id INT IDENTITY (1,1) PRIMARY KEY,
    idCreador INT NOT NULL,
    titulo NVARCHAR(60) NOT NULL,
    fecha_publicacion DATETIME2 NOT NULL,
    es_publica BIT NOT NULL,
    tipo_contenido VARCHAR(6) NOT NULL CHECK (tipo_contenido IN ('VIDEO', 'TEXTO', 'IMAGEN')),
    FOREIGN KEY (idCreador) REFERENCES Creador (idUsuario)
);

CREATE TABLE Video (
    idPublicacion INT PRIMARY KEY NOT NULL,
    duracion_seg INT NOT NULL,
    resolucion VARCHAR(5) NOT NULL CHECK (resolucion IN ('720p', '1080p', '4K')),
    url_stream VARCHAR(100) NOT NULL,
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id)
);

CREATE TABLE Texto (
    idPublicacion INT PRIMARY KEY NOT NULL,
    contenido_html NVARCHAR(MAX) NOT NULL,
    resumen_gratuito VARCHAR(500) NOT NULL,
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id)
);

CREATE TABLE Imagen (
    idPublicacion INT PRIMARY KEY NOT NULL,
    ancho INT NOT NULL,
    alto INT NOT NULL,
    formato VARCHAR(30) NOT NULL,
    alt_text NVARCHAR(255),
    url_imagen VARCHAR(100) NOT NULL,
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id)
);

CREATE TABLE Comentario (
    id INT PRIMARY KEY NOT NULL,
    idUsuario INT NOT NULL,
    idPublicacion INT NOT NULL,
    idComentarioPadre INT,
    texto NVARCHAR(255) NOT NULL,
    fecha DATETIME2 NOT NULL,
    FOREIGN KEY (idUsuario) REFERENCES Usuario(id),
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id),
    FOREIGN KEY (idComentarioPadre) REFERENCES Comentario(id)
);

CREATE TABLE TipoReaccion (
    id INT PRIMARY KEY NOT NULL,
    nombre NVARCHAR(30) NOT NULL,
    emoji_code NVARCHAR(10) NOT NULL
);

CREATE TABLE UsuarioReaccionPublicacion (
    idUsuario INT NOT NULL,
    idPublicacion INT NOT NULL,
    idTipoReaccion INT NOT NULL,
    fecha_reaccion DATETIME2 NOT NULL,
    PRIMARY KEY (idUsuario, idPublicacion),
    FOREIGN KEY (idUsuario) REFERENCES Usuario(id),
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id),
    FOREIGN KEY (idTipoReaccion) REFERENCES TipoReaccion(id)
);

CREATE TABLE Etiqueta (
    id INT PRIMARY KEY NOT NULL,
    nombre NVARCHAR(30) NOT NULL
);

CREATE TABLE PublicacionEtiqueta (
    idPublicacion INT NOT NULL,
    idEtiqueta INT NOT NULL,
    PRIMARY KEY (idPublicacion,idEtiqueta),
    FOREIGN KEY (idPublicacion) REFERENCES Publicacion(id),
    FOREIGN KEY (idEtiqueta) REFERENCES Etiqueta(id)
);
