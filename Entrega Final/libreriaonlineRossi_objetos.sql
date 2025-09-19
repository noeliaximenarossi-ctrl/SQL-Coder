-- ============================================================
-- OBJETOS (Vistas, Funciones, Stored Procedures, Triggers) - vEntFinal
-- Estilo estable (como Entrega 2): DROP IF EXISTS + CREATE
-- ============================================================
USE libreria_online;

-- ======================= VISTAS =======================
DROP VIEW IF EXISTS v_ventas_cliente;
CREATE VIEW v_ventas_cliente AS
SELECT
  c.id_cliente,
  CONCAT(c.nombre,' ',c.apellido) AS cliente,
  COUNT(DISTINCT p.id_pedido) AS pedidos,
  COALESCE(SUM(p.total),0) AS total_comprado
FROM Cliente c
LEFT JOIN Pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, cliente;

DROP VIEW IF EXISTS v_libros_stock;
CREATE VIEW v_libros_stock AS
SELECT l.id_libro, l.titulo, l.precio, l.stock, e.nombre AS editorial, cl.nombre AS categoria
FROM Libro l
LEFT JOIN Editorial e ON e.id_editorial = l.id_editorial
LEFT JOIN CategoriaLibro cl ON cl.id_categoria = l.id_categoria;

DROP VIEW IF EXISTS v_pedidos_detallados;
CREATE VIEW v_pedidos_detallados AS
SELECT
  p.id_pedido, p.fecha, p.estado, p.total,
  c.id_cliente, CONCAT(c.nombre,' ',c.apellido) AS cliente,
  dp.id_detalle, dp.cantidad, dp.precio_unitario, (dp.cantidad*dp.precio_unitario) AS subtotal,
  l.id_libro, l.titulo
FROM Pedido p
JOIN Cliente c ON c.id_cliente = p.id_cliente
JOIN DetallePedido dp ON dp.id_pedido = p.id_pedido
JOIN Libro l ON l.id_libro = dp.id_libro;

DROP VIEW IF EXISTS v_ventas_mensuales;
CREATE VIEW v_ventas_mensuales AS
SELECT DATE_FORMAT(p.fecha,'%Y-%m') AS periodo,
       COUNT(DISTINCT p.id_pedido) AS pedidos,
       SUM(p.total) AS total_ventas
FROM Pedido p
GROUP BY DATE_FORMAT(p.fecha,'%Y-%m')
ORDER BY periodo;

DROP VIEW IF EXISTS v_top5_libros;
CREATE VIEW v_top5_libros AS
SELECT l.id_libro, l.titulo, SUM(dp.cantidad) AS unidades_vendidas
FROM DetallePedido dp
JOIN Libro l ON l.id_libro = dp.id_libro
GROUP BY l.id_libro, l.titulo
ORDER BY unidades_vendidas DESC
LIMIT 5;

DROP VIEW IF EXISTS v_ventas_por_editorial;
CREATE VIEW v_ventas_por_editorial AS
SELECT e.nombre AS editorial, SUM(dp.cantidad*dp.precio_unitario) AS total_ventas
FROM DetallePedido dp
JOIN Libro l ON l.id_libro = dp.id_libro
JOIN Editorial e ON e.id_editorial = l.id_editorial
GROUP BY e.nombre
ORDER BY total_ventas DESC;

-- ======================= FUNCIONES =======================
DELIMITER $$

