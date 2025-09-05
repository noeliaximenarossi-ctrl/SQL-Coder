-- Entrega2_tests.sql
-- Validación de objetos (MySQL 8+)
-- Requisitos previos:
--   1) Ejecutar IdeaRossi_Ent1_revisada.sql (esquema/tablas/seed).
--   2) Ejecutar Entrega2_objetos.sql (vistas, funciones, SP, triggers).
--   3) Ejecutar Entrega2_inserts.sql (datos adicionales).
-- Ejecución recomendada: correr por bloques.

USE libreria_db;

-- =====================================================
-- 0) CHEQUEOS RÁPIDOS DE EXISTENCIA
-- =====================================================
-- Tablas clave
SELECT 'TABLAS' AS tipo, COUNT(*) AS total
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('Cliente','Autor','Editorial','Libro','LibroAutor','Pedido','DetallePedido','Pago');

-- Vistas
SELECT 'VISTAS' AS tipo, COUNT(*) AS total
FROM information_schema.views
WHERE table_schema = DATABASE()
  AND table_name IN ('v_ventas_cliente','v_libros_stock','v_pedidos_detallados');

-- Funciones
SELECT 'FUNCIONES' AS tipo, COUNT(*) AS total
FROM information_schema.routines
WHERE routine_schema = DATABASE()
  AND routine_type = 'FUNCTION'
  AND routine_name IN ('fn_total_pedidos_cliente','fn_stock_libro','fn_total_pagado_pedido','fn_saldo_pedido');

-- Triggers
SELECT 'TRIGGERS' AS tipo, COUNT(*) AS total
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
  AND trigger_name IN ('trg_detallepedido_ai','trg_detallepedido_au','trg_detallepedido_ad');

-- =====================================================
-- 1) VALIDACIÓN DE VISTAS
-- =====================================================
-- v_ventas_cliente: comparar con cálculo directo
SELECT
  vc.id_cliente,
  vc.cantidad_pedidos AS vista_cant,
  vc.total_comprado  AS vista_total,
  d.cant_directo,
  d.total_directo,
  CASE
    WHEN vc.cantidad_pedidos = d.cant_directo
     AND vc.total_comprado = d.total_directo THEN 'OK'
    ELSE 'FAIL'
  END AS check_
FROM v_ventas_cliente vc
JOIN (
  SELECT p.id_cliente,
         COUNT(DISTINCT p.id_pedido) AS cant_directo,
         COALESCE(SUM(p.total),0)     AS total_directo
  FROM Pedido p
  GROUP BY p.id_cliente
) d ON d.id_cliente = vc.id_cliente;

-- v_libros_stock
SELECT COUNT(*) AS vista_rows FROM v_libros_stock;
SELECT COUNT(*) AS libro_rows FROM Libro WHERE id_editorial IS NOT NULL;

-- v_pedidos_detallados: suma de subtotales = Pedido.total
SELECT vp.id_pedido,
       SUM(vp.subtotal) AS vista_sum_subtotal,
       (SELECT total FROM Pedido WHERE id_pedido = vp.id_pedido) AS pedido_total,
       CASE WHEN SUM(vp.subtotal) = (SELECT total FROM Pedido WHERE id_pedido = vp.id_pedido)
            THEN 'OK' ELSE 'FAIL' END AS check_
FROM v_pedidos_detallados vp
GROUP BY vp.id_pedido;

-- =====================================================
-- 2) VALIDACIÓN DE FUNCIONES (UDF)
-- =====================================================
-- fn_total_pedidos_cliente
SELECT c.id_cliente,
       fn_total_pedidos_cliente(c.id_cliente) AS fn_valor,
       (SELECT COALESCE(SUM(total),0) FROM Pedido WHERE id_cliente=c.id_cliente) AS directo
FROM Cliente c;

-- fn_stock_libro
SELECT l.id_libro,
       fn_stock_libro(l.id_libro) AS fn_valor,
       l.stock AS directo
FROM Libro l;

-- fn_total_pagado_pedido y fn_saldo_pedido
SELECT p.id_pedido,
       p.total AS pedido_total,
       fn_total_pagado_pedido(p.id_pedido) AS pagado,
       fn_saldo_pedido(p.id_pedido) AS saldo,
       CASE WHEN p.total = fn_total_pagado_pedido(p.id_pedido) + fn_saldo_pedido(p.id_pedido)
            THEN 'OK' ELSE 'FAIL' END AS check_
