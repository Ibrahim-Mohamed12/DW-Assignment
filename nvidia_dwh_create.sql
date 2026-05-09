-- =============================================================
--  Nvidia Data Warehouse -- DDL Creation Script
--  Galaxy Schema: 3 Fact Tables + 6 Dimension Tables
--  Target: SQL Server (T-SQL)
--  Execution order: Dimensions first, then Facts
-- =============================================================


-- =============================================================
--  SECTION 1: DIMENSION TABLES
-- =============================================================

-- -------------------------------------------------------------
--  DimDate  |  SCD Type 1
--  Populated by SSIS Script Component (no source table)
-- -------------------------------------------------------------
CREATE TABLE DimDate (
    date_sk         INT             NOT NULL IDENTITY(1,1),
    full_date       DATE            NOT NULL,
    day_of_week     TINYINT         NOT NULL,   -- 1=Monday ... 7=Sunday
    day_of_month    TINYINT         NOT NULL,   -- 1-31
    month_number    TINYINT         NOT NULL,   -- 1-12
    month_name      VARCHAR(12)     NOT NULL,   -- January ... December
    quarter         TINYINT         NOT NULL,   -- 1-4
    year            SMALLINT        NOT NULL,   -- Four-digit year
    is_weekend      BIT             NOT NULL,   -- 1 if Saturday or Sunday

    CONSTRAINT PK_DimDate        PRIMARY KEY (date_sk),
    CONSTRAINT UQ_DimDate_date   UNIQUE      (full_date)
);


-- -------------------------------------------------------------
--  DimProduct  |  SCD Type 1
--  Source: products
-- -------------------------------------------------------------
CREATE TABLE DimProduct (
    product_sk      INT             NOT NULL IDENTITY(1,1),
    product_id      INT             NOT NULL,   -- Natural key (source)
    product_name    VARCHAR(200)    NOT NULL,
    category        VARCHAR(100)    NOT NULL,   -- e.g. AI Accelerator, Gaming GPU
    release_date    DATE            NOT NULL,
    current_price   DECIMAL(18,2)   NOT NULL,   -- Overwritten on change (SCD1)

    CONSTRAINT PK_DimProduct        PRIMARY KEY (product_sk),
    CONSTRAINT UQ_DimProduct_nk     UNIQUE      (product_id)
);


-- -------------------------------------------------------------
--  DimCustomer  |  SCD Type 1
--  Source: customers
-- -------------------------------------------------------------
CREATE TABLE DimCustomer (
    customer_sk     INT             NOT NULL IDENTITY(1,1),
    customer_id     INT             NOT NULL,   -- Natural key (source)
    customer_name   VARCHAR(200)    NOT NULL,
    industry        VARCHAR(100)    NOT NULL,   -- e.g. Cloud Services, Data Centers
    contact_email   VARCHAR(200)    NOT NULL,
    contact_phone   VARCHAR(30)     NULL,

    CONSTRAINT PK_DimCustomer       PRIMARY KEY (customer_sk),
    CONSTRAINT UQ_DimCustomer_nk    UNIQUE      (customer_id)
);


-- -------------------------------------------------------------
--  DimSupplier  |  SCD Type 2
--  Source: suppliers
--  Versioned cols: supplier_name, material_supplied
--  Non-versioned:  contact_email (Type 1 overwrite)
-- -------------------------------------------------------------
CREATE TABLE DimSupplier (
    supplier_sk         INT             NOT NULL IDENTITY(1,1),
    supplier_id         INT             NOT NULL,   -- Natural key (stable across versions)
    supplier_name       VARCHAR(200)    NOT NULL,   -- Versioned
    material_supplied   VARCHAR(200)    NOT NULL,   -- Versioned
    contact_email       VARCHAR(200)    NOT NULL,   -- Overwrite (not versioned)
    effective_date      DATE            NOT NULL,   -- SCD2 metadata: version start
    expiry_date         DATE            NULL,       -- SCD2 metadata: version end (NULL = current)
    is_current          BIT             NOT NULL DEFAULT 1,  -- 1 = active version

    CONSTRAINT PK_DimSupplier   PRIMARY KEY (supplier_sk)
);

CREATE INDEX IX_DimSupplier_nk_current
    ON DimSupplier (supplier_id, is_current);


