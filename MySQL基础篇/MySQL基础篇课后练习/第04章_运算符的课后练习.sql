# 第04章_运算符课后练习

# 1.选择工资不在5000到12000的员工的姓名和工资

SELECT last_name,salary
FROM employees
#where salary not between 5000 and 12000;
WHERE salary < 5000 OR salary > 12000;

# 2.选择在20或50号部门工作的员工姓名和部门号
SELECT last_name,department_id
FROM employees
# where department_id in (20,50);
WHERE department_id = 20 OR department_id = 50;

# 3.选择公司中没有管理者的员工姓名及job_id

SELECT last_name,job_id,manager_id
FROM employees
WHERE manager_id IS NULL;

SELECT last_name,job_id,manager_id
FROM employees
WHERE manager_id <=> NULL;

# 4.选择公司中有奖金的员工姓名，工资和奖金级别
SELECT last_name,salary,commission_pct
FROM employees
WHERE commission_pct IS NOT NULL;


SELECT last_name,salary,commission_pct
FROM employees
WHERE NOT commission_pct <=> NULL;


# 5.选择员工姓名的第三个字母是a的员工姓名

SELECT last_name
FROM employees
WHERE last_name LIKE '__a%';


# 6.选择姓名中有字母a和k的员工姓名

SELECT last_name
FROM employees
WHERE last_name LIKE '%a%k%' OR last_name LIKE '%k%a%';
#where last_name like '%a%' and last_name LIKE '%k%';

# 7.显示出表 employees 表中 first_name 以 'e'结尾的员工信息

SELECT first_name,last_name
FROM employees
WHERE first_name LIKE '%e';

SELECT first_name,last_name
FROM employees
WHERE first_name REGEXP 'e$'; # 以e开头的写法：'^e'

# 8.显示出表 employees 部门编号在 80-100 之间的姓名、工种
SELECT last_name,job_id
FROM employees
#方式1：推荐
WHERE department_id BETWEEN 80 AND 100;
#方式2：推荐，与方式1相同
#where department_id >= 80 and department_id <= 100;
#方式3：仅适用于本题的方式。
#where department_id in (80,90,100);

SELECT * FROM departments;

# 9.显示出表 employees 的 manager_id 是 100,101,110 的员工姓名、工资、管理者id

SELECT last_name,salary,manager_id
FROM employees
WHERE manager_id IN (100,101,110);