FROM Pedido p;

-- =====================================================
-- 3) VALIDACIÓN DE STORED PROCEDURES (con ROLLBACK)
-- =====================================================
START TRANSACTION;
CALL sp_crear_pedido(1, CURDATE(), 1, 2, 100.00);
SET @p := LAST_INSERT_ID();
SELECT @p AS nuevo_pedido,
       (SELECT total FROM Pedido WHERE id_pedido=@p) AS total,
       (SELECT SUM(subtotal) FROM DetallePedido WHERE id_pedido=@p) AS sum_subtotal;
ROLLBACK;

START TRANSACTION;
INSERT INTO Pedido (id_cliente, fecha_pedido, estado) VALUES (1, CURDATE(), 'pendiente');
SET @p := LAST_INSERT_ID();
CALL sp_agregar_detalle(@p, 1, 1, 50.00);
CALL sp_agregar_detalle(@p, 2, 2, 10.00);
SELECT @p AS pedido,
       (SELECT total FROM Pedido WHERE id_pedido=@p) AS total,
       (SELECT SUM(subtotal) FROM DetallePedido WHERE id_pedido=@p) AS sum_subtotal;
ROLLBACK;

START TRANSACTION;
INSERT INTO Pedido (id_cliente, fecha_pedido, estado) VALUES (1, CURDATE(), 'pendiente');
SET @p := LAST_INSERT_ID();
INSERT INTO DetallePedido (id_pedido, id_libro, cantidad, precio_unitario) VALUES (@p, 1, 1, 100.00);
SELECT fn_total_pagado_pedido(@p) AS pagado, fn_saldo_pedido(@p) AS saldo;
CALL sp_registrar_pago(@p, 40.00, 'tarjeta');
SELECT fn_total_pagado_pedido(@p) AS pagado, fn_saldo_pedido(@p) AS saldo;
ROLLBACK;

START TRANSACTION;
INSERT INTO Pedido (id_cliente, fecha_pedido, estado) VALUES (1, CURDATE(), 'pendiente');
SET @p := LAST_INSERT_ID();
CALL sp_actualizar_estado_pedido(@p, 'enviado');
SELECT (SELECT estado FROM Pedido WHERE id_pedido=@p) AS estado;
ROLLBACK;

-- =====================================================
-- 4) VALIDACIÓN DE TRIGGERS
-- =====================================================
START TRANSACTION;
INSERT INTO Pedido (id_cliente, fecha_pedido, estado) VALUES (1, CURDATE(), 'pendiente');
SET @p := LAST_INSERT_ID();
INSERT INTO DetallePedido (id_pedido, id_libro, cantidad, precio_unitario) VALUES (@p, 1, 2, 10.00);
SELECT (SELECT total FROM Pedido WHERE id_pedido=@p) AS total,
       (SELECT SUM(subtotal) FROM DetallePedido WHERE id_pedido=@p) AS sum_subtotal;
UPDATE DetallePedido SET cantidad = 3, precio_unitario = 12.00 WHERE id_pedido=@p LIMIT 1;
SELECT (SELECT total FROM Pedido WHERE id_pedido=@p) AS total,
       (SELECT SUM(subtotal) FROM DetallePedido WHERE id_pedido=@p) AS sum_subtotal;
DELETE FROM DetallePedido WHERE id_pedido=@p LIMIT 1;
SELECT (SELECT total FROM Pedido WHERE id_pedido=@p) AS total,
       (SELECT SUM(subtotal) FROM DetallePedido WHERE id_pedido=@p) AS sum_subtotal;
ROLLBACK;

-- =====================================================
-- 5) CHEQUEOS DE ÍNDICES Y PLANES
-- =====================================================
SELECT * FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name IN ('Pedido','DetallePedido','Pago');

EXPLAIN SELECT p.id_pedido, p.fecha_pedido
FROM Pedido p
WHERE p.id_cliente = 1 AND p.fecha_pedido >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);

EXPLAIN SELECT dp.id_pedido, dp.id_libro
FROM DetallePedido dp
WHERE dp.id_pedido = 1 AND dp.id_libro IN (1,2);
