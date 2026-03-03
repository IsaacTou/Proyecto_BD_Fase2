CREATE TABLE Usuario (
    id INT IDENTITY(1,1) PRIMARY KEY,
    email VARCHAR(320) NOT NULL CHECK (email LIKE '%_@__%.__%'), -- Expresion regular que garantiza que siga un estandar general del correo electronico
    password_hash VARCHAR(60) NOT NULL,
    nickname VARCHAR(50) NOT NULL,
    fecha_registro DATETIME2 NOT NULL DEFAULT GETDATE(),
    fecha_nacimiento DATE NOT NULL,
    pais VARCHAR(50) NOT NULL,
    esta_activo BIT NOT NULL
);

CREATE TABLE Creador (
    idUsuario INT PRIMARY KEY NOT NULL,
    biografia VARCHAR(320) NOT NULL,
    banco_nombre VARCHAR(50) NOT NULL,
    banco_cuenta VARCHAR(50) NOT NULL,
    es_nsfw BIT NOT NULL,
    idCategoria INT NOT NULL,

);

