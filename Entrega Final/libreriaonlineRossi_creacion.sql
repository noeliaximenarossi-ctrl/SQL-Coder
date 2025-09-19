-- ============================================================
-- CREACION DE BASE DE DATOS Y TABLAS - Libreria Online (vEntFinal)
-- Alumna: Noelia Rossi
-- ============================================================

DROP DATABASE IF EXISTS libreria_online;
CREATE DATABASE libreria_online
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE libreria_online;

-- ======================= TABLAS =======================
CREATE TABLE Cliente (
  id_cliente INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  telefono VARCHAR(20),
  direccion VARCHAR(200)
) ENGINE=InnoDB;

CREATE TABLE Autor (
  id_autor INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE Editorial (
  id_editorial INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE CategoriaLibro (
  id_categoria INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE Libro (
  id_libro INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(200) NOT NULL,
  anio_publicacion YEAR,
  precio DECIMAL(10,2) NOT NULL,
  stock INT NOT NULL,
  id_editorial INT,
  id_categoria INT,
  CONSTRAINT fk_libro_editorial FOREIGN KEY (id_editorial) REFERENCES Editorial(id_editorial),
  CONSTRAINT fk_libro_categoria  FOREIGN KEY (id_categoria)  REFERENCES CategoriaLibro(id_categoria)
) ENGINE=InnoDB;

CREATE TABLE Proveedor (
  id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  contacto VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE Compra (
  id_compra INT AUTO_INCREMENT PRIMARY KEY,
  id_proveedor INT NOT NULL,
  fecha DATE NOT NULL,
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_compra_proveedor FOREIGN KEY (id_proveedor) REFERENCES Proveedor(id_proveedor)
) ENGINE=InnoDB;

CREATE TABLE DetalleCompra (
  id_detalle_compra INT AUTO_INCREMENT PRIMARY KEY,
  id_compra INT NOT NULL,
  id_libro INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_detallecompra_compra FOREIGN KEY (id_compra) REFERENCES Compra(id_compra),
  CONSTRAINT fk_detallecompra_libro  FOREIGN KEY (id_libro)  REFERENCES Libro(id_libro)
) ENGINE=InnoDB;

CREATE TABLE Pedido (
  id_pedido INT AUTO_INCREMENT PRIMARY KEY,
  id_cliente INT NOT NULL,
  fecha DATE NOT NULL,
  estado ENUM('pendiente','enviado','entregado') NOT NULL DEFAULT 'pendiente',
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente)
) ENGINE=InnoDB;

CREATE TABLE DetallePedido (
  id_detalle INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  id_libro INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_detallepedido_pedido FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido),
  CONSTRAINT fk_detallepedido_libro  FOREIGN KEY (id_libro)  REFERENCES Libro(id_libro)
) ENGINE=InnoDB;

CREATE TABLE Pago (
  id_pago INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  fecha DATE NOT NULL,
  monto DECIMAL(10,2) NOT NULL,
  metodo ENUM('tarjeta','transferencia','efectivo') NOT NULL,
  CONSTRAINT fk_pago_pedido FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido)
) ENGINE=InnoDB;

CREATE TABLE Sucursal (
  id_sucursal INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  direccion VARCHAR(200) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE Empleado (
  id_empleado INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  id_sucursal INT NOT NULL,
  CONSTRAINT fk_empleado_sucursal FOREIGN KEY (id_sucursal) REFERENCES Sucursal(id_sucursal)
) ENGINE=InnoDB;

CREATE TABLE UsuarioSistema (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(100) NOT NULL,
  rol ENUM('admin','vendedor','cliente') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE Envio (
  id_envio INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  direccion VARCHAR(200) NOT NULL,
  fecha_envio DATE,
  estado ENUM('preparando','enviado','entregado') NOT NULL DEFAULT 'preparando',
  CONSTRAINT fk_envio_pedido FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido)
) ENGINE=InnoDB;

CREATE TABLE InventarioMovimientos (
  id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
  id_libro INT NOT NULL,
  tipo ENUM('entrada','salida') NOT NULL,
  cantidad INT NOT NULL,
  fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_mov_libro FOREIGN KEY (id_libro) REFERENCES Libro(id_libro)
) ENGINE=InnoDB;
