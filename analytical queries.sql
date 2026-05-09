-- Q1: KPI 1 - Total Revenue by Region and Product Category
SELECT 
    s.region,
    p.category,
    SUM(s.revenue) AS TotalRevenue
FROM FactSales s
JOIN DimProduct p ON s.product_sk = p.product_sk
GROUP BY s.region, p.category
ORDER BY TotalRevenue DESC;

-- Q2: KPI 2 - Monthly Sales Volume Trend
-- Source sales table has only one month
SELECT 
    d.year,
    d.month_number,
    d.month_name,
    SUM(s.quantity_sold) AS TotalUnitsSold
FROM FactSales s
JOIN DimDate d ON s.date_sk = d.date_sk
GROUP BY d.year, d.month_number, d.month_name
ORDER BY d.year, d.month_number;

-- Q3: KPI 3 - Revenue by Customer Industry
SELECT 
    c.industry,
    SUM(s.revenue) AS TotalRevenue,
    COUNT(DISTINCT c.customer_id) AS CustomerCount,
    SUM(s.quantity_sold) AS TotalUnitsSold
FROM FactSales s
JOIN DimCustomer c ON s.customer_sk = c.customer_sk
GROUP BY c.industry
ORDER BY TotalRevenue DESC;

-- Q4: Top 10 Customers by Revenue
SELECT TOP 10
    c.customer_name,
    c.industry,
    SUM(s.revenue) AS TotalRevenue,
    SUM(s.quantity_sold) AS TotalUnits
FROM FactSales s
JOIN DimCustomer c ON s.customer_sk = c.customer_sk
GROUP BY c.customer_name, c.industry
ORDER BY TotalRevenue DESC;

-- Q5: Seasonal Analysis - Quarterly Revenue by Category
SELECT 
    d.year,
    d.quarter,
    p.category,
    SUM(s.revenue) AS QuarterlyRevenue,
    SUM(s.quantity_sold) AS QuarterlyUnits
FROM FactSales s
JOIN DimDate d ON s.date_sk = d.date_sk
JOIN DimProduct p ON s.product_sk = p.product_sk
GROUP BY d.year, d.quarter, p.category
ORDER BY d.year, d.quarter, QuarterlyRevenue DESC;


-- -----------------------------------------------------------------

-- Q6: KPI 4 - Supply Chain Volume by Vendor
SELECT 
    sup.supplier_name,
    sup.material_supplied,
    SUM(sc.quantity_supplied) AS TotalQuantitySupplied
FROM FactSupplyChain sc
JOIN DimSupplier sup ON sc.supplier_sk = sup.supplier_sk
WHERE sup.is_current = 1
GROUP BY sup.supplier_name, sup.material_supplied
ORDER BY TotalQuantitySupplied DESC;

-- Q7: Monthly Inbound Supply Trend
SELECT 
    d.year,
    d.month_name,
    COUNT(DISTINCT sup.supplier_name) AS ActiveSuppliers,
    SUM(sc.quantity_supplied) AS TotalQuantity
FROM FactSupplyChain sc
JOIN DimDate d ON sc.date_sk = d.date_sk
JOIN DimSupplier sup ON sc.supplier_sk = sup.supplier_sk
GROUP BY d.year, d.month_number, d.month_name
ORDER BY d.year, d.month_number;

-- Q8: Top Products by Supply Quantity Received
SELECT TOP 10
    p.product_name,
    p.category,
    SUM(sc.quantity_supplied) AS TotalReceived
FROM FactSupplyChain sc
JOIN DimProduct p ON sc.product_sk = p.product_sk
GROUP BY p.product_name, p.category
ORDER BY TotalReceived DESC;

---------------------------------------------------------

-- Q9: KPI 5 - Departmental Project Budget Allocation
SELECT 
    d.department_name,
    d.location,
    COUNT(p.project_id) AS ProjectCount,
    SUM(p.project_budget) AS TotalBudget,
    AVG(p.project_budget) AS AvgBudgetPerProject
FROM FactProjectHR p
JOIN DimDepartment d ON p.department_sk = d.department_sk
WHERE d.is_current = 1
GROUP BY d.department_name, d.location
ORDER BY TotalBudget DESC;

-- Q10: KPI 6 - Average Project Duration by Department
SELECT 
    dep.department_name,
    COUNT(proj.project_id) AS CompletedProjects,
    AVG(proj.duration_days) AS AvgDurationDays,
    MIN(proj.duration_days) AS MinDurationDays,
    MAX(proj.duration_days) AS MaxDurationDays
FROM FactProjectHR proj
JOIN DimDepartment dep ON proj.department_sk = dep.department_sk
WHERE proj.end_date_sk IS NOT NULL
  AND dep.is_current = 1
GROUP BY dep.department_name
ORDER BY AvgDurationDays;

-- Q11: KPI 7 - Departmental Salary Expenditure
SELECT 
    dep.department_name,
    dep.location,
    SUM(proj.dept_salary_expenditure) AS TotalSalaryExpenditure,
    COUNT(DISTINCT proj.employee_sk) AS UniqueEmployeesTracked
FROM FactProjectHR proj
JOIN DimDepartment dep ON proj.department_sk = dep.department_sk
WHERE dep.is_current = 1
GROUP BY dep.department_name, dep.location
ORDER BY TotalSalaryExpenditure DESC;