-- -------------------------------------------------------------
--  DimDepartment  |  SCD Type 2
--  Source: departments
--  Versioned cols: department_name, location
-- -------------------------------------------------------------
CREATE TABLE DimDepartment (
    department_sk       INT             NOT NULL IDENTITY(1,1),
    department_id       INT             NOT NULL,   -- Natural key (stable across versions)
    department_name     VARCHAR(200)    NOT NULL,   -- Versioned
    location            VARCHAR(200)    NOT NULL,   -- Versioned
    effective_date      DATE            NOT NULL,   -- SCD2 metadata: version start
    expiry_date         DATE            NULL,       -- SCD2 metadata: version end (NULL = current)
    is_current          BIT             NOT NULL DEFAULT 1,  -- 1 = active version

    CONSTRAINT PK_DimDepartment  PRIMARY KEY (department_sk)
);

CREATE INDEX IX_DimDepartment_nk_current
    ON DimDepartment (department_id, is_current);


-- -------------------------------------------------------------
--  DimEmployee  |  SCD Type 1
--  Source: employees
--  Current salary overwritten; history captured via FactProjectHR snapshots
--  department_sk references the CURRENT version of DimDepartment
-- -------------------------------------------------------------
CREATE TABLE DimEmployee (
    employee_sk     INT             NOT NULL IDENTITY(1,1),
    employee_id     INT             NOT NULL,   -- Natural key (source)
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    department_sk   INT             NOT NULL,   -- FK -> DimDepartment (current version)
    hire_date       DATE            NOT NULL,
    current_salary  DECIMAL(18,2)   NOT NULL,   -- Overwritten on raise (SCD1)

    CONSTRAINT PK_DimEmployee       PRIMARY KEY (employee_sk),
    CONSTRAINT UQ_DimEmployee_nk    UNIQUE      (employee_id),
    CONSTRAINT FK_DimEmployee_Dept  FOREIGN KEY (department_sk)
        REFERENCES DimDepartment (department_sk)
);


-- =============================================================
--  SECTION 2: FACT TABLES
--  All dimension tables must exist before creating facts
-- =============================================================

-- -------------------------------------------------------------
--  FactSales  |  Transaction Fact
--  Grain: one row = one individual sale transaction
--  Source: sales (+ products for unit_price at time of sale)
-- -------------------------------------------------------------
CREATE TABLE FactSales (
    sale_sk         INT             NOT NULL IDENTITY(1,1),

    -- Foreign keys
    date_sk         INT             NOT NULL,   -- FK -> DimDate
    product_sk      INT             NOT NULL,   -- FK -> DimProduct
    customer_sk     INT             NOT NULL,   -- FK -> DimCustomer

    -- Degenerate dimension
    region          VARCHAR(50)     NOT NULL,   -- No separate dimension table

    -- Source natural key (audit / idempotency)
    sale_id         INT             NOT NULL,

    -- Measures
    quantity_sold   INT             NOT NULL,           -- Additive
    revenue         DECIMAL(18,2)   NOT NULL,           -- Additive
    unit_price      DECIMAL(18,2)   NOT NULL,           -- Non-additive (point-in-time)

    CONSTRAINT PK_FactSales             PRIMARY KEY (sale_sk),
    CONSTRAINT UQ_FactSales_source_nk   UNIQUE      (sale_id),
    CONSTRAINT FK_FactSales_Date        FOREIGN KEY (date_sk)
        REFERENCES DimDate      (date_sk),
    CONSTRAINT FK_FactSales_Product     FOREIGN KEY (product_sk)
        REFERENCES DimProduct   (product_sk),
    CONSTRAINT FK_FactSales_Customer    FOREIGN KEY (customer_sk)
        REFERENCES DimCustomer  (customer_sk)
);

CREATE INDEX IX_FactSales_Date       ON FactSales (date_sk);
CREATE INDEX IX_FactSales_Product    ON FactSales (product_sk);
CREATE INDEX IX_FactSales_Customer   ON FactSales (customer_sk);


