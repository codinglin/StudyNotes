# 第06章_多表查询

/*
SELECT ...,....,....
FROM ....
WHERE .... AND / OR / NOT....
ORDER BY .... (ASC/DESC),....,...
LIMIT ...,...

*/
#1. 熟悉常见的几个表
DESC employees;

DESC departments;

DESC locations;

#查询员工名为'Abel'的人在哪个城市工作？
SELECT * 
FROM employees
WHERE last_name = 'Abel';

SELECT *
FROM departments
WHERE department_id = 80;


SELECT *
FROM locations 
WHERE location_id = 2500;

#2. 出现笛卡尔积的错误
#错误的原因：缺少了多表的连接条件

#错误的实现方式：每个员工都与每个部门匹配了一遍。
SELECT employee_id,department_name
FROM employees,departments;  #查询出2889条记录

#错误的方式
SELECT employee_id,department_name
FROM employees CROSS JOIN departments;#查询出2889条记录


SELECT *
FROM employees;  #107条记录

SELECT 2889 / 107
FROM DUAL;

SELECT *
FROM departments; # 27条记录


#3. 多表查询的正确方式：需要有连接条件

SELECT employee_id,department_name
FROM employees,departments
#两个表的连接条件
WHERE employees.`department_id` = departments.department_id;

#4. 如果查询语句中出现了多个表中都存在的字段，则必须指明此字段所在的表。
SELECT employees.employee_id,departments.department_name,employees.department_id
FROM employees,departments
WHERE employees.`department_id` = departments.department_id;

#建议：从sql优化的角度，建议多表查询时，每个字段前都指明其所在的表。

#5. 可以给表起别名，在SELECT和WHERE中使用表的别名。
SELECT emp.employee_id,dept.department_name,emp.department_id
FROM employees emp,departments dept
WHERE emp.`department_id` = dept.department_id;

#如果给表起了别名，一旦在SELECT或WHERE中使用表名的话，则必须使用表的别名，而不能再使用表的原名。
#如下的操作是错误的：
SELECT emp.employee_id,departments.department_name,emp.department_id
FROM employees emp,departments dept
WHERE emp.`department_id` = departments.department_id;


#6. 结论：如果有n个表实现多表的查询，则需要至少n-1个连接条件
#练习：查询员工的employee_id,last_name,department_name,city
SELECT e.employee_id,e.last_name,d.department_name,l.city,e.department_id,l.location_id
FROM employees e,departments d,locations l
WHERE e.`department_id` = d.`department_id`
AND d.`location_id` = l.`location_id`;

/*
演绎式：提出问题1 ---> 解决问题1 ----> 提出问题2 ---> 解决问题2 ....

归纳式：总--分

*/
#7. 多表查询的分类
/*

角度1：等值连接  vs  非等值连接

角度2：自连接  vs  非自连接

角度3：内连接  vs  外连接


*/

# 7.1 等值连接  vs  非等值连接

#非等值连接的例子：
SELECT *
FROM job_grades;

SELECT e.last_name,e.salary,j.grade_level
FROM employees e,job_grades j
#where e.`salary` between j.`lowest_sal` and j.`highest_sal`;
WHERE e.`salary` >= j.`lowest_sal` AND e.`salary` <= j.`highest_sal`;

#7.2 自连接  vs  非自连接

SELECT * FROM employees;

#自连接的例子：
#练习：查询员工id,员工姓名及其管理者的id和姓名

SELECT emp.employee_id,emp.last_name,mgr.employee_id,mgr.last_name
FROM employees emp ,employees mgr
WHERE emp.`manager_id` = mgr.`employee_id`;


#7.3 内连接  vs  外连接

# 内连接：合并具有同一列的两个以上的表的行, 结果集中不包含一个表与另一个表不匹配的行
SELECT employee_id,department_name
FROM employees e,departments d
WHERE e.`department_id` = d.department_id;  #只有106条记录

# 外连接：合并具有同一列的两个以上的表的行, 结果集中除了包含一个表与另一个表匹配的行之外，
#         还查询到了左表 或 右表中不匹配的行。

# 外连接的分类：左外连接、右外连接、满外连接

# 左外连接：两个表在连接过程中除了返回满足连接条件的行以外还返回左表中不满足条件的行，这种连接称为左外连接。
# 右外连接：两个表在连接过程中除了返回满足连接条件的行以外还返回右表中不满足条件的行，这种连接称为右外连接。

#练习：查询所有的员工的last_name,department_name信息 

SELECT employee_id,department_name
FROM employees e,departments d
WHERE e.`department_id` = d.department_id;   # 需要使用左外连接

