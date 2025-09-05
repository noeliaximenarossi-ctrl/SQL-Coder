-- IdeaRossi_Ent1_revisada.sql
-- Proyecto: Base de datos para Librería Online
-- Alumna: Noelia Rossi
-- Motor: MySQL 8+ (InnoDB, utf8mb4)
-- Revisión según feedback docente (22-ago-2025):
--   (1) Casos de prueba (datos semilla) para validar consultas y lógica de negocio.
--   (2) Notas de normalización/denormalización (modelo en 3FN; total de Pedido mantenido por trigger como denormalización controlada).
--   (3) Consideraciones de performance: índices compuestos, cobertura para consultas típicas y notas de particionamiento futuro.
--   (4) Se mantienen comentarios habilitados en el archivo (sugerencia de formato).

/* =========================
   NOTAS DE NORMALIZACIÓN
   =========================
   - Cada tabla representa una entidad única (Cliente, Autor, Editorial, Libro, Pedido, DetallePedido, Pago).
   - No hay dependencias parciales ni transitivas sobre claves no primarias ⇒ 3FN (Tercera Forma Normal).
   - Relación N:M entre Libro y Autor se resuelve con tabla puente LibroAutor (PK compuesta).
   - Denormalización controlada: campo calculado "subtotal" en DetallePedido (GENERATED) y
     acumulación de "total" en Pedido mantenida por triggers de DetallePedido (evita recalcular en cada consulta).
*/

