-- Entrega 2 - Inserción de datos adicionales
-- Dependencia: ejecutar después del esquema/tablas (Entrega 1 revisada)
USE libreria_db;

-- Más editoriales y autores (si no existen, pueden duplicarse: ajustar según entorno)
INSERT INTO Editorial (nombre) VALUES ('Alfaguara'), ('Debolsillo');

INSERT INTO Autor (nombre, apellido) VALUES
('Silvina','Ocampo'),('Ricardo','Piglia');

-- Libros adicionales
INSERT INTO Libro (titulo, anio_publicacion, precio, stock, id_editorial) VALUES
('Respiración artificial', 1980, 18000.00, 6, 5),
('Las invitadas', 2020, 21000.00, 4, 6);

-- Clientes adicionales
INSERT INTO Cliente (nombre, apellido, email, telefono, direccion) VALUES
('Carla','Domínguez','carla.dom@example.com','4444-4444','Av. Libros 1001');

-- Pedido con varias líneas y pagos parciales
INSERT INTO Pedido (id_cliente, fecha_pedido, estado) VALUES (LAST_INSERT_ID(), CURDATE(), 'pendiente');
SET @p := LAST_INSERT_ID();

INSERT INTO DetallePedido (id_pedido, id_libro, cantidad, precio_unitario) VALUES
(@p, 1, 1, 15999.90),
(@p, 2, 1, 17999.00);

INSERT INTO Pago (id_pedido, fecha_pago, monto, metodo) VALUES
(@p, CURDATE(), 15000.00, 'tarjeta'),
(@p, CURDATE(), (SELECT total FROM Pedido WHERE id_pedido=@p) - 15000.00, 'transferencia');