#SQL92语法实现内连接：见上，略
#SQL92语法实现外连接：使用 +  ----------MySQL不支持SQL92语法中外连接的写法！
#不支持：
SELECT employee_id,department_name
FROM employees e,departments d
WHERE e.`department_id` = d.department_id(+);

#SQL99语法中使用 JOIN ...ON 的方式实现多表的查询。这种方式也能解决外连接的问题。MySQL是支持此种方式的。
#SQL99语法如何实现多表的查询。

#SQL99语法实现内连接：
SELECT last_name,department_name
FROM employees e INNER JOIN departments d
ON e.`department_id` = d.`department_id`;

SELECT last_name,department_name,city
FROM employees e JOIN departments d
ON e.`department_id` = d.`department_id`
JOIN locations l
ON d.`location_id` = l.`location_id`;

#SQL99语法实现外连接：

#练习：查询所有的员工的last_name,department_name信息 
# 左外连接：
SELECT last_name,department_name
FROM employees e LEFT JOIN departments d
ON e.`department_id` = d.`department_id`;

#右外连接：
SELECT last_name,department_name
FROM employees e RIGHT OUTER JOIN departments d
ON e.`department_id` = d.`department_id`;


#满外连接：mysql不支持FULL OUTER JOIN
SELECT last_name,department_name
FROM employees e FULL OUTER JOIN departments d
ON e.`department_id` = d.`department_id`;

#8. UNION  和 UNION ALL的使用
# UNION：会执行去重操作
# UNION ALL:不会执行去重操作
#结论：如果明确知道合并数据后的结果数据不存在重复数据，或者不需要去除重复的数据，
#则尽量使用UNION ALL语句，以提高数据查询的效率。

#9. 7种JOIN的实现：

# 中图：内连接
SELECT employee_id,department_name
FROM employees e JOIN departments d
ON e.`department_id` = d.`department_id`;

# 左上图：左外连接
SELECT employee_id,department_name
FROM employees e LEFT JOIN departments d
ON e.`department_id` = d.`department_id`;

# 右上图：右外连接
SELECT employee_id,department_name
FROM employees e RIGHT JOIN departments d
ON e.`department_id` = d.`department_id`;

# 左中图：
SELECT employee_id,department_name
FROM employees e LEFT JOIN departments d
ON e.`department_id` = d.`department_id`
WHERE d.`department_id` IS NULL;

# 右中图：
SELECT employee_id,department_name
FROM employees e RIGHT JOIN departments d
ON e.`department_id` = d.`department_id`
WHERE e.`department_id` IS NULL;


# 左下图：满外连接
# 方式1：左上图 UNION ALL 右中图

SELECT employee_id,department_name
FROM employees e LEFT JOIN departments d
ON e.`department_id` = d.`department_id`
UNION ALL
SELECT employee_id,department_name
FROM employees e RIGHT JOIN departments d
ON e.`department_id` = d.`department_id`
WHERE e.`department_id` IS NULL;


# 方式2：左中图 UNION ALL 右上图

SELECT employee_id,department_name
FROM employees e LEFT JOIN departments d
ON e.`department_id` = d.`department_id`
WHERE d.`department_id` IS NULL
UNION ALL
SELECT employee_id,department_name
FROM employees e RIGHT JOIN departments d
ON e.`department_id` = d.`department_id`;

# 右下图：左中图  UNION ALL 右中图
SELECT employee_id,department_name
FROM employees e LEFT JOIN departments d
ON e.`department_id` = d.`department_id`
WHERE d.`department_id` IS NULL
UNION ALL
SELECT employee_id,department_name
FROM employees e RIGHT JOIN departments d
ON e.`department_id` = d.`department_id`
WHERE e.`department_id` IS NULL;

#10. SQL99语法的新特性1:自然连接

SELECT employee_id,last_name,department_name
FROM employees e JOIN departments d
ON e.`department_id` = d.`department_id`
AND e.`manager_id` = d.`manager_id`;

# NATURAL JOIN : 它会帮你自动查询两张连接表中`所有相同的字段`，然后进行`等值连接`。
SELECT employee_id,last_name,department_name
FROM employees e NATURAL JOIN departments d;


#11. SQL99语法的新特性2:USING
SELECT employee_id,last_name,department_name
FROM employees e JOIN departments d
ON e.department_id = d.department_id;

SELECT employee_id,last_name,department_name
FROM employees e JOIN departments d
USING (department_id);


#拓展：
SELECT last_name,job_title,department_name 
FROM employees INNER JOIN departments INNER JOIN jobs 
ON employees.department_id = departments.department_id 
AND employees.job_id = jobs.job_id;