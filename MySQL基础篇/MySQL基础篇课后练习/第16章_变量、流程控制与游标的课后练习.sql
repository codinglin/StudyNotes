#第16章_变量、流程控制与游标的课后练习

/*
变量：
	系统变量 （全局系统变量、会话系统变量）
	
	用户自定义变量（会话用户变量、局部变量）

*/
#练习1：测试变量的使用  

#存储函数的练习

#0. 准备工作
CREATE DATABASE test16_var_cursor;

USE test16_var_cursor;

CREATE TABLE employees
AS
SELECT * FROM atguigudb.`employees`;

CREATE TABLE departments
AS
SELECT * FROM atguigudb.`departments`;

SET GLOBAL log_bin_trust_function_creators = 1;

#无参有返回
#1. 创建函数get_count(),返回公司的员工个数

DELIMITER $

CREATE FUNCTION get_count()
RETURNS INT

BEGIN
	#声明局部变量
	DECLARE emp_count INT;
	
	#赋值
	SELECT COUNT(*) INTO emp_count FROM employees;
	
	RETURN emp_count;
END $

DELIMITER ;

#调用
SELECT get_count();


#有参有返回
#2. 创建函数ename_salary(),根据员工姓名，返回它的工资

DELIMITER $

CREATE FUNCTION ename_salary(emp_name VARCHAR(15))
RETURNS DOUBLE

BEGIN
	#声明变量
	SET @sal = 0; #定义了一个会话用户变量
	
	#赋值
	SELECT salary INTO @sal FROM employees WHERE last_name = emp_name;	
	
	RETURN @sal;
END $

DELIMITER ;

#调用
SELECT ename_salary('Abel');

SELECT @sal;


#3. 创建函数dept_sal() ,根据部门名，返回该部门的平均工资

DELIMITER //

CREATE FUNCTION dept_sal(dept_name VARCHAR(15))
RETURNS DOUBLE

BEGIN
	DECLARE avg_sal DOUBLE;
	
	SELECT AVG(salary) INTO avg_sal
	FROM employees e JOIN departments d
	ON e.department_id = d.department_id
	WHERE d.department_name = dept_name;
	
	RETURN avg_sal;

END //

DELIMITER ;

#调用

SELECT * FROM departments;

SELECT dept_sal('Marketing');


#4. 创建函数add_float()，实现传入两个float，返回二者之和

DELIMITER //

CREATE FUNCTION add_float(value1 FLOAT,value2 FLOAT)
RETURNS FLOAT

BEGIN
	DECLARE sum_val FLOAT ;
	SET sum_val = value1 + value2;
	RETURN sum_val;

END //

DELIMITER ;

# 调用
SET @v1 := 12.2;
SET @v2 = 2.3;
SELECT add_float(@v1,@v2);


#2. 流程控制

/*
分支：if \ case ... when \ case when ...
循环：loop \ while \ repeat
其它：leave \ iterate

*/

#1. 创建函数test_if_case()，实现传入成绩，如果成绩>90,返回A，如果成绩>80,返回B，如果成绩>60,返回C，否则返回D
#要求：分别使用if结构和case结构实现

#方式1：if
DELIMITER $

CREATE FUNCTION test_if_case1(score DOUBLE)
RETURNS CHAR
BEGIN
	#声明变量
	DECLARE score_level CHAR;
	IF score > 90
		THEN SET score_level = 'A';
	ELSEIF score > 80 
		THEN SET score_level = 'B';
	ELSEIF score > 60
		THEN SET score_level = 'C';
	ELSE
		SET score_level = 'D';
	END IF;
	
	#返回
	RETURN score_level;

END $

DELIMITER ;

#调用
SELECT test_if_case1(56);


#方式2：case when ...
DELIMITER $

CREATE FUNCTION test_if_case2(score DOUBLE)
RETURNS CHAR
BEGIN
	#声明变量
	DECLARE score_level CHAR;
	
	CASE
	WHEN score > 90 THEN SET score_level = 'A';
	WHEN score > 80 THEN SET score_level = 'B';
	WHEN score > 60 THEN SET score_level = 'C';
	ELSE SET score_level = 'D';
	END CASE;
	
	#返回
	RETURN score_level;

