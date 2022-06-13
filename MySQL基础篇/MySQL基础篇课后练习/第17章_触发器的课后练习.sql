#第17章_触发器的课后练习

#练习1：

#0. 准备工作

CREATE DATABASE test17_trigger;

USE test17_trigger;

CREATE TABLE emps
AS
SELECT employee_id,last_name,salary
FROM atguigudb.`employees`;

SELECT * FROM emps;

#1. 复制一张emps表的空表emps_back，只有表结构，不包含任何数据

CREATE TABLE emps_back
AS
SELECT * FROM emps
WHERE 1 = 2;


#2. 查询emps_back表中的数据
SELECT * FROM emps_back;


#3. 创建触发器emps_insert_trigger，每当向emps表中添加一条记录时，同步将这条记录
#添加到emps_back表中

DELIMITER //

CREATE TRIGGER emps_insert_trigger
AFTER INSERT ON emps
FOR EACH ROW
BEGIN
	#将新添加到emps表中的记录添加到emps_back表中
	INSERT INTO emps_back(employee_id,last_name,salary)
	VALUES(NEW.employee_id,NEW.last_name,NEW.salary);
END //

DELIMITER ;

#show triggers;


#4. 验证触发器是否起作用
SELECT * FROM emps;

SELECT * FROM emps_back;

INSERT INTO emps(employee_id,last_name,salary)
VALUES(301,'Tom1',3600);


#练习2：
#0. 准备工作：使用练习1中的emps表

#1. 复制一张emps表的空表emps_back1，只有表结构，不包含任何数据

CREATE TABLE emps_back1
AS
SELECT * 
FROM emps
WHERE 1 = 2;


#2. 查询emps_back1表中的数据

SELECT * FROM emps_back1;


#3. 创建触发器emps_del_trigger，每当向emps表中删除一条记录时，同步将删除的这条记录添加到emps_back1表中

DELIMITER //

CREATE TRIGGER emps_del_trigger
BEFORE DELETE ON emps
FOR EACH ROW
BEGIN
	#将emps表中删除的记录，添加到emps_back1表中。
	INSERT INTO emps_back1(employee_id,last_name,salary)
	VALUES(OLD.employee_id,OLD.last_name,OLD.salary);
END //

DELIMITER ;


#4. 验证触发器是否起作用

DELETE FROM emps
WHERE employee_id = 101;


DELETE FROM emps;

SELECT * FROM emps;


SELECT * FROM emps_back1;