/* ==================================
   CONSIDERACIONES DE PERFORMANCE
   ==================================
   - Índices simples existentes:
       * Cliente(apellido)
       * Autor(apellido)
       * Libro(titulo), Libro(id_editorial)
       * Pedido(id_cliente), Pedido(estado)
       * DetallePedido(id_pedido), DetallePedido(id_libro)
       * Pago(id_pedido), Pago(fecha_pago)
   - Índices compuestos agregados en esta revisión (patterns comunes):
       * DetallePedido(id_pedido, id_libro)  -- filtros por pedido y análisis de líneas
       * Pedido(id_cliente, fecha_pedido)    -- listados del cliente por rango de fechas
       * Pago(id_pedido, fecha_pago)         -- conciliación por pedido y período
   - Si el volumen crece: evaluar particionamiento por RANGE en Pedido/Pago por fecha.
   - Charset/collation utf8mb4 para compatibilidad con caracteres acentuados.
*/

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
DROP TABLE IF EXISTS Cliente;
CREATE TABLE Cliente (
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
DROP TABLE IF EXISTS Autor;
CREATE TABLE Autor (
  id_autor INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE INDEX idx_autor_apellido ON Autor(apellido);

-- ========================
--  TABLA: Editorial
-- ========================
DROP TABLE IF EXISTS Editorial;
CREATE TABLE Editorial (
  id_editorial INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ========================
--  TABLA: Libro
-- ========================
DROP TABLE IF EXISTS Libro;
CREATE TABLE Libro (
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
DROP TABLE IF EXISTS LibroAutor;
CREATE TABLE LibroAutor (
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
DROP TABLE IF EXISTS Pedido;
CREATE TABLE Pedido (
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
-- Índice compuesto sugerido para listados por cliente+fecha
CREATE INDEX idx_pedido_cliente_fecha ON Pedido(id_cliente, fecha_pedido);

-- ========================
--  TABLA: DetallePedido
-- ========================
DROP TABLE IF EXISTS DetallePedido;
CREATE TABLE DetallePedido (
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
-- Índice compuesto sugerido para búsquedas por línea en un pedido
CREATE INDEX idx_detalle_pedido_libro ON DetallePedido(id_pedido, id_libro);

-- ========================
--  TRIGGERS: Actualizar total del pedido
-- ========================
DROP TRIGGER IF EXISTS trg_detallepedido_ai;
DROP TRIGGER IF EXISTS trg_detallepedido_au;
DROP TRIGGER IF EXISTS trg_detallepedido_ad;

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
DROP TABLE IF EXISTS Pago;
CREATE TABLE Pago (
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
-- Índice compuesto sugerido para conciliación por pedido+fecha
CREATE INDEX idx_pago_pedido_fecha ON Pago(id_pedido, fecha_pago);

/* =========================
   CASOS DE PRUEBA (SEED)
   =========================
   - Objetivo: disponer de datos mínimos para probar SELECT, JOIN, triggers y reportes.
   - Envuelto en una transacción para revertir fácilmente si es necesario.
*/
START TRANSACTION;

-- Editoriales
INSERT INTO Editorial (nombre) VALUES
  ('Planeta'), ('Penguin Random House'), ('Siglo XXI'), ('Anagrama');

-- Autores
INSERT INTO Autor (nombre, apellido) VALUES
  ('Julio','Cortázar'),
  ('Gabriel','García Márquez'),
  ('Mariana','Enríquez'),
  ('Samanta','Schweblin');

-- Libros
INSERT INTO Libro (titulo, anio_publicacion, precio, stock, id_editorial) VALUES
  ('Rayuela', 1963, 15999.90, 10, 1),
  ('Cien años de soledad', 1967, 17999.00, 7, 2),
  ('Nuestra parte de noche', 2019, 22000.00, 5, 3),
  ('Distancia de rescate', 2014, 14000.00, 8, 4);

-- Relación Libro-Autor
INSERT INTO LibroAutor (id_libro, id_autor) VALUES
  (1,1),  -- Rayuela - Cortázar
  (2,2),  -- Cien años - GGM
  (3,3),  -- Nuestra parte - Enríquez
  (4,4);  -- Distancia - Schweblin

-- Clientes
INSERT INTO Cliente (nombre, apellido, email, telefono, direccion) VALUES
  ('Ana','Pérez','ana.perez@example.com','1111-1111','Av. Siempreviva 123'),
  ('Luis','Gómez','luis.gomez@example.com','2222-2222','Calle Falsa 456'),
  ('Noelia','Rossi','noelia.rossi@example.com','3333-3333','Calle del Buen Libro 789');

-- Pedido de Ana
INSERT INTO Pedido (id_cliente, fecha_pedido, estado) VALUES (1, CURDATE(), 'pendiente');
INSERT INTO DetallePedido (id_pedido, id_libro, cantidad, precio_unitario) VALUES
  (LAST_INSERT_ID(), 1, 1, 15999.90),
  (LAST_INSERT_ID(), 4, 2, 14000.00);
-- Pago parcial y total
INSERT INTO Pago (id_pedido, fecha_pago, monto, metodo) VALUES
  (1, CURDATE(), 10000.00, 'tarjeta'),
  (1, CURDATE(), 33999.90 - 10000.00, 'transferencia');

-- Pedido de Noelia
INSERT INTO Pedido (id_cliente, fecha_pedido, estado) VALUES (3, CURDATE(), 'pendiente');
INSERT INTO DetallePedido (id_pedido, id_libro, cantidad, precio_unitario) VALUES
  (LAST_INSERT_ID(), 3, 1, 22000.00);
INSERT INTO Pago (id_pedido, fecha_pago, monto, metodo) VALUES
  (2, CURDATE(), 22000.00, 'efectivo');

COMMIT;

/* =========================
   CONSULTAS DE VERIFICACIÓN
   =========================
   -- Compras por cliente
   SELECT c.id_cliente, CONCAT(c.nombre,' ',c.apellido) AS cliente, COUNT(p.id_pedido) pedidos, SUM(p.total) total
   FROM Cliente c LEFT JOIN Pedido p ON p.id_cliente=c.id_cliente
   GROUP BY c.id_cliente, cliente;

   -- Líneas de pedido
   SELECT dp.id_pedido, l.titulo, dp.cantidad, dp.precio_unitario, dp.subtotal
   FROM DetallePedido dp JOIN Libro l ON l.id_libro=dp.id_libro
   ORDER BY dp.id_pedido;

   -- Conciliación de pagos por pedido
   SELECT id_pedido, SUM(monto) pagado FROM Pago GROUP BY id_pedido;
*/
