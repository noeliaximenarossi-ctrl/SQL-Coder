-- ============================================================
-- TESTS PASS/FAIL v4 - Libreria Online
-- Orden: creacion -> objetos -> inserts -> tests
-- ============================================================
USE libreria_online;

SELECT 'Base actual' AS info, DATABASE() AS valor;

-- Sanidad
SELECT 'SANIDAD: Libro' AS test, CASE WHEN (SELECT COUNT(*) FROM Libro)>0 THEN 'PASS' ELSE 'FAIL' END AS resultado;
SELECT 'SANIDAD: Cliente' AS test, CASE WHEN (SELECT COUNT(*) FROM Cliente)>0 THEN 'PASS' ELSE 'FAIL' END AS resultado;
SELECT 'SANIDAD: Pedido' AS test, CASE WHEN (SELECT COUNT(*) FROM Pedido)>0 THEN 'PASS' ELSE 'FAIL' END AS resultado;
SELECT 'SANIDAD: DetallePedido' AS test, CASE WHEN (SELECT COUNT(*) FROM DetallePedido)>0 THEN 'PASS' ELSE 'FAIL' END AS resultado;

-- Existencia básica de objetos
SELECT 'VISTA v_ventas_cliente' AS test,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.VIEWS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='v_ventas_cliente')
            THEN 'PASS' ELSE 'FAIL: no existe' END AS resultado;
SELECT 'FUNC fn_total_pagado_pedido' AS test,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='fn_total_pagado_pedido' AND ROUTINE_TYPE='FUNCTION')
            THEN 'PASS' ELSE 'FAIL: no existe' END AS resultado;
SELECT 'SP sp_crear_pedido' AS test,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='sp_crear_pedido' AND ROUTINE_TYPE='PROCEDURE')
            THEN 'PASS' ELSE 'FAIL: no existe' END AS resultado;

-- Integridad
SELECT 'FK DetallePedido->Pedido/Libro' AS test,
       CASE WHEN (SELECT COUNT(*) FROM DetallePedido d
                  LEFT JOIN Pedido p ON p.id_pedido=d.id_pedido
                  LEFT JOIN Libro l  ON l.id_libro=d.id_libro
                  WHERE p.id_pedido IS NULL OR l.id_libro IS NULL)=0
            THEN 'PASS' ELSE 'FAIL' END AS resultado;

-- Triggers: prueba controlada
SET @lib_test := (SELECT id_libro FROM Libro WHERE stock >= 5 ORDER BY id_libro LIMIT 1);
SET @cli_test := (SELECT id_cliente FROM Cliente ORDER BY id_cliente LIMIT 1);

INSERT INTO Pedido(id_cliente, fecha, estado, total) VALUES(@cli_test, CURDATE(), 'pendiente', 0);
SET @ped_test := LAST_INSERT_ID();

SELECT stock INTO @stock_ini FROM Libro WHERE id_libro=@lib_test;

INSERT INTO DetallePedido(id_pedido,id_libro,cantidad,precio_unitario)
VALUES (@ped_test, @lib_test, 2, 10000.00), (@ped_test, @lib_test, 1, 12000.00);

-- Total esperado (2*10000 + 1*12000 = 32000)
SELECT ROUND(p.total,2) INTO @total_test FROM Pedido p WHERE p.id_pedido=@ped_test;
SELECT 'TRG total post-insert' AS test,
       CASE WHEN @total_test IS NULL THEN 'FAIL: pedido no encontrado'
            WHEN @total_test = 32000.00 THEN 'PASS'
            ELSE CONCAT('FAIL: total=', @total_test) END AS resultado;

-- Stock esperado
SELECT stock INTO @stock_post FROM Libro WHERE id_libro=@lib_test;
SELECT 'TRG stock post-insert' AS test,
       CASE WHEN @stock_post = @stock_ini - 3 THEN 'PASS' ELSE CONCAT('FAIL: stock=', @stock_post,' esperado=',@stock_ini-3) END AS resultado;

-- Borrar última línea y revalidar
DELETE FROM DetallePedido WHERE id_pedido=@ped_test ORDER BY id_detalle DESC LIMIT 1;

SELECT ROUND(total,2) INTO @total_after FROM Pedido WHERE id_pedido=@ped_test;
SELECT 'TRG total post-delete' AS test,
       CASE WHEN @total_after = 20000.00 THEN 'PASS' ELSE CONCAT('FAIL: total=',@total_after) END AS resultado;

SELECT stock INTO @stock_after FROM Libro WHERE id_libro=@lib_test;
SELECT 'TRG stock post-delete' AS test,
       CASE WHEN @stock_after = @stock_ini - 2 THEN 'PASS' ELSE CONCAT('FAIL: stock=',@stock_after) END AS resultado;

-- SP: flujo completo
CALL sp_crear_pedido(@cli_test, CURDATE(), @lib_test, 2, 9000.00);
SET @ped_sp := LAST_INSERT_ID();
CALL sp_agregar_detalle(@ped_sp, @lib_test, 1, 11000.00);
CALL sp_registrar_pago(@ped_sp, 15000.00, 'tarjeta');
CALL sp_actualizar_estado_pedido(@ped_sp, 'enviado');

SELECT ROUND(total,2) INTO @total_sp FROM Pedido WHERE id_pedido=@ped_sp;
SELECT 'SP total' AS test,
       CASE WHEN @total_sp = 29000.00 THEN 'PASS' ELSE CONCAT('FAIL: total=',@total_sp) END AS resultado;

SELECT estado INTO @estado_sp FROM Pedido WHERE id_pedido=@ped_sp;
SELECT 'SP estado' AS test,
       CASE WHEN @estado_sp = 'enviado' THEN 'PASS' ELSE CONCAT('FAIL: estado=',@estado_sp) END AS resultado;