END $

DELIMITER ;

#调用
SELECT test_if_case2(76);


#2. 创建存储过程test_if_pro()，传入工资值，如果工资值<3000,则删除工资为此值的员工，
# 如果3000 <= 工资值 <= 5000,则修改此工资值的员工薪资涨1000，否则涨工资500

DELIMITER $

CREATE PROCEDURE test_if_pro(IN sal DOUBLE)

BEGIN
	IF sal < 3000
		THEN DELETE FROM employees WHERE salary = sal;
	ELSEIF sal <= 5000
		THEN UPDATE employees SET salary = salary + 1000 WHERE salary = sal;
	ELSE 
		UPDATE employees SET salary = salary + 500 WHERE salary = sal;
	END IF;

END $

DELIMITER ;

#调用
CALL test_if_pro(24000);

SELECT * FROM employees;



#3. 创建存储过程insert_data(),传入参数为 IN 的 INT 类型变量 insert_count,实现向admin表中
#批量插入insert_count条记录

CREATE TABLE admin(
id INT PRIMARY KEY AUTO_INCREMENT,
user_name VARCHAR(25) NOT NULL,
user_pwd VARCHAR(35) NOT NULL
);

SELECT * FROM admin;

DELIMITER $

CREATE PROCEDURE insert_data(IN insert_count INT)

BEGIN
	#声明变量
	DECLARE init_count INT DEFAULT 1; #①初始化条件
	
	WHILE init_count <= insert_count DO #② 循环条件
		#③ 循环体
		INSERT INTO admin(user_name,user_pwd) VALUES (CONCAT('atguigu-',init_count),ROUND(RAND()*1000000));
		#④ 迭代条件
		SET init_count = init_count + 1;
	END WHILE;

END $


DELIMITER ;

#调用
CALL insert_data(100);

#3. 游标的使用

#创建存储过程update_salary()，参数1为 IN 的INT型变量dept_id，表示部门id；
#参数2为 IN的INT型变量change_sal_count，表示要调整薪资的员工个数。查询指定id部门的员工信息，
#按照salary升序排列，根据hire_date的情况，调整前change_sal_count个员工的薪资，详情如下。

DELIMITER $

CREATE PROCEDURE update_salary(IN dept_id INT,IN change_sal_count INT)
BEGIN
	#声明变量
	DECLARE emp_id INT ;#记录员工id
	DECLARE emp_hire_date DATE; #记录员工入职时间
	
	DECLARE init_count INT DEFAULT 1; #用于表示循环结构的初始化条件
	DECLARE add_sal_rate DOUBLE ; #记录涨薪的比例
	
	#声明游标
	DECLARE emp_cursor CURSOR FOR SELECT employee_id,hire_date FROM employees 
	WHERE department_id = dept_id ORDER BY salary ASC;
	
	#打开游标
	OPEN emp_cursor;
	
	WHILE init_count <= change_sal_count DO

		#使用游标
		FETCH emp_cursor INTO emp_id,emp_hire_date;
		
		#获取涨薪的比例
		IF (YEAR(emp_hire_date) < 1995)
			THEN SET add_sal_rate = 1.2;
		ELSEIF(YEAR(emp_hire_date) <= 1998)
			THEN SET add_sal_rate = 1.15;
		ELSEIF(YEAR(emp_hire_date) <= 2001)
			THEN SET add_sal_rate = 1.10;
		ELSE
			SET add_sal_rate = 1.05;
		END IF;
		
		#涨薪操作
		UPDATE employees SET salary = salary * add_sal_rate
		WHERE employee_id = emp_id;
		
		#迭代条件的更新
		SET init_count = init_count + 1;
	
	END WHILE;
	
	#关闭游标
	CLOSE emp_cursor;

END $


DELIMITER ;


#调用
CALL update_salary(50,3);


SELECT employee_id,hire_date,salary
FROM employees
WHERE department_id = 50
ORDER BY salary ASC;
