CREATE DATABASE Staging;
Go
USE Staging;
Go

CREATE TABLE [customers] (
	[customer_id] INT,
	[customer_name] VARCHAR(255),
	[industry] VARCHAR(100),
	[contact_email] VARCHAR(255),
	[contact_phone] VARCHAR(50)
);

CREATE TABLE [departments] (
	[department_id] INT,
	[department_name] VARCHAR(255),
	[location] VARCHAR(100)
);

CREATE TABLE [employees] (
	[employee_id] INT,
	[first_name] VARCHAR(100),
	[last_name] VARCHAR(100),
	[department_id] INT,
	[hire_date] DATE,
	[salary] DECIMAL(18,2),
);

CREATE TABLE [products] (
	[product_id] INT,
	[product_name] VARCHAR(255),
	[category] VARCHAR(100),
	[release_date] DATE,
	[price] DECIMAL(18,2)
);

CREATE TABLE [projects] (
	[project_id] INT,
	[project_name] VARCHAR(255),
	[department_id] INT,
	[start_date] DATE,
	[end_date] DATE,
	[budget] DECIMAL(18,2),
);

CREATE TABLE [sales] (
	[sale_id] INT,
	[product_id] INT,
	[customer_id] INT,
	[sale_date] DATE,
	[region] VARCHAR(100),
	[quantity_sold] INT,
	[revenue] DECIMAL(18,2),
);

CREATE TABLE [suppliers] (
	[supplier_id] INT,
	[supplier_name] VARCHAR(255),
	[material_supplied] VARCHAR(255),
	[contact_email] VARCHAR(255)
);

CREATE TABLE [supply_chain] (
	[supply_chain_id] INT,
	[supplier_id] INT,
	[product_id] INT,
	[supply_date] DATE,
	[quantity_supplied] INT,
);