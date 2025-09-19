-- ============================================================
-- DROP ALL - Reinicio completo del esquema (vEntFinal)
-- ============================================================
USE libreria_online;
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS v_ventas_cliente;
DROP VIEW IF EXISTS v_libros_stock;
DROP VIEW IF EXISTS v_pedidos_detallados;
DROP VIEW IF EXISTS v_ventas_mensuales;
DROP VIEW IF EXISTS v_top5_libros;
DROP VIEW IF EXISTS v_ventas_por_editorial;

DROP TABLE IF EXISTS InventarioMovimientos;
DROP TABLE IF EXISTS Envio;
DROP TABLE IF EXISTS Pago;
DROP TABLE IF EXISTS DetallePedido;
DROP TABLE IF EXISTS Pedido;
DROP TABLE IF EXISTS DetalleCompra;
DROP TABLE IF EXISTS Compra;
DROP TABLE IF EXISTS UsuarioSistema;
DROP TABLE IF EXISTS Empleado;
DROP TABLE IF EXISTS Sucursal;
DROP TABLE IF EXISTS Libro;
DROP TABLE IF EXISTS CategoriaLibro;
DROP TABLE IF EXISTS Autor;
DROP TABLE IF EXISTS Editorial;
DROP TABLE IF EXISTS Proveedor;
DROP TABLE IF EXISTS Cliente;

SET FOREIGN_KEY_CHECKS = 1;
