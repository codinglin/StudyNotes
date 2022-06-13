#第13章_约束的课后练习

#练习1：
CREATE DATABASE test04_emp;

USE test04_emp;

CREATE TABLE emp2(
id INT,
emp_name VARCHAR(15)
);

CREATE TABLE dept2(
id INT,
dept_name VARCHAR(15)
);

#1.向表emp2的id列中添加PRIMARY KEY约束

ALTER TABLE emp2
ADD CONSTRAINT pk_emp2_id PRIMARY KEY(id);


#2.向表dept2的id列中添加PRIMARY KEY约束

ALTER TABLE dept2
ADD PRIMARY KEY(id);


#3.向表emp2中添加列dept_id，并在其中定义FOREIGN KEY约束，与之相关联的列是dept2表中的id列。

ALTER TABLE emp2
ADD dept_id INT;

DESC emp2;

ALTER TABLE emp2
ADD CONSTRAINT fk_emp2_deptid FOREIGN KEY(dept_id) REFERENCES dept2(id);

#练习2：
#承接《第11章_数据处理之增删改》的综合案例。
USE test01_library;

DESC books;

#根据题目要求给books表中的字段添加约束
#方式1：
ALTER TABLE books
ADD PRIMARY KEY (id);

ALTER TABLE books
MODIFY id INT AUTO_INCREMENT;
#方式2：
ALTER TABLE books
MODIFY id INT PRIMARY KEY AUTO_INCREMENT;


#针对于非id字段的操作
ALTER TABLE books
MODIFY NAME VARCHAR(50) NOT NULL;

ALTER TABLE books
MODIFY AUTHORS VARCHAR(100) NOT NULL;

ALTER TABLE books
MODIFY price FLOAT NOT NULL;

ALTER TABLE books
MODIFY pubdate YEAR NOT NULL;

ALTER TABLE books
MODIFY num INT NOT NULL;


#练习3：

#1. 创建数据库test04_company
CREATE DATABASE IF NOT EXISTS test04_company CHARACTER SET 'utf8';

USE test04_company;

#2. 按照下表给出的表结构在test04_company数据库中创建两个数据表offices和employees

CREATE TABLE IF NOT EXISTS offices(
officeCode INT(10) PRIMARY KEY ,
city VARCHAR(50) NOT NULL,
address VARCHAR(50) ,
country VARCHAR(50) NOT NULL,
postalCode VARCHAR(15),
CONSTRAINT uk_off_poscode UNIQUE(postalCode)

);

DESC offices;

CREATE TABLE employees(
employeeNumber INT PRIMARY KEY AUTO_INCREMENT,
lastName VARCHAR(50) NOT NULL,
firstName VARCHAR(50) NOT NULL,
mobile VARCHAR(25) UNIQUE,
officeCode INT(10) NOT NULL,
jobTitle VARCHAR(50) NOT NULL,
birth DATETIME NOT NULL,
note VARCHAR(255),
sex VARCHAR(5),
CONSTRAINT fk_emp_offcode FOREIGN KEY (officeCode) REFERENCES offices(officeCode)

);

DESC employees;

#3. 将表employees的mobile字段修改到officeCode字段后面
ALTER TABLE employees
MODIFY mobile VARCHAR(25) AFTER officeCode;

#4. 将表employees的birth字段改名为employee_birth
ALTER TABLE employees
CHANGE birth employee_birth DATETIME;

#5. 修改sex字段，数据类型为CHAR(1)，非空约束
ALTER TABLE employees
MODIFY sex CHAR(1) NOT NULL;


#6. 删除字段note
ALTER TABLE employees
DROP COLUMN note;

#7. 增加字段名favoriate_activity，数据类型为VARCHAR(100)
ALTER TABLE employees
ADD favoriate_activity VARCHAR(100);

#8. 将表employees名称修改为employees_info
RENAME TABLE employees
TO employees_info;

#错误：Table 'test04_company.employees' doesn't exist
DESC employees;

DESC employees_info;