DROP FUNCTION IF EXISTS fn_total_pedidos_cliente $$
CREATE FUNCTION fn_total_pedidos_cliente(p_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(12,2);
  SELECT COALESCE(SUM(total),0) INTO v_total FROM Pedido WHERE id_cliente=p_id;
  RETURN COALESCE(v_total,0);
END $$

DROP FUNCTION IF EXISTS fn_total_pagado_pedido $$
CREATE FUNCTION fn_total_pagado_pedido(p_pedido INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_pagado DECIMAL(12,2);
  SELECT COALESCE(SUM(monto),0) INTO v_pagado FROM Pago WHERE id_pedido=p_pedido;
  RETURN COALESCE(v_pagado,0);
END $$

DROP FUNCTION IF EXISTS fn_saldo_pedido $$
CREATE FUNCTION fn_saldo_pedido(p_pedido INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(12,2);
  SELECT COALESCE(total,0) INTO v_total FROM Pedido WHERE id_pedido=p_pedido;
  RETURN v_total - fn_total_pagado_pedido(p_pedido);
END $$

DELIMITER ;

-- ======================= STORED PROCEDURES =======================
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_crear_pedido $$
CREATE PROCEDURE sp_crear_pedido(
  IN p_cliente INT, IN p_fecha DATE, IN p_libro INT, IN p_cantidad INT, IN p_precio DECIMAL(10,2))
BEGIN
  DECLARE v_pedido_id INT;
  INSERT INTO Pedido(id_cliente,fecha,estado,total) VALUES(p_cliente,p_fecha,'pendiente',0);
  SET v_pedido_id = LAST_INSERT_ID();
  INSERT INTO DetallePedido(id_pedido,id_libro,cantidad,precio_unitario) VALUES(v_pedido_id,p_libro,p_cantidad,p_precio);
END $$

DROP PROCEDURE IF EXISTS sp_agregar_detalle $$
CREATE PROCEDURE sp_agregar_detalle(
  IN p_pedido INT, IN p_libro INT, IN p_cantidad INT, IN p_precio DECIMAL(10,2))
BEGIN
  INSERT INTO DetallePedido(id_pedido,id_libro,cantidad,precio_unitario)
  VALUES(p_pedido,p_libro,p_cantidad,p_precio);
END $$

DROP PROCEDURE IF EXISTS sp_registrar_pago $$
CREATE PROCEDURE sp_registrar_pago(
  IN p_pedido INT, IN p_monto DECIMAL(10,2), IN p_metodo VARCHAR(20))
BEGIN
  IF p_metodo NOT IN ('tarjeta','transferencia','efectivo') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Metodo de pago inválido';
  END IF;
  INSERT INTO Pago(id_pedido,fecha,monto,metodo) VALUES(p_pedido,CURDATE(),p_monto,p_metodo);
END $$

DROP PROCEDURE IF EXISTS sp_actualizar_estado_pedido $$
CREATE PROCEDURE sp_actualizar_estado_pedido(IN p_pedido INT, IN p_estado VARCHAR(20))
BEGIN
  IF p_estado NOT IN ('pendiente','enviado','entregado') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Estado inválido';
  END IF;
  UPDATE Pedido SET estado=p_estado WHERE id_pedido=p_pedido;
END $$

DELIMITER ;

-- ======================= TRIGGERS =======================
DELIMITER $$

DROP TRIGGER IF EXISTS trg_detallepedido_ai $$
CREATE TRIGGER trg_detallepedido_ai
AFTER INSERT ON DetallePedido
FOR EACH ROW
BEGIN
  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.cantidad*d.precio_unitario),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = NEW.id_pedido;

  UPDATE Libro SET stock = stock - NEW.cantidad WHERE id_libro = NEW.id_libro;
  INSERT INTO InventarioMovimientos(id_libro,tipo,cantidad) VALUES(NEW.id_libro,'salida',NEW.cantidad);
END $$

DROP TRIGGER IF EXISTS trg_detallepedido_au $$
CREATE TRIGGER trg_detallepedido_au
AFTER UPDATE ON DetallePedido
FOR EACH ROW
BEGIN
  DECLARE v_delta INT;
  SET v_delta = NEW.cantidad - OLD.cantidad;

  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.cantidad*d.precio_unitario),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = NEW.id_pedido;

  IF v_delta <> 0 THEN
    UPDATE Libro SET stock = stock - v_delta WHERE id_libro = NEW.id_libro;
    IF v_delta > 0 THEN
      INSERT INTO InventarioMovimientos(id_libro,tipo,cantidad) VALUES(NEW.id_libro,'salida', v_delta);
    ELSE
      INSERT INTO InventarioMovimientos(id_libro,tipo,cantidad) VALUES(NEW.id_libro,'entrada', ABS(v_delta));
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_detallepedido_ad $$
CREATE TRIGGER trg_detallepedido_ad
AFTER DELETE ON DetallePedido
FOR EACH ROW
BEGIN
  UPDATE Pedido p
     SET p.total = (SELECT COALESCE(SUM(d.cantidad*d.precio_unitario),0) FROM DetallePedido d WHERE d.id_pedido = p.id_pedido)
   WHERE p.id_pedido = OLD.id_pedido;

  UPDATE Libro SET stock = stock + OLD.cantidad WHERE id_libro = OLD.id_libro;
  INSERT INTO InventarioMovimientos(id_libro,tipo,cantidad) VALUES(OLD.id_libro,'entrada',OLD.cantidad);
END $$

DROP TRIGGER IF EXISTS trg_detallecompra_ai $$
CREATE TRIGGER trg_detallecompra_ai
AFTER INSERT ON DetalleCompra
FOR EACH ROW
BEGIN
  UPDATE Compra c
     SET c.total = (SELECT COALESCE(SUM(d.cantidad*d.precio_unitario),0) FROM DetalleCompra d WHERE d.id_compra = c.id_compra)
   WHERE c.id_compra = NEW.id_compra;

  UPDATE Libro SET stock = stock + NEW.cantidad WHERE id_libro = NEW.id_libro;
  INSERT INTO InventarioMovimientos(id_libro,tipo,cantidad) VALUES(NEW.id_libro,'entrada',NEW.cantidad);
END $$

DROP TRIGGER IF EXISTS trg_detallecompra_au $$
CREATE TRIGGER trg_detallecompra_au
AFTER UPDATE ON DetalleCompra
FOR EACH ROW
BEGIN
  DECLARE v_delta INT;
  SET v_delta = NEW.cantidad - OLD.cantidad;

  UPDATE Compra c
     SET c.total = (SELECT COALESCE(SUM(d.cantidad*d.precio_unitario),0) FROM DetalleCompra d WHERE d.id_compra = c.id_compra)
   WHERE c.id_compra = NEW.id_compra;

  IF v_delta <> 0 THEN
    UPDATE Libro SET stock = stock + v_delta WHERE id_libro = NEW.id_libro;
    IF v_delta > 0 THEN
      INSERT INTO InventarioMovimientos(id_libro,tipo,cantidad) VALUES(NEW.id_libro,'entrada', v_delta);
    ELSE
      INSERT INTO InventarioMovimientos(id_libro,tipo,cantidad) VALUES(NEW.id_libro,'salida', ABS(v_delta));
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_detallecompra_ad $$
CREATE TRIGGER trg_detallecompra_ad
AFTER DELETE ON DetalleCompra
FOR EACH ROW
BEGIN
  UPDATE Compra c
     SET c.total = (SELECT COALESCE(SUM(d.cantidad*d.precio_unitario),0) FROM DetalleCompra d WHERE d.id_compra = c.id_compra)
   WHERE c.id_compra = OLD.id_compra;

  UPDATE Libro SET stock = stock - OLD.cantidad WHERE id_libro = OLD.id_libro;
  INSERT INTO InventarioMovimientos(id_libro,tipo,cantidad) VALUES(OLD.id_libro,'salida',OLD.cantidad);
END $$

DELIMITER ;

-- FIN OBJETOS