-- -------------------------------------------------------------
--  FactSupplyChain  |  Transaction Fact
--  Grain: one row = one supplier delivery event
--  Source: supply_chain
-- -------------------------------------------------------------
CREATE TABLE FactSupplyChain (
    supply_chain_sk     INT     NOT NULL IDENTITY(1,1),

    -- Foreign keys
    date_sk             INT     NOT NULL,   -- FK -> DimDate (delivery date)
    supplier_sk         INT     NOT NULL,   -- FK -> DimSupplier (active version at load time)
    product_sk          INT     NOT NULL,   -- FK -> DimProduct

    -- Source natural key (audit / idempotency)
    supply_chain_id     INT     NOT NULL,

    -- Measures
    quantity_supplied   INT     NOT NULL,   -- Additive

    CONSTRAINT PK_FactSupplyChain           PRIMARY KEY (supply_chain_sk),
    CONSTRAINT UQ_FactSupplyChain_source_nk UNIQUE      (supply_chain_id),
    CONSTRAINT FK_FactSupplyChain_Date      FOREIGN KEY (date_sk)
        REFERENCES DimDate      (date_sk),
    CONSTRAINT FK_FactSupplyChain_Supplier  FOREIGN KEY (supplier_sk)
        REFERENCES DimSupplier  (supplier_sk),
    CONSTRAINT FK_FactSupplyChain_Product   FOREIGN KEY (product_sk)
        REFERENCES DimProduct   (product_sk)
);

CREATE INDEX IX_FactSupplyChain_Date        ON FactSupplyChain (date_sk);
CREATE INDEX IX_FactSupplyChain_Supplier    ON FactSupplyChain (supplier_sk);
CREATE INDEX IX_FactSupplyChain_Product     ON FactSupplyChain (product_sk);


-- -------------------------------------------------------------
--  FactProjectHR  |  Accumulating Snapshot Fact
--  Grain: one row = one project lifecycle record
--  Source: projects + employees + departments
--  DimDate is role-played twice (start_date_sk, end_date_sk)
--  Row is CREATED at project initiation and UPDATED as milestones complete
-- -------------------------------------------------------------
CREATE TABLE FactProjectHR (
    project_sk              INT             NOT NULL IDENTITY(1,1),

    -- Foreign keys (DimDate role-played twice)
    start_date_sk           INT             NOT NULL,   -- FK -> DimDate (project start)
    end_date_sk             INT             NULL,       -- FK -> DimDate (project end, NULL until complete)

    department_sk           INT             NOT NULL,   -- FK -> DimDepartment
    employee_sk             INT             NOT NULL,   -- FK -> DimEmployee (project lead)

    -- Source natural key (audit / upsert key)
    project_id              INT             NOT NULL,

    -- Measures
    project_budget          DECIMAL(18,2)   NOT NULL,   -- Additive
    duration_days           INT             NULL,       -- Semi-additive (NULL until end_date known)
    dept_salary_expenditure DECIMAL(18,2)   NOT NULL,   -- Semi-additive (snapshot of dept salary sum)

    CONSTRAINT PK_FactProjectHR             PRIMARY KEY (project_sk),
    CONSTRAINT UQ_FactProjectHR_source_nk   UNIQUE      (project_id),
    CONSTRAINT FK_FactProjectHR_StartDate   FOREIGN KEY (start_date_sk)
        REFERENCES DimDate        (date_sk),
    CONSTRAINT FK_FactProjectHR_EndDate     FOREIGN KEY (end_date_sk)
        REFERENCES DimDate        (date_sk),
    CONSTRAINT FK_FactProjectHR_Dept        FOREIGN KEY (department_sk)
        REFERENCES DimDepartment  (department_sk),
    CONSTRAINT FK_FactProjectHR_Employee    FOREIGN KEY (employee_sk)
        REFERENCES DimEmployee    (employee_sk)
);

CREATE INDEX IX_FactProjectHR_StartDate  ON FactProjectHR (start_date_sk);
CREATE INDEX IX_FactProjectHR_EndDate    ON FactProjectHR (end_date_sk);
CREATE INDEX IX_FactProjectHR_Dept       ON FactProjectHR (department_sk);
CREATE INDEX IX_FactProjectHR_Employee   ON FactProjectHR (employee_sk);


-- =============================================================
--  END OF SCRIPT
--  Table creation order summary:
--    1. DimDate
--    2. DimProduct
--    3. DimCustomer
--    4. DimSupplier
--    5. DimDepartment
--    6. DimEmployee       (depends on DimDepartment)
--    7. FactSales         (depends on DimDate, DimProduct, DimCustomer)
--    8. FactSupplyChain   (depends on DimDate, DimSupplier, DimProduct)
--    9. FactProjectHR     (depends on DimDate x2, DimDepartment, DimEmployee)
-- =============================================================
