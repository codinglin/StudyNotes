#第18章_MySQL8.0的其它新特性的课后练习

#1. 创建students数据表，如下

CREATE DATABASE test18_mysql8;

USE test18_mysql8;

CREATE TABLE students(
id INT PRIMARY KEY AUTO_INCREMENT,
student VARCHAR(15),
points TINYINT
);

#2. 向表中添加数据如下
INSERT INTO students(student,points)
VALUES
('张三',89),
('李四',77),
('王五',88),
('赵六',90),
('孙七',90),
('周八',88);

SELECT * FROM students;

#3. 分别使用RANK()、DENSE_RANK() 和 ROW_NUMBER()函数对学生成绩降序排列情况进行显示
#方式1：
SELECT 
ROW_NUMBER() OVER (ORDER BY points DESC) AS "排序1",
RANK() OVER (ORDER BY points DESC) AS "排序2",
DENSE_RANK() OVER (ORDER BY points DESC) AS "排序3",
student,points
FROM students;


#方式2：
SELECT 
ROW_NUMBER() OVER w AS "排序1",
RANK() OVER w AS "排序2",
DENSE_RANK() OVER w AS "排序3",
student,points
FROM students WINDOW w AS (ORDER BY points DESC);

