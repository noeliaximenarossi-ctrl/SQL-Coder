-- Entrega 2 - Objetos (Vistas, Funciones, Stored Procedures, Triggers)
-- Dependencia: ejecutar antes IdeaRossi_Ent1_revisada.sql (esquema y tablas)
USE libreria_db;

-- ======================
-- VISTAS
-- ======================
CREATE OR REPLACE VIEW v_ventas_cliente AS
SELECT
  c.id_cliente,
  CONCAT(c.nombre,' ',c.apellido) AS cliente,
  COUNT(DISTINCT p.id_pedido) AS cantidad_pedidos,
  COALESCE(SUM(p.total),0) AS total_comprado
FROM Cliente c
LEFT JOIN Pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, cliente;

CREATE OR REPLACE VIEW v_libros_stock AS
SELECT
  l.id_libro, l.titulo, l.stock, e.nombre AS editorial
FROM Libro l
JOIN Editorial e ON e.id_editorial = l.id_editorial;

CREATE OR REPLACE VIEW v_pedidos_detallados AS
SELECT
  p.id_pedido, p.fecha_pedido, p.estado, p.total,
  c.id_cliente, CONCAT(c.nombre,' ',c.apellido) AS cliente,
  dp.id_detalle, dp.cantidad, dp.precio_unitario, dp.subtotal,
  l.id_libro, l.titulo
FROM Pedido p
JOIN Cliente c ON c.id_cliente = p.id_cliente
JOIN DetallePedido dp ON dp.id_pedido = p.id_pedido
JOIN Libro l ON l.id_libro = dp.id_libro;

-- ======================
-- FUNCIONES (UDF)
-- ======================
DROP FUNCTION IF EXISTS fn_total_pedidos_cliente;
DELIMITER //
CREATE FUNCTION fn_total_pedidos_cliente(p_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
  DECLARE v_total DECIMAL(12,2);
  SELECT COALESCE(SUM(total),0) INTO v_total
  FROM Pedido WHERE id_cliente = p_id;
  RETURN v_total;
END//
DELIMITER ;

DROP FUNCTION IF EXISTS fn_stock_libro;
DELIMITER //
CREATE FUNCTION fn_stock_libro(p_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE v_stock INT;
  SELECT stock INTO v_stock FROM Libro WHERE id_libro = p_id;
  RETURN IFNULL(v_stock, 0);
END//
DELIMITER ;

DROP FUNCTION IF EXISTS fn_total_pagado_pedido;
DELIMITER //
CREATE FUNCTION fn_total_pagado_pedido(p_pedido INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
  DECLARE v_pagado DECIMAL(12,2);
  SELECT COALESCE(SUM(monto),0) INTO v_pagado
  FROM Pago WHERE id_pedido = p_pedido;
  RETURN v_pagado;
END//
DELIMITER ;

DROP FUNCTION IF EXISTS fn_saldo_pedido;
DELIMITER //
CREATE FUNCTION fn_saldo_pedido(p_pedido INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
  DECLARE v_total DECIMAL(12,2);
  DECLARE v_pagado DECIMAL(12,2);
  SELECT total INTO v_total FROM Pedido WHERE id_pedido = p_pedido;
  SET v_pagado = fn_total_pagado_pedido(p_pedido);
  RETURN COALESCE(v_total,0) - COALESCE(v_pagado,0);
END//
DELIMITER ;

-- ======================
-- STORED PROCEDURES
-- ======================
DROP PROCEDURE IF EXISTS sp_crear_pedido;
DELIMITER //
CREATE PROCEDURE sp_crear_pedido(
  IN p_cliente INT,
  IN p_fecha DATE,
  IN p_libro INT,
  IN p_cantidad INT,
  IN p_precio DECIMAL(10,2)
)
BEGIN
  INSERT INTO Pedido (id_cliente, fecha_pedido, estado)
  VALUES (p_cliente, p_fecha, 'pendiente');
  SET @last_pedido := LAST_INSERT_ID();

  INSERT INTO DetallePedido (id_pedido, id_libro, cantidad, precio_unitario)
  VALUES (@last_pedido, p_libro, p_cantidad, p_precio);
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_agregar_detalle;
DELIMITER //
CREATE PROCEDURE sp_agregar_detalle(
  IN p_pedido INT,
  IN p_libro INT,
  IN p_cantidad INT,
  IN p_precio DECIMAL(10,2)
)
BEGIN
  INSERT INTO DetallePedido (id_pedido, id_libro, cantidad, precio_unitario)
  VALUES (p_pedido, p_libro, p_cantidad, p_precio);
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_registrar_pago;
DELIMITER //
CREATE PROCEDURE sp_registrar_pago(
  IN p_pedido INT,
  IN p_monto DECIMAL(10,2),
  IN p_metodo ENUM('tarjeta','transferencia','efectivo')
)
BEGIN
  INSERT INTO Pago (id_pedido, fecha_pago, monto, metodo)
  VALUES (p_pedido, CURDATE(), p_monto, p_metodo);
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_actualizar_estado_pedido;
DELIMITER //
CREATE PROCEDURE sp_actualizar_estado_pedido(
  IN p_pedido INT,
  IN p_estado VARCHAR(20)
)
BEGIN
  IF p_estado NOT IN ('pendiente','enviado','entregado') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Estado inválido. Use: pendiente|enviado|entregado';
  END IF;
  UPDATE Pedido SET estado = p_estado WHERE id_pedido = p_pedido;
END//
DELIMITER ;

-- ======================
-- TRIGGERS (reafirmación)
-- ======================
DROP TRIGGER IF EXISTS trg_detallepedido_ai;
DROP TRIGGER IF EXISTS trg_detallepedido_au;
DROP TRIGGER IF EXISTS trg_detallepedido_ad;

DELIMITER //
CREATE TRIGGER trg_detallepedido_ai
AFTER INSERT ON DetallePedido
FOR EACH ROW
BEGIN
  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.subtotal),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = NEW.id_pedido;
END//
CREATE TRIGGER trg_detallepedido_au
AFTER UPDATE ON DetallePedido
FOR EACH ROW
BEGIN
  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.subtotal),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = NEW.id_pedido;
END//
CREATE TRIGGER trg_detallepedido_ad
AFTER DELETE ON DetallePedido
FOR EACH ROW
BEGIN
  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.subtotal),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = OLD.id_pedido;
END//
DELIMITER ;
