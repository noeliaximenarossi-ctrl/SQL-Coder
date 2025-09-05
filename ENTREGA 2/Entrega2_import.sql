-- Entrega2_import.sql
-- Importación de datos por CSV (MySQL 8+)
-- Requisitos:
-- 1) Haber ejecutado IdeaRossi_Ent1_revisada.sql (esquema y tablas).
-- 2) Habilitar local infile si corresponde:
--    * Cliente: mysql --local-infile=1 -u usuario -p
--    * Servidor (si aplica): SET GLOBAL local_infile=1;
-- 3) Ajustar las rutas a los CSV (reemplazar PATH).

USE libreria_db;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Pago;
TRUNCATE TABLE DetallePedido;
TRUNCATE TABLE LibroAutor;
TRUNCATE TABLE Pedido;
TRUNCATE TABLE Libro;
TRUNCATE TABLE Autor;
TRUNCATE TABLE Editorial;
TRUNCATE TABLE Cliente;
SET FOREIGN_KEY_CHECKS = 1;

-- IMPORTACIÓN
SET FOREIGN_KEY_CHECKS = 0;

LOAD DATA LOCAL INFILE 'PATH/Editorial.csv'
INTO TABLE Editorial
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_editorial, nombre);

LOAD DATA LOCAL INFILE 'PATH/Autor.csv'
INTO TABLE Autor
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_autor, nombre, apellido);

LOAD DATA LOCAL INFILE 'PATH/Libro.csv'
INTO TABLE Libro
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_libro, titulo, anio_publicacion, precio, stock, id_editorial);

LOAD DATA LOCAL INFILE 'PATH/Cliente.csv'
INTO TABLE Cliente
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_cliente, nombre, apellido, email, telefono, direccion);

LOAD DATA LOCAL INFILE 'PATH/LibroAutor.csv'
INTO TABLE LibroAutor
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_libro, id_autor);

LOAD DATA LOCAL INFILE 'PATH/Pedido.csv'
INTO TABLE Pedido
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_pedido, id_cliente, fecha_pedido, estado, @total)
SET total = 0.00;

LOAD DATA LOCAL INFILE 'PATH/DetallePedido.csv'
INTO TABLE DetallePedido
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_detalle, id_pedido, id_libro, cantidad, precio_unitario);

LOAD DATA LOCAL INFILE 'PATH/Pago.csv'
INTO TABLE Pago
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id_pago, id_pedido, fecha_pago, monto, metodo);

SET FOREIGN_KEY_CHECKS = 1;

-- Verificación rápida
SELECT 'Editorial' AS tabla, COUNT(*) AS filas FROM Editorial
UNION ALL SELECT 'Autor', COUNT(*) FROM Autor
UNION ALL SELECT 'Libro', COUNT(*) FROM Libro
UNION ALL SELECT 'Cliente', COUNT(*) FROM Cliente
UNION ALL SELECT 'LibroAutor', COUNT(*) FROM LibroAutor
UNION ALL SELECT 'Pedido', COUNT(*) FROM Pedido
UNION ALL SELECT 'DetallePedido', COUNT(*) FROM DetallePedido
UNION ALL SELECT 'Pago', COUNT(*) FROM Pago;

-- Validación del total por triggers
SELECT p.id_pedido, p.total AS total_pedido,
       (SELECT SUM(subtotal) FROM DetallePedido d WHERE d.id_pedido=p.id_pedido) AS sum_subtotal
FROM Pedido p
ORDER BY p.id_pedido;
