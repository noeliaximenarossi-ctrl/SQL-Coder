-- Proyecto: Base de datos para Librería Online
-- Alumna: Noelia Rossi



-- ========================
-- CREACIÓN DE ESQUEMA
-- ========================
CREATE DATABASE IF NOT EXISTS libreria_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE libreria_db;

-- ========================
--  TABLA: Cliente
-- ========================
CREATE TABLE IF NOT EXISTS Cliente (
  id_cliente INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  telefono VARCHAR(20),
  direccion VARCHAR(200),
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE INDEX idx_cliente_apellido ON Cliente(apellido);

-- ========================
--  TABLA: Autor
-- ========================
CREATE TABLE IF NOT EXISTS Autor (
  id_autor INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE INDEX idx_autor_apellido ON Autor(apellido);

-- ========================
--  TABLA: Editorial
-- ========================
CREATE TABLE IF NOT EXISTS Editorial (
  id_editorial INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ========================
--  TABLA: Libro
-- ========================
CREATE TABLE IF NOT EXISTS Libro (
  id_libro INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(200) NOT NULL,
  anio_publicacion YEAR,
  precio DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  stock INT NOT NULL DEFAULT 0,
  id_editorial INT,
  FOREIGN KEY (id_editorial) REFERENCES Editorial(id_editorial)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_libro_titulo ON Libro(titulo);
CREATE INDEX idx_libro_editorial ON Libro(id_editorial);

-- ================================
--  TABLA: LibroAutor (N:M)
-- ================================
CREATE TABLE IF NOT EXISTS LibroAutor (
  id_libro INT NOT NULL,
  id_autor INT NOT NULL,
  PRIMARY KEY (id_libro, id_autor),
  FOREIGN KEY (id_libro) REFERENCES Libro(id_libro)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  FOREIGN KEY (id_autor) REFERENCES Autor(id_autor)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ========================
--  TABLA: Pedido
-- ========================
CREATE TABLE IF NOT EXISTS Pedido (
  id_pedido INT AUTO_INCREMENT PRIMARY KEY,
  id_cliente INT NOT NULL,
  fecha_pedido DATE NOT NULL,
  estado ENUM('pendiente','enviado','entregado') NOT NULL DEFAULT 'pendiente',
  total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE INDEX idx_pedido_cliente ON Pedido(id_cliente);
CREATE INDEX idx_pedido_estado ON Pedido(estado);

-- ========================
--  TABLA: DetallePedido
-- ========================
CREATE TABLE IF NOT EXISTS DetallePedido (
  id_detalle INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  id_libro INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(12,2) AS (cantidad * precio_unitario) STORED,
  FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  FOREIGN KEY (id_libro) REFERENCES Libro(id_libro)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE INDEX idx_detalle_pedido ON DetallePedido(id_pedido);
CREATE INDEX idx_detalle_libro ON DetallePedido(id_libro);

-- ========================
--  TRIGGERS: Actualizar total del pedido
-- ========================
DELIMITER $$
CREATE TRIGGER trg_detallepedido_ai
AFTER INSERT ON DetallePedido
FOR EACH ROW
BEGIN
  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.subtotal),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = NEW.id_pedido;
END$$

CREATE TRIGGER trg_detallepedido_au
AFTER UPDATE ON DetallePedido
FOR EACH ROW
BEGIN
  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.subtotal),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = NEW.id_pedido;
END$$

CREATE TRIGGER trg_detallepedido_ad
AFTER DELETE ON DetallePedido
FOR EACH ROW
BEGIN
  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.subtotal),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = OLD.id_pedido;
END$$
DELIMITER ;

-- ========================
--  TABLA: Pago
-- ========================
CREATE TABLE IF NOT EXISTS Pago (
  id_pago INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  fecha_pago DATE NOT NULL,
  monto DECIMAL(10,2) NOT NULL,
  metodo ENUM('tarjeta','transferencia','efectivo') NOT NULL,
  FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_pago_pedido ON Pago(id_pedido);
CREATE INDEX idx_pago_fecha ON Pago(fecha_pago);

-- ========================
--  VISTA (opcional): Resumen de ventas por cliente
-- ========================
CREATE OR REPLACE VIEW v_ventas_cliente AS
SELECT
  c.id_cliente,
  CONCAT(c.nombre, ' ', c.apellido) AS cliente,
  COUNT(DISTINCT p.id_pedido) AS pedidos,
  COALESCE(SUM(p.total),0) AS total_comprado
FROM Cliente c
LEFT JOIN Pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, cliente;

-- ========================
--  EJEMPLOS DE DATOS (opcionales para pruebas)
-- ========================
INSERT INTO Editorial (nombre) VALUES ('Planeta'), ('Penguin Random House');
INSERT INTO Autor (nombre, apellido) VALUES ('Julio','Cortázar'),('Gabriel','García Márquez');
INSERT INTO Libro (titulo, anio_publicacion, precio, stock, id_editorial)
VALUES ('Rayuela', 1963, 15999.90, 10, 1),
       ('Cien años de soledad', 1967, 17999.00, 7, 2);
INSERT INTO LibroAutor (id_libro, id_autor) VALUES (1,1),(2,2);

INSERT INTO Cliente (nombre, apellido, email, telefono, direccion)
VALUES ('Ana','Pérez','ana.perez@example.com','1111-1111','Av. Siempreviva 123'),
       ('Luis','Gómez','luis.gomez@example.com','2222-2222','Calle Falsa 456');

INSERT INTO Pedido (id_cliente, fecha_pedido, estado) VALUES (1, CURDATE(), 'pendiente');
INSERT INTO DetallePedido (id_pedido, id_libro, cantidad, precio_unitario) VALUES (1,1,1,15999.90);
INSERT INTO Pago (id_pedido, fecha_pago, monto, metodo) VALUES (1, CURDATE(), 15999.90, 'tarjeta');
