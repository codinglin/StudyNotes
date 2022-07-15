# 第13章_事务基础知识

## 1. 数据库事务概述

### 1.1 存储引擎支持情况

`SHOW ENGINES` 命令来查看当前 MySQL 支持的存储引擎都有哪些，以及这些存储引擎是否支持事务。

![image-20220708124306444](MySQL事物篇.assets/image-20220708124306444.png)

能看出在 MySQL 中，只有InnoDB 是支持事务的。

### 1.2 基本概念

**事务：**一组逻辑操作单元，使数据从一种状态变换到另一种状态。

**事务处理的原则：**保证所有事务都作为 `一个工作单元` 来执行，即使出现了故障，都不能改变这种执行方 式。当在一个事务中执行多个操作时，要么所有的事务都被提交( `commit` )，那么这些修改就 `永久` 地保 `存下来`；要么数据库管理系统将 `放弃` 所作的所有 `修改` ，整个事务回滚( rollback )到最初状态。

```mysql
# 案例：AA用户给BB用户转账100
update account set money = money - 100 where name = 'AA';
# 服务器宕机
update account set money = money + 100 where name = 'BB';
```

### 1.3 事物的ACID特性

* **原子性（atomicity）：**

原子性是指事务是一个不可分割的工作单位，要么全部提交，要么全部失败回滚。即要么转账成功，要么转账失败，是不存在中间的状态。如果无法保证原子性会怎么样？就会出现数据不一致的情形，A账户减去100元，而B账户增加100元操作失败，系统将无故丢失100元。

* **一致性（consistency）：**

（国内很多网站上对一致性的阐述有误，具体你可以参考 Wikipedia 对Consistency的阐述）

根据定义，一致性是指事务执行前后，数据从一个 `合法性状态` 变换到另外一个 `合法性状态` 。这种状态是 `语义上` 的而不是语法上的，跟具体的业务有关。

那什么是合法的数据状态呢？满足 `预定的约束` 的状态就叫做合法的状态。通俗一点，这状态是由你自己来定义的（比如满足现实世界中的约束）。满足这个状态，数据就是一致的，不满足这个状态，数据就 是不一致的！如果事务中的某个操作失败了，系统就会自动撤销当前正在执行的事务，返回到事务操作 之前的状态。

**举例1：**A账户有200元，转账300元出去，此时A账户余额为-100元。你自然就发现此时数据是不一致的，为什么呢？因为你定义了一个状态，余额这列必须>=0。

**举例2：**A账户有200元，转账50元给B账户，A账户的钱扣了，但是B账户因为各种意外，余额并没有增加。你也知道此时的数据是不一致的，为什么呢？因为你定义了一个状态，要求A+B的总余额必须不变。

**举例3：**在数据表中我们将`姓名`字段设置为`唯一性约束`，这时当事务进行提交或者事务发生回滚的时候，如果数据表的姓名不唯一，就破坏了事物的一致性要求。

* **隔离型（isolation）：**

事务的隔离性是指一个事务的执行`不能被其他事务干扰`，即一个事务内部的操作及使用的数据对`并发`的其他事务是隔离的，并发执行的各个事务之间不能相互干扰。

如果无法保证隔离性会怎么样？假设A账户有200元，B账户0元。A账户往B账户转账两次，每次金额为50 元，分别在两个事务中执行。如果无法保证隔离性，会出现下面的情形：

```mysql
UPDATE accounts SET money = money - 50 WHERE NAME = 'AA';
UPDATE accounts SET money = money + 50 WHERE NAME = 'BB';
```

![image-20220708164610193](MySQL事物篇.assets/image-20220708164610193.png)

**持久性（durability）：**

持久性是指一个事务一旦被提交，它对数据库中数据的改变就是 永久性的 ，接下来的其他操作和数据库 故障不应该对其有任何影响。

持久性是通过 `事务日志` 来保证的。日志包括了 `重做日志` 和 `回滚日志` 。当我们通过事务对数据进行修改 的时候，首先会将数据库的变化信息记录到重做日志中，然后再对数据库中对应的行进行修改。这样做 的好处是，即使数据库系统崩溃，数据库重启后也能找到没有更新到数据库系统中的重做日志，重新执 行，从而使事务具有持久性。

> 总结
>
> ACID是事务的四大特征，在这四个特性中，原子性是基础，隔离性是手段，一致性是约束条件， 而持久性是我们的目的。
>
> 数据库事务，其实就是数据库设计者为了方便起见，把需要保证`原子性`、`隔离性`、`一致性`和`持久性`的一个或多个数据库操作称为一个事务。

### 1.4 事务的状态

我们现在知道 `事务` 是一个抽象的概念，它其实对应着一个或多个数据库操作，MySQL根据这些操作所执 行的不同阶段把 `事务` 大致划分成几个状态：

* **活动的（active）**

  事务对应的数据库操作正在执行过程中时，我们就说该事务处在 `活动的` 状态。

* **部分提交的（partially committed）**

  当事务中的最后一个操作执行完成，但由于操作都在内存中执行，所造成的影响并 `没有刷新到磁盘` 时，我们就说该事务处在 `部分提交的` 状态。

* **失败的（failed）**

  当事务处在 `活动的` 或者 部分提交的 状态时，可能遇到了某些错误（数据库自身的错误、操作系统 错误或者直接断电等）而无法继续执行，或者人为的停止当前事务的执行，我们就说该事务处在 失 败的 状态。

* **中止的（aborted）**

  如果事务执行了一部分而变为 `失败的` 状态，那么就需要把已经修改的事务中的操作还原到事务执 行前的状态。换句话说，就是要撤销失败事务对当前数据库造成的影响。我们把这个撤销的过程称之为 `回滚` 。当 `回滚` 操作执行完毕时，也就是数据库恢复到了执行事务之前的状态，我们就说该事 务处在了 `中止的` 状态。

  举例：

  ```mysql
  UPDATE accounts SET money = money - 50 WHERE NAME = 'AA';
  
  UPDATE accounts SET money = money + 50 WHERE NAME = 'BB';
  ```

* **提交的（committed）**

  当一个处在 `部分提交的` 状态的事务将修改过的数据都 `同步到磁盘` 上之后，我们就可以说该事务处在了 `提交的` 状态。

  一个基本的状态转换图如下所示：

  <img src="MySQL事物篇.assets/image-20220708171859055.png" alt="image-20220708171859055" style="zoom:80%;" />

  图中可见，只有当事物处于`提交的`或者`中止的`状态时，一个事务的生命周期才算是结束了。对于已经提交的事务来说，该事务对数据库所做的修改将永久生效，对于处于中止状态的事物，该事务对数据库所做的所有修改都会被回滚到没执行该事物之前的状态。

## 2. 如何使用事务

使用事务有两种方式，分别为 `显式事务` 和 `隐式事务` 。

### 2.1 显式事务

**步骤1：** START TRANSACTION 或者 BEGIN ，作用是显式开启一个事务。

```mysql
mysql> BEGIN;
#或者
mysql> START TRANSACTION;
```

`START TRANSACTION` 语句相较于 `BEGIN` 特别之处在于，后边能跟随几个 `修饰符` ：

① `READ ONLY` ：标识当前事务是一个 `只读事务` ，也就是属于该事务的数据库操作只能读取数据，而不能修改数据。

> 补充：只读事务中只是不允许修改那些其他事务也能访问到的表中的数据，对于临时表来说（我们使用 CREATE TMEPORARY TABLE 创建的表），由于它们只能再当前会话中可见，所有只读事务其实也是可以对临时表进行增、删、改操作的。

② `READ WRITE` ：标识当前事务是一个 `读写事务` ，也就是属于该事务的数据库操作既可以读取数据， 也可以修改数据。

③ `WITH CONSISTENT SNAPSHOT` ：启动一致性读。

比如：

```mysql
START TRANSACTION READ ONLY; # 开启一个只读事务
```

```mysql
START TRANSACTION READ ONLY, WITH CONSISTENT SNAPSHOT # 开启只读事务和一致性读
```

```mysql
START TRANSACTION READ WRITE, WITH CONSISTENT SNAPSHOT # 开启读写事务和一致性读
```

注意：

* `READ ONLY`和`READ WRITE`是用来设置所谓的事物`访问模式`的，就是以只读还是读写的方式来访问数据库中的数据，一个事务的访问模式不能同时即设置为`只读`的也设置为`读写`的，所以不能同时把`READ ONLY`和`READ WRITE`放到`START TRANSACTION`语句后边。
* 如果我们不显式指定事务的访问模式，那么该事务的访问模式就是`读写`模式

**步骤2：**一系列事务中的操作（主要是DML，不含DDL）

**步骤3：**提交事务 或 中止事务（即回滚事务）

```mysql
# 提交事务。当提交事务后，对数据库的修改是永久性的。
mysql> COMMIT;
```

```mysql
# 回滚事务。即撤销正在进行的所有没有提交的修改
mysql> ROLLBACK;

# 将事务回滚到某个保存点。
mysql> ROLLBACK TO [SAVEPOINT]
```

其中关于SAVEPOINT相关操作有：

```mysql
# 在事务中创建保存点，方便后续针对保存点进行回滚。一个事务中可以存在多个保存点。
SAVEPOINT 保存点名称;
```

```mysql
# 删除某个保存点
RELEASE SAVEPOINT 保存点名称;
```

### 2.2 隐式事务

MySQL中有一个系统变量 `autocommit` ：

```mysql
mysql> SHOW VARIABLES LIKE 'autocommit';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| autocommit    |  ON   |
+---------------+-------+
1 row in set (0.01 sec)
```

当然，如果我们想关闭这种 `自动提交` 的功能，可以使用下边两种方法之一：

* 显式的的使用 `START TRANSACTION` 或者 `BEGIN` 语句开启一个事务。这样在本次事务提交或者回滚前会暂时关闭掉自动提交的功能。

* 把系统变量 `autocommit` 的值设置为 `OFF` ，就像这样：

  ```mysql
  SET autocommit = OFF;
  #或
  SET autocommit = 0;
  ```

### 2.3 隐式提交数据的情况

* 数据定义语言（Data definition language，缩写为：DDL）

  数据库对象，指的就是`数据库、表、视图、存储过程`等结构。当我们`CREATE、ALTER、DROP`等语句去修改数据库对象时，就会隐式的提交前边语句所属于的事物。即：

  ```mysql
  BEGIN;
  
  SELECT ... # 事务中的一条语句
  UPDATE ... # 事务中的一条语句
  ... # 事务中的其他语句
  
  CREATE TABLE ... # 此语句会隐式的提交前边语句所属于的事务
  ```

* 隐式使用或修改mysql数据库中的表

  当我们使用`ALTER USER`、`CREATE USER`、`DROP USER`、`GRANT`、`RENAME USER`、`REVOKE`、`SET PASSWORD`等语句时也会隐式的提交前边语句所属于的事务。

* 事务控制或关于锁定的语句

  ① 当我们在一个事务还没提交或者回滚时就又使用 START TRANSACTION 或者 BEGIN 语句开启了另一个事务时，会隐式的提交上一个事务。即：

  ```mysql
  BEGIN;
  
  SELECT ... # 事务中的一条语句
  UPDATE ... # 事务中的一条语句
  ... # 事务中的其他语句
  
  BEGIN; # 此语句会隐式的提交前边语句所属于的事务
  ```

  ② 当前的 autocommit 系统变量的值为 OFF ，我们手动把它调为 ON 时，也会 隐式的提交前边语句所属的事务。

  ③ 使用 LOCK TABLES 、 UNLOCK TABLES 等关于锁定的语句也会 隐式的提交 前边语句所属的事务。

* 加载数据的语句

  使用`LOAD DATA`语句来批量往数据库中导入数据时，也会`隐式的提交`前边语句所属的事务。

* 关于MySQL复制的一些语句

  使用`START SLAVE、STOP SLAVE、RESET SLAVE、CHANGE MASTER TO`等语句会隐式的提交前边语句所属的事务

* 其他的一些语句

  使用`ANALYZE TABLE、CACHE INDEX、CAECK TABLE、FLUSH、LOAD INDEX INTO CACHE、OPTIMIZE TABLE、REPAIR TABLE、RESET`等语句也会隐式的提交前边语句所属的事务。

### 2.4 使用举例1：提交与回滚

我们看下在 MySQL 的默认状态下，下面这个事务最后的处理结果是什么。

**情况1：**

```mysql
CREATE TABLE user(name varchar(20), PRIMARY KEY (name)) ENGINE=InnoDB;

BEGIN;
INSERT INTO user SELECT '张三';
COMMIT;

BEGIN;
INSERT INTO user SELECT '李四';
INSERT INTO user SELECT '李四';
ROLLBACK;

SELECT * FROM user;
```

运行结果（1 行数据）：

```mysql
mysql> commit;
Query OK, 0 rows affected (0.00 秒)

mysql> BEGIN;
Query OK, 0 rows affected (0.00 秒)

mysql> INSERT INTO user SELECT '李四';
Query OK, 1 rows affected (0.00 秒)

mysql> INSERT INTO user SELECT '李四';
Duplicate entry '李四' for key 'user.PRIMARY'
mysql> ROLLBACK;
Query OK, 0 rows affected (0.01 秒)

mysql> select * from user;
+--------+
| name   |
+--------+
| 张三    |
+--------+
1 行于数据集 (0.01 秒)
```

**情况2：**

```mysql
CREATE TABLE user (name varchar(20), PRIMARY KEY (name)) ENGINE=InnoDB;

BEGIN;
INSERT INTO user SELECT '张三';
COMMIT;

INSERT INTO user SELECT '李四';
INSERT INTO user SELECT '李四';
ROLLBACK;
```

运行结果（2 行数据）：

```mysql
mysql> SELECT * FROM user;
+--------+
| name   |
+--------+
| 张三    |
| 李四    |
+--------+
2 行于数据集 (0.01 秒)
```

**情况3：**

```mysql
CREATE TABLE user(name varchar(255), PRIMARY KEY (name)) ENGINE=InnoDB;

SET @@completion_type = 1;
BEGIN;
INSERT INTO user SELECT '张三';
COMMIT;

INSERT INTO user SELECT '李四';
INSERT INTO user SELECT '李四';
ROLLBACK;

SELECT * FROM user;
```

运行结果（1 行数据）：

```mysql
mysql> SELECT * FROM user;
+--------+
| name   |
+--------+
| 张三    |
+--------+
1 行于数据集 (0.01 秒)
```

<img src="MySQL事物篇.assets/image-20220708201221316.png" alt="image-20220708201221316" style="float:left;" />

> 当我们设置 autocommit=0 时，不论是否采用 START TRANSACTION 或者 BEGIN 的方式来开启事 务，都需要用 COMMIT 进行提交，让事务生效，使用 ROLLBACK 对事务进行回滚。
>
> 当我们设置 autocommit=1 时，每条 SQL 语句都会自动进行提交。 不过这时，如果你采用 START TRANSACTION 或者 BEGIN 的方式来显式地开启事务，那么这个事务只有在 COMMIT 时才会生效， 在 ROLLBACK 时才会回滚。

### 2.5 使用举例2：测试不支持事务的engine

```mysql
CREATE TABLE test1(i INT) ENGINE=InnoDB;

CREATE TABLE test2(i INT) ENGINE=MYISAM;
```

针对于InnoDB表

```mysql
BEGIN;
INSERT INTO test1 VALUES(1);
ROLLBACK;

SELECT * FROM test1;
```

结果：没有数据

针对于MYISAM表：

```mysql
BEGIN;
INSERT INTO test1 VALUES(1);
ROLLBACK;

SELECT * FROM test2;
```

结果：有一条数据

### 2.6 使用举例3：SAVEPOINT

创建表并添加数据：

```mysql
CREATE TABLE account(
id INT PRIMARY KEY AUTO_INCREMENT,
NAME VARCHAR(15),
balance DECIMAL(10,2)
);

INSERT INTO account(NAME,balance)
VALUES
('张三',1000),
('李四',1000);
```

```mysql
BEGIN;
UPDATE account SET balance = balance - 100 WHERE NAME = '张三';
UPDATE account SET balance = balance - 100 WHERE NAME = '张三';
SAVEPOINT s1; # 设置保存点
UPDATE account SET balance = balance + 1 WHERE NAME = '张三';
ROLLBACK TO s1; # 回滚到保存点
```

结果：张三：800.00

```mysql
ROLLBACK;
```

结果：张三：1000.00

## 3. 事务隔离级别

MySQL是一个 `客户端／服务器` 架构的软件，对于同一个服务器来说，可以有若干个客户端与之连接，每 个客户端与服务器连接上之后，就可以称为一个会话（ `Session` ）。每个客户端都可以在自己的会话中 向服务器发出请求语句，一个请求语句可能是某个事务的一部分，也就是对于服务器来说可能同时处理多个事务。事务有 `隔离性` 的特性，理论上在某个事务 `对某个数据进行访问` 时，其他事务应该进行`排队` ，当该事务提交之后，其他事务才可以继续访问这个数据。但是这样对 `性能影响太大` ，我们既想保持事务的隔离性，又想让服务器在处理访问同一数据的多个事务时 `性能尽量高些` ，那就看二者如何权衡取 舍了。

### 3.1 数据准备

```mysql
CREATE TABLE student (
    studentno INT,
    name VARCHAR(20),
    class varchar(20),
    PRIMARY KEY (studentno)
) Engine=InnoDB CHARSET=utf8;
```

然后向这个表里插入一条数据：

```mysql
INSERT INTO student VALUES(1, '小谷', '1班');
```

现在表里的数据就是这样的：

```mysql
mysql> select * from student;
+-----------+--------+-------+
| studentno | name   | class |
+-----------+--------+-------+
|      1    |   小谷  | 1班   |
+-----------+--------+-------+
1 row in set (0.00 sec)
```

### 3.2 数据并发问题

针对事务的隔离性和并发性，我们怎么做取舍呢？先看一下访问相同数据的事务在 不保证串行执行 （也 就是执行完一个再执行另一个）的情况下可能会出现哪些问题：

**1. 脏写（ Dirty Write ）**

对于两个事务 Session A、Session B，如果事务Session A `修改了` 另一个 `未提交` 事务Session B `修改过` 的数据，那就意味着发生了 `脏写`，示意图如下：

![image-20220708214453902](MySQL事物篇.assets/image-20220708214453902.png)

Session A 和 Session B 各开启了一个事务，Sesssion B 中的事务先将studentno列为1的记录的name列更新为'李四'，然后Session A中的事务接着又把这条studentno列为1的记录的name列更新为'张三'。如果之后Session B中的事务进行了回滚，那么Session A中的更新也将不复存在，这种现象称之为脏写。这时Session A中的事务就没有效果了，明明把数据更新了，最后也提交事务了，最后看到的数据什么变化也没有。这里大家对事务的隔离性比较了解的话，会发现默认隔离级别下，上面Session A中的更新语句会处于等待状态，这里只是跟大家说明一下会出现这样的现象。

**2. 脏读（ Dirty Read ）**

 对于两个事务 Session A、Session B，Session A `读取` 了已经被 Session B `更新` 但还 `没有被提交` 的字段。 之后若 Session B `回滚` ，Session A `读取 `的内容就是 `临时且无效` 的。

![image-20220708215109480](MySQL事物篇.assets/image-20220708215109480.png)

Session A和Session B各开启了一个事务，Session B中的事务先将studentno列为1的记录的name列更新 为'张三'，然后Session A中的事务再去查询这条studentno为1的记录，如果读到列name的值为'张三'，而 Session B中的事务稍后进行了回滚，那么Session A中的事务相当于读到了一个不存在的数据，这种现象就称之为 `脏读` 。

**3. 不可重复读（ Non-Repeatable Read ）**

对于两个事务Session A、Session B，Session A `读取`了一个字段，然后 Session B `更新`了该字段。 之后 Session A `再次读取` 同一个字段， `值就不同` 了。那就意味着发生了不可重复读。

![image-20220708215626435](MySQL事物篇.assets/image-20220708215626435.png)

我们在Session B中提交了几个 `隐式事务` （注意是隐式事务，意味着语句结束事务就提交了），这些事务 都修改了studentno列为1的记录的列name的值，每次事务提交之后，如果Session A中的事务都可以查看到最新的值，这种现象也被称之为 `不可重复读 `。

**4. 幻读（ Phantom ）**

对于两个事务Session A、Session B, Session A 从一个表中 `读取` 了一个字段, 然后 Session B 在该表中 插 入 了一些新的行。 之后, 如果 Session A `再次读取` 同一个表, 就会多出几行。那就意味着发生了`幻读`。

![image-20220708220102342](MySQL事物篇.assets/image-20220708220102342.png)

Session A中的事务先根据条件 studentno > 0这个条件查询表student，得到了name列值为'张三'的记录； 之后Session B中提交了一个 `隐式事务` ，该事务向表student中插入了一条新记录；之后Session A中的事务 再根据相同的条件 studentno > 0查询表student，得到的结果集中包含Session B中的事务新插入的那条记 录，这种现象也被称之为 幻读 。我们把新插入的那些记录称之为 `幻影记录` 。

<img src="MySQL事物篇.assets/image-20220708220228436.png" alt="image-20220708220228436" style="float:left;" />

### 3.3 SQL中的四种隔离级别

上面介绍了几种并发事务执行过程中可能遇到的一些问题，这些问题有轻重缓急之分，我们给这些问题 按照严重性来排一下序：

```mysql
脏写 > 脏读 > 不可重复读 > 幻读
```

我们愿意舍弃一部分隔离性来换取一部分性能在这里就体现在：设立一些隔离级别，隔离级别越低，并发问题发生的就越多。 `SQL标准` 中设立了4个 `隔离级别` ：

* `READ UNCOMMITTED` ：读未提交，在该隔离级别，所有事务都可以看到其他未提交事务的执行结 果。不能避免脏读、不可重复读、幻读。 
* `READ COMMITTED` ：读已提交，它满足了隔离的简单定义：一个事务只能看见已经提交事务所做 的改变。这是大多数数据库系统的默认隔离级别（但不是MySQL默认的）。可以避免脏读，但不可 重复读、幻读问题仍然存在。 
* `REPEATABLE READ` ：可重复读，事务A在读到一条数据之后，此时事务B对该数据进行了修改并提 交，那么事务A再读该数据，读到的还是原来的内容。可以避免脏读、不可重复读，但幻读问题仍 然存在。这是MySQL的默认隔离级别。 
* `SERIALIZABLE` ：可串行化，确保事务可以从一个表中读取相同的行。在这个事务持续期间，禁止 其他事务对该表执行插入、更新和删除操作。所有的并发问题都可以避免，但性能十分低下。能避 免脏读、不可重复读和幻读。

`SQL标准` 中规定，针对不同的隔离级别，并发事务可以发生不同严重程度的问题，具体情况如下：

![image-20220708220917267](MySQL事物篇.assets/image-20220708220917267.png)

`脏写 `怎么没涉及到？因为脏写这个问题太严重了，不论是哪种隔离级别，都不允许脏写的情况发生。

不同的隔离级别有不同的现象，并有不同的锁和并发机制，隔离级别越高，数据库的并发性能就越差，4 种事务隔离级别与并发性能的关系如下：

<img src="MySQL事物篇.assets/image-20220708220957108.png" alt="image-20220708220957108" style="zoom:80%;" />

### 3.4 MySQL支持的四种隔离级别

<img src="MySQL事物篇.assets/image-20220708221639979.png" alt="image-20220708221639979" style="float:left;" />

MySQL的默认隔离级别为REPEATABLE READ，我们可以手动修改一下事务的隔离级别。

```mysql
# 查看隔离级别，MySQL 5.7.20的版本之前：
mysql> SHOW VARIABLES LIKE 'tx_isolation';
+---------------+-----------------+
| Variable_name | Value           |
+---------------+-----------------+
| tx_isolation  | REPEATABLE-READ |
+---------------+-----------------+
1 row in set (0.00 sec)
# MySQL 5.7.20版本之后，引入transaction_isolation来替换tx_isolation

# 查看隔离级别，MySQL 5.7.20的版本及之后：
mysql> SHOW VARIABLES LIKE 'transaction_isolation';
+-----------------------+-----------------+
| Variable_name         | Value           |
+-----------------------+-----------------+
| transaction_isolation | REPEATABLE-READ |
+-----------------------+-----------------+
1 row in set (0.02 sec)

#或者不同MySQL版本中都可以使用的：
SELECT @@transaction_isolation;
```

### 3.5 如何设置事务的隔离级别

**通过下面的语句修改事务的隔离级别：**

```mysql
SET [GLOBAL|SESSION] TRANSACTION ISOLATION LEVEL 隔离级别;
#其中，隔离级别格式：
> READ UNCOMMITTED
> READ COMMITTED
> REPEATABLE READ
> SERIALIZABLE
```

或者：

```mysql
SET [GLOBAL|SESSION] TRANSACTION_ISOLATION = '隔离级别'
#其中，隔离级别格式：
> READ-UNCOMMITTED
> READ-COMMITTED
> REPEATABLE-READ
> SERIALIZABLE
```

**关于设置时使用GLOBAL或SESSION的影响：**

* 使用 GLOBAL 关键字（在全局范围影响）：

  ```mysql
  SET GLOBAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  #或
  SET GLOBAL TRANSACTION_ISOLATION = 'SERIALIZABLE';
  ```

  则：

  + 当前已经存在的会话无效
  + 只对执行完该语句之后产生的会话起作用

* 使用 `SESSION` 关键字（在会话范围影响）：

  ```mysql
  SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  #或
  SET SESSION TRANSACTION_ISOLATION = 'SERIALIZABLE';
  ```

  则：

  + 对当前会话的所有后续的事务有效
  + 如果在事务之间执行，则对后续的事务有效
  + 该语句可以在已经开启的事务中间执行，但不会影响当前正在执行的事务

如果在服务器启动时想改变事务的默认隔离级别，可以修改启动参数`transaction_isolation`的值。比如，在启动服务器时指定了`transaction_isolation=SERIALIZABLE`，那么事务的默认隔离界别就从原来的`REPEATABLE-READ`变成了`SERIALIZABLE`。

> 小结： 
>
> 数据库规定了多种事务隔离级别，不同隔离级别对应不同的干扰程度，隔离级别越高，数据一致性就越好，但并发性越弱。

### 3.6 不同隔离级别举例

初始化数据：

```mysql
TRUNCATE TABLE account;
INSERT INTO account VALUES (1,'张三','100'), (2,'李四','0');
```

<img src="MySQL事物篇.assets/image-20220708223250773.png" alt="image-20220708223250773" style="float:left;" />

**演示1. 读未提交之脏读**

设置隔离级别为未提交读：

![image-20220710193920008](MySQL事物篇.assets/image-20220710193920008.png)

脏读就是指当前事务就在访问数据，并且对数据进行了修改，而这种修改还没有提交到数据库中，这时，另外一个事务也访问了这个数据，然后使用了这个数据。

**演示2：读已提交**

![image-20220710194440101](MySQL事物篇.assets/image-20220710194440101.png)

**演示3. 不可重复读**

设置隔离级别为可重复读，事务的执行流程如下：

![image-20220710194144826](MySQL事物篇.assets/image-20220710194144826.png)

当我们将当前会话的隔离级别设置为可重复读的时候，当前会话可以重复读，就是每次读取的结果集都相同，而不管其他事务有没有提交。但是在可重复读的隔离级别上会出现幻读的问题。

**演示4：幻读**

![image-20220710194042096](MySQL事物篇.assets/image-20220710194042096.png)

<img src="MySQL事物篇.assets/image-20220710194612317.png" alt="image-20220710194612317" style="float:left;" />

## 4. 事务的常见分类

从事务理论的角度来看，可以把事务分为以下几种类型：

* 扁平事务（Flat Transactions） 
* 带有保存点的扁平事务（Flat Transactions with Savepoints） 
* 链事务（Chained Transactions） 
* 嵌套事务（Nested Transactions） 
* 分布式事务（Distributed Transactions）

# 第14章_MySQL事务日志

事务有4种特性：原子性、一致性、隔离性和持久性。那么事务的四种特性到底是基于什么机制实现呢？

* 事务的隔离性由 `锁机制` 实现。
* 而事务的原子性、一致性和持久性由事务的 redo 日志和undo 日志来保证。
  + REDO LOG 称为 `重做日志 `，提供再写入操作，恢复提交事务修改的页操作，用来保证事务的持久性。
  + UNDO LOG 称为 `回滚日志` ，回滚行记录到某个特定版本，用来保证事务的原子性、一致性。

有的DBA或许会认为 UNDO 是 REDO 的逆过程，其实不然。REDO 和 UNDO都可以视为是一种 `恢复操作`，但是：

* redo log: 是存储引擎层 (innodb) 生成的日志，记录的是`"物理级别"`上的页修改操作，比如页号xxx，偏移量yyy写入了'zzz'数据。主要为了保证数据的可靠性。
* undo log: 是存储引擎层 (innodb) 生成的日志，记录的是 `逻辑操作` 日志，比如对某一行数据进行了INSERT语句操作，那么undo log就记录一条与之相反的DELETE操作。主要用于 `事务的回滚` (undo log 记录的是每个修改操作的 `逆操作`) 和 `一致性非锁定读` (undo log 回滚行记录到某种特定的版本——MVCC，即多版本并发控制)。

## 1. redo日志

InnoDB存储引擎是以`页为单位`来管理存储空间的。在真正访问页面之前，需要把在`磁盘上`的页缓存到内存中的`Buffer Pool`之后才可以访问。所有的变更都必须`先更新缓冲池`中的数据，然后缓冲池中的`脏页`会以一定的频率被刷入磁盘 (`checkPoint`机制)，通过缓冲池来优化CPU和磁盘之间的鸿沟，这样就可以保证整体的性能不会下降太快。

### 1.1 为什么需要REDO日志

一方面，缓冲池可以帮助我们消除CPU和磁盘之间的鸿沟，checkpoint机制可以保证数据的最终落盘，然 而由于checkpoint `并不是每次变更的时候就触发` 的，而是master线程隔一段时间去处理的。所以最坏的情 况就是事务提交后，刚写完缓冲池，数据库宕机了，那么这段数据就是丢失的，无法恢复。

另一方面，事务包含 `持久性` 的特性，就是说对于一个已经提交的事务，在事务提交后即使系统发生了崩溃，这个事务对数据库中所做的更改也不能丢失。

那么如何保证这个持久性呢？ `一个简单的做法` ：在事务提交完成之前把该事务所修改的所有页面都刷新 到磁盘，但是这个简单粗暴的做法有些问题:

* **修改量与刷新磁盘工作量严重不成比例**

  有时候我们仅仅修改了某个页面中的一个字节，但是我们知道在InnoDB中是以页为单位来进行磁盘IO的，也就是说我们在该事务提交时不得不将一个完整的页面从内存中刷新到磁盘，我们又知道一个默认页面时16KB大小，只修改一个字节就要刷新16KB的数据到磁盘上显然是小题大做了。

* **随机IO刷新较慢**

  一个事务可能包含很多语句，即使是一条语句也可能修改许多页面，假如该事务修改的这些页面可能并不相邻，这就意味着在将某个事务修改的Buffer Pool中的页面`刷新到磁盘`时，需要进行很多的`随机IO`，随机IO比顺序IO要慢，尤其对于传统的机械硬盘来说。

`另一个解决的思路` ：我们只是想让已经提交了的事务对数据库中数据所做的修改永久生效，即使后来系 统崩溃，在重启后也能把这种修改恢复出来。所以我们其实没有必要在每次事务提交时就把该事务在内 存中修改过的全部页面刷新到磁盘，只需要把 修改 了哪些东西 记录一下 就好。比如，某个事务将系统 表空间中 第10号 页面中偏移量为 100 处的那个字节的值 1 改成 2 。我们只需要记录一下：将第0号表 空间的10号页面的偏移量为100处的值更新为 2 

InnoDB引擎的事务采用了WAL技术 (`Write-Ahead Logging`)，这种技术的思想就是先写日志，再写磁盘，只有日志写入成功，才算事务提交成功，这里的日志就是redo log。当发生宕机且数据未刷到磁盘的时候，可以通过redo log来恢复，保证ACID中的D，这就是redo log的作用。

![image-20220710202517977](MySQL事物篇.assets/image-20220710202517977.png)

### 1.2 REDO日志的好处、特点

#### 1. 好处

* redo日志降低了刷盘频率 
* redo日志占用的空间非常小

存储表空间ID、页号、偏移量以及需要更新的值，所需的存储空间是很小的，刷盘快。

#### 2. 特点

* **redo日志是顺序写入磁盘的**

  在执行事务的过程中，每执行一条语句，就可能产生若干条redo日志，这些日志是按照`产生的顺序写入磁盘的`，也就是使用顺序ID，效率比随机IO快。

* **事务执行过程中，redo log不断记录**

  redo log跟bin log的区别，redo log是`存储引擎层`产生的，而bin log是`数据库层`产生的。假设一个事务，对表做10万行的记录插入，在这个过程中，一直不断的往redo log顺序记录，而bin log不会记录，直到这个事务提交，才会一次写入到bin log文件中。

### 1.3 redo的组成

Redo log可以简单分为以下两个部分：

* `重做日志的缓冲 (redo log buffer)` ，保存在内存中，是易失的。

在服务器启动时就会向操作系统申请了一大片称之为 redo log buffer 的 `连续内存` 空间，翻译成中文就是redo日志缓冲区。这片内存空间被划分为若干个连续的`redo log block`。一个redo log block占用`512字节`大小。

![image-20220710204114543](MySQL事物篇.assets/image-20220710204114543.png)

**参数设置：innodb_log_buffer_size：**

redo log buffer 大小，默认 `16M` ，最大值是4096M，最小值为1M。

```mysql
mysql> show variables like '%innodb_log_buffer_size%';
+------------------------+----------+
| Variable_name          | Value    |
+------------------------+----------+
| innodb_log_buffer_size | 16777216 |
+------------------------+----------+
```

* `重做日志文件 (redo log file) `，保存在硬盘中，是持久的。

REDO日志文件如图所示，其中`ib_logfile0`和`ib_logfile1`即为REDO日志。

![image-20220710204427616](MySQL事物篇.assets/image-20220710204427616.png)

### 1.4 redo的整体流程

以一个更新事务为例，redo log 流转过程，如下图所示：

![image-20220710204810264](MySQL事物篇.assets/image-20220710204810264-16574572910841.png)

```
第1步：先将原始数据从磁盘中读入内存中来，修改数据的内存拷贝
第2步：生成一条重做日志并写入redo log buffer，记录的是数据被修改后的值
第3步：当事务commit时，将redo log buffer中的内容刷新到 redo log file，对 redo log file采用追加写的方式
第4步：定期将内存中修改的数据刷新到磁盘中
```

> 体会： Write-Ahead Log(预先日志持久化)：在持久化一个数据页之前，先将内存中相应的日志页持久化。

### 1.5 redo log的刷盘策略

redo log的写入并不是直接写入磁盘的，InnoDB引擎会在写redo log的时候先写redo log buffer，之后以` 一 定的频率 `刷入到真正的redo log file 中。这里的一定频率怎么看待呢？这就是我们要说的刷盘策略。

![image-20220710205015302](MySQL事物篇.assets/image-20220710205015302.png)

注意，redo log buffer刷盘到redo log file的过程并不是真正的刷到磁盘中去，只是刷入到 `文件系统缓存 （page cache）`中去（这是现代操作系统为了提高文件写入效率做的一个优化），真正的写入会交给系统自己来决定（比如page cache足够大了）。那么对于InnoDB来说就存在一个问题，如果交给系统来同 步，同样如果系统宕机，那么数据也丢失了（虽然整个系统宕机的概率还是比较小的）。

针对这种情况，InnoDB给出 `innodb_flush_log_at_trx_commit` 参数，该参数控制 commit提交事务 时，如何将 redo log buffer 中的日志刷新到 redo log file 中。它支持三种策略：

* `设置为0` ：表示每次事务提交时不进行刷盘操作。（系统默认master thread每隔1s进行一次重做日 志的同步） 第1步：先将原始数据从磁盘中读入内存中来，修改数据的内存拷贝 第2步：生成一条重做日志并写入redo log buffer，记录的是数据被修改后的值 第3步：当事务commit时，将redo log buffer中的内容刷新到 redo log file，对 redo log file采用追加 写的方式 第4步：定期将内存中修改的数据刷新到磁盘中 
* `设置为1` ：表示每次事务提交时都将进行同步，刷盘操作（ 默认值 ） 
* `设置为2` ：表示每次事务提交时都只把 redo log buffer 内容写入 page cache，不进行同步。由os自 己决定什么时候同步到磁盘文件。

<img src="MySQL事物篇.assets/image-20220710205948156.png" alt="image-20220710205948156" style="float:left;" />

另外，InnoDB存储引擎有一个后台线程，每隔`1秒`，就会把`redo log buffer`中的内容写到文件系统缓存(`page cache`)，然后调用刷盘操作。

![image-20220710210339724](MySQL事物篇.assets/image-20220710210339724.png)

也就是说，一个没有提交事务的`redo log`记录，也可能会刷盘。因为在事务执行过程 redo log 记录是会写入 `redo log buffer`中，这些redo log 记录会被`后台线程`刷盘。

![image-20220710210532805](MySQL事物篇.assets/image-20220710210532805.png)

除了后台线程每秒`1次`的轮询操作，还有一种情况，当`redo log buffer`占用的空间即将达到`innodb_log_buffer_size`（这个参数默认是16M）的一半的时候，后台线程会主动刷盘。

### 1.6 不同刷盘策略演示

#### 1. 流程图

<img src="MySQL事物篇.assets/image-20220710210751414.png" alt="image-20220710210751414" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220710211318120.png" alt="image-20220710211318120" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220710211335379.png" alt="image-20220710211335379" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220710211618789.png" alt="image-20220710211618789" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220710211831675.png" alt="image-20220710211831675" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220710212041563.png" alt="image-20220710212041563" style="float:left;" />

#### 2. 举例

比较innodb_flush_log_at_trx_commit对事务的影响。

```mysql
CREATE TABLE test_load(
a INT,
b CHAR(80)
)ENGINE=INNODB;
```

```mysql
DELIMITER//
CREATE PROCEDURE p_load(COUNT INT UNSIGNED)
BEGIN
DECLARE s INT UNSIGNED DEFAULT 1;
DECLARE c CHAR(80) DEFAULT REPEAT('a',80);
WHILE s<=COUNT DO
INSERT INTO test_load SELECT NULL, c;
COMMIT;
SET s=s+1;
END WHILE;
END //
DELIMITER;
```

<img src="MySQL事物篇.assets/image-20220710215001482.png" alt="image-20220710215001482" style="float:left;" />

```mysql
mysql> CALL p_load(30000);
Query OK, 0 rows affected(1 min 23 sec)
```

`1 min 23 sec`的时间显然是不能接受的。而造成时间比较长的原因就在于fsync操作所需要的时间。

修改参数innodb_flush_log_at_trx_commit，设置为0：

```mysql
mysql> set global innodb_flush_log_at_trx_commit = 0;
```

```mysql
mysql> CALL p_load(30000);
Query OK, 0 rows affected(38 sec)
```

修改参数innodb_flush_log_at_trx_commit，设置为2：

```mysql
mysql> set global innodb_flush_log_at_trx_commit = 2;
```

```mysql
mysql> CALL p_load(30000);
Query OK, 0 rows affected(46 sec)
```

<img src="MySQL事物篇.assets/image-20220710215353893.png" alt="image-20220710215353893" style="float:left;" />

### 1.7 写入redo log buffer 过程

#### 1. 补充概念：Mini-Transaction

MySQL把对底层页面中的一次原子访问过程称之为一个`Mini-Transaction`，简称`mtr`，比如，向某个索引对应的B+树中插入一条记录的过程就是一个`Mini-Transaction`。一个所谓的`mtr`可以包含一组redo日志，在进行崩溃恢复时这一组`redo`日志可以作为一个不可分割的整体。

一个事务可以包含若干条语句，每一条语句其实是由若干个 `mtr` 组成，每一个 `mtr` 又可以包含若干条 redo日志，画个图表示它们的关系就是这样：

![image-20220710220653131](MySQL事物篇.assets/image-20220710220653131.png)

#### 2. redo 日志写入log buffer

<img src="MySQL事物篇.assets/image-20220710220838744.png" alt="image-20220710220838744" style="float:left;" />

![image-20220710220919271](MySQL事物篇.assets/image-20220710220919271.png)

<img src="MySQL事物篇.assets/image-20220710221221981.png" alt="image-20220710221221981" style="float:left;" />

![image-20220710221318271](MySQL事物篇.assets/image-20220710221318271.png)

不同的事务可能是 `并发` 执行的，所以 T1 、 T2 之间的 mtr 可能是 `交替执行` 的。没当一个mtr执行完成时，伴随该mtr生成的一组redo日志就需要被复制到log buffer中，也就是说不同事务的mtr可能是交替写入log buffer的，我们画个示意图（为了美观，我们把一个mtr中产生的所有redo日志当做一个整体来画）：

![image-20220710221620291](MySQL事物篇.assets/image-20220710221620291.png)

有的mtr产生的redo日志量非常大，比如`mtr_t1_2`产生的redo日志占用空间比较大，占用了3个block来存储。

#### 3. redo log block的结构图

一个redo log block是由`日志头、日志体、日志尾`组成。日志头占用12字节，日志尾占用8字节，所以一个block真正能存储的数据是512-12-8=492字节。

<img src="MySQL事物篇.assets/image-20220710223117420.png" alt="image-20220710223117420" style="float:left;" />

![image-20220710223135374](MySQL事物篇.assets/image-20220710223135374.png)

真正的redo日志都是存储到占用`496`字节大小的`log block body`中，图中的`log block header`和`log block trailer`存储的是一些管理信息。我们来看看这些所谓`管理信息`都有什么。

![image-20220711144546439](MySQL事物篇.assets/image-20220711144546439.png)

<img src="MySQL事物篇.assets/image-20220711144608223.png" alt="image-20220711144608223" style="float:left;" />

### 1.8 redo log file

#### 1. 相关参数设置

* `innodb_log_group_home_dir` ：指定 redo log 文件组所在的路径，默认值为 `./` ，表示在数据库 的数据目录下。MySQL的默认数据目录（ `var/lib/mysql`）下默认有两个名为 `ib_logfile0` 和 `ib_logfile1` 的文件，log buffer中的日志默认情况下就是刷新到这两个磁盘文件中。此redo日志 文件位置还可以修改。

* `innodb_log_files_in_group`：指明redo log file的个数，命名方式如：ib_logfile0，iblogfile1... iblogfilen。默认2个，最大100个。

  ```mysql
  mysql> show variables like 'innodb_log_files_in_group';
  +---------------------------+-------+
  | Variable_name             | Value |
  +---------------------------+-------+
  | innodb_log_files_in_group | 2     |
  +---------------------------+-------+
  #ib_logfile0
  #ib_logfile1
  ```

* `innodb_flush_log_at_trx_commit`：控制 redo log 刷新到磁盘的策略，默认为1。

* `innodb_log_file_size`：单个 redo log 文件设置大小，默认值为 `48M` 。最大值为512G，注意最大值 指的是整个 redo log 系列文件之和，即（innodb_log_files_in_group * innodb_log_file_size ）不能大 于最大值512G。

  ```mysql
  mysql> show variables like 'innodb_log_file_size';
  +----------------------+----------+
  | Variable_name        | Value    |
  +----------------------+----------+
  | innodb_log_file_size | 50331648 |
  +----------------------+----------+
  ```

根据业务修改其大小，以便容纳较大的事务。编辑my.cnf文件并重启数据库生效，如下所示

```mysql
[root@localhost ~]# vim /etc/my.cnf
innodb_log_file_size=200M
```

> 在数据库实例更新比较频繁的情况下，可以适当加大 redo log 数组和大小。但也不推荐 redo log 设置过大，在MySQL崩溃时会重新执行REDO日志中的记录。

#### 2. 日志文件组

<img src="MySQL事物篇.assets/image-20220711152137012.png" alt="image-20220711152137012" style="float:left;" />

![image-20220711152242300](MySQL事物篇.assets/image-20220711152242300.png)

总共的redo日志文件大小其实就是： `innodb_log_file_size × innodb_log_files_in_group` 。

采用循环使用的方式向redo日志文件组里写数据的话，会导致后写入的redo日志覆盖掉前边写的redo日志？当然！所以InnoDB的设计者提出了checkpoint的概念。

#### 3. checkpoint

在整个日志文件组中还有两个重要的属性，分别是 write pos、checkpoint

* `write pos`是当前记录的位置，一边写一边后移
* `checkpoint`是当前要擦除的位置，也是往后推移

每次刷盘 redo log 记录到日志文件组中，write pos 位置就会后移更新。每次MySQL加载日志文件组恢复数据时，会清空加载过的 redo log 记录，并把check point后移更新。write pos 和 checkpoint 之间的还空着的部分可以用来写入新的 redo log 记录。

<img src="MySQL事物篇.assets/image-20220711152631108.png" alt="image-20220711152631108" style="zoom:80%;" />

如果 write pos 追上 checkpoint ，表示`日志文件组`满了，这时候不能再写入新的 redo log记录，MySQL 得 停下来，清空一些记录，把 checkpoint 推进一下。

<img src="MySQL事物篇.assets/image-20220711152802294.png" alt="image-20220711152802294" style="zoom:80%;" />

### 1.9 redo log 小结

<img src="MySQL事物篇.assets/image-20220711152930911.png" alt="image-20220711152930911" style="float:left;" />

## 2. Undo日志

redo log是事务持久性的保证，undo log是事务原子性的保证。在事务中 `更新数据` 的 `前置操作` 其实是要先写入一个 `undo log` 。

### 2.1 如何理解Undo日志

事务需要保证 `原子性 `，也就是事务中的操作要么全部完成，要么什么也不做。但有时候事务执行到一半会出现一些情况，比如：

* 情况一：事务执行过程中可能遇到各种错误，比如` 服务器本身的错误` ， `操作系统错误` ，甚至是突然 `断电` 导致的错误。
* 情况二：程序员可以在事务执行过程中手动输入 `ROLLBACK` 语句结束当前事务的执行。

以上情况出现，我们需要把数据改回原先的样子，这个过程称之为 `回滚` ，这样就可以造成一个假象：这 个事务看起来什么都没做，所以符合 `原子性` 要求。

<img src="MySQL事物篇.assets/image-20220711153523704.png" alt="image-20220711153523704" style="float:left;" />

### 2.2 Undo日志的作用

* **作用1：回滚数据**

<img src="MySQL事物篇.assets/image-20220711153645204.png" alt="image-20220711153645204" style="float:left;" />

* **作用2：MVCC**

undo的另一个作用是MVCC，即在InnoDB存储引擎中MVCC的实现是通过undo来完成。当用户读取一行记录时，若该记录以及被其他事务占用，当前事务可以通过undo读取之前的行版本信息，以此实现非锁定读取。

### 2.3 undo的存储结构

#### 1. 回滚段与undo页

InnoDB对undo log的管理采用段的方式，也就是 `回滚段（rollback segment）` 。每个回滚段记录了 `1024` 个 `undo log segment` ，而在每个undo log segment段中进行 `undo页` 的申请。

* 在` InnoDB1.1版本之前` （不包括1.1版本），只有一个rollback segment，因此支持同时在线的事务限制为 `1024` 。虽然对绝大多数的应用来说都已经够用。 
* 从1.1版本开始InnoDB支持最大 `128个rollback segment` ，故其支持同时在线的事务限制提高到 了 `128*1024` 。

```mysql
mysql> show variables like 'innodb_undo_logs';
+------------------+-------+
| Variable_name    | Value |
+------------------+-------+
| innodb_undo_logs | 128   |
+------------------+-------+
```

<img src="MySQL事物篇.assets/image-20220711154936382.png" alt="image-20220711154936382" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220711155044078.png" alt="image-20220711155044078" style="float:left;" />

#### 2. 回滚段与事务

1. 每个事务只会使用一个回滚段，一个回滚段在同一时刻可能会服务于多个事务。

2. 当一个事务开始的时候，会制定一个回滚段，在事务进行的过程中，当数据被修改时，原始的数 据会被复制到回滚段。

3. 在回滚段中，事务会不断填充盘区，直到事务结束或所有的空间被用完。如果当前的盘区不够 用，事务会在段中请求扩展下一个盘区，如果所有已分配的盘区都被用完，事务会覆盖最初的盘 区或者在回滚段允许的情况下扩展新的盘区来使用。

4. 回滚段存在于undo表空间中，在数据库中可以存在多个undo表空间，但同一时刻只能使用一个 undo表空间。

   ```mysql
   mysql> show variables like 'innodb_undo_tablespaces';
   +-------------------------+-------+
   | Variable_name           | Value |
   +-------------------------+-------+
   | innodb_undo_tablespaces | 2     |
   +-------------------------+-------+
   # undo log的数量，最少为2. undo log的truncate操作有purge协调线程发起。在truncate某个undo log表空间的过程中，保证有一个可用的undo log可用。
   ```

5. 当事务提交时，InnoDB存储引擎会做以下两件事情：

   + 将undo log放入列表中，以供之后的purge操作 
   + 判断undo log所在的页是否可以重用，若可以分配给下个事务使用

#### 3. 回滚段中的数据分类

1. `未提交的回滚数据(uncommitted undo information)`：该数据所关联的事务并未提交，用于实现读一致性，所以该数据不能被其他事务的数据覆盖。
2. `已经提交但未过期的回滚数据(committed undo information)`：该数据关联的事务已经提交，但是仍受到undo retention参数的保持时间的影响。
3. `事务已经提交并过期的数据(expired undo information)`：事务已经提交，而且数据保存时间已经超过 undo retention参数指定的时间，属于已经过期的数据。当回滚段满了之后，就优先覆盖“事务已经提交并过期的数据"。

事务提交后不能马上删除undo log及undo log所在的页。这是因为可能还有其他事务需要通过undo log来得到行记录之前的版本。故事务提交时将undo log放入一个链表中，是否可以最终删除undo log以undo log所在页由purge线程来判断。

### 2.4 undo的类型

在InnoDB存储引擎中，undo log分为：

* insert undo log

  insert undo log是指insert操作中产生的undo log。因为insert操作的记录，只对事务本身可见，对其他事务不可见（这是事务隔离性的要求），故该undo log可以在事务提交后直接删除。不需要进行purge操作。

* update undo log

  update undo log记录的是对delete和update操作产生的undo log。该undo log可能需要提供MVCC机制，因此不能在事务提交时就进行删除。提交时放入undo log链表，等待purge线程进行最后的删除。

### 2.5 undo log的生命周期

#### 1. 简要生成过程

以下是undo+redo事务的简化过程

假设有两个数值，分别为A=1和B=2，然后将A修改为3，B修改为4

<img src="MySQL事物篇.assets/image-20220711162414928.png" alt="image-20220711162414928" style="float:left;" />

**只有Buffer Pool的流程：**

![image-20220711162505008](MySQL事物篇.assets/image-20220711162505008.png)

**有了Redo Log和Undo Log之后：**

![image-20220711162642305](MySQL事物篇.assets/image-20220711162642305.png)

在更新Buffer Pool中的数据之前，我们需要先将该数据事务开始之前的状态写入Undo Log中。假设更新到一半出错了，我们就可以通过Undo Log来回滚到事务开始前。

#### 2. 详细生成过程

<img src="MySQL事物篇.assets/image-20220711162919157.png" alt="image-20220711162919157" style="float:left;" />

**当我们执行INSERT时：**

```mysql
begin;
INSERT INTO user (name) VALUES ("tom");
```

插入的数据都会生成一条insert undo log，并且数据的回滚指针会指向它。undo log会记录undo log的序号、插入主键的列和值...，那么在进行rollback的时候，通过主键直接把对应的数据删除即可。

![image-20220711163725129](MySQL事物篇.assets/image-20220711163725129.png)

**当我们执行UPDATE时：**

对应更新的操作会产生update undo log，并且会分更新主键和不更新主键的，假设现在执行：

```mysql
UPDATE user SET name="Sun" WHERE id=1;
```

![image-20220711164138414](MySQL事物篇.assets/image-20220711164138414.png)

这时会把老的记录写入新的undo log，让回滚指针指向新的undo log，它的undo no是1，并且新的undo log会指向老的undo log（undo no=0）。

假设现在执行：

```mysql
UPDATE user SET id=2 WHERE id=1;
```

![image-20220711164421494](MySQL事物篇.assets/image-20220711164421494.png)

对于更新主键的操作，会先把原来的数据deletemark标识打开，这时并没有真正的删除数据，真正的删除会交给清理线程去判断，然后在后面插入一条新的数据，新的数据也会产生undo log，并且undo log的序号会递增。

可以发现每次对数据的变更都会产生一个undo log，当一条记录被变更多次时，那么就会产生多条undo log，undo log记录的是变更前的日志，并且每个undo log的序号是递增的，那么当要回滚的时候，按照序号`依次向前推`，就可以找到我们的原始数据了。

#### 3. undo log是如何回滚的

以上面的例子来说，假设执行rollback，那么对应的流程应该是这样：

1. 通过undo no=3的日志把id=2的数据删除 
2. 通过undo no=2的日志把id=1的数据的deletemark还原成0 
3. 通过undo no=1的日志把id=1的数据的name还原成Tom 
4. 通过undo no=0的日志把id=1的数据删除

#### 4. undo log的删除

* 针对于insert undo log

  因为insert操作的记录，只对事务本身可见，对其他事务不可见。故该undo log可以在事务提交后直接删除，不需要进行purge操作。

* 针对于update undo log

  该undo log可能需要提供MVCC机制，因此不能在事务提交时就进行删除。提交时放入undo log链表，等待purge线程进行最后的删除。

> 补充：
>
> purge线程两个主要作用是：`清理undo页`和`清理page里面带有Delete_Bit标识的数据行`。在InnoDB中，事务中的Delete操作实际上并不是真正的删除掉数据行，而是一种Delete Mark操作，在记录上标识Delete_Bit，而不删除记录。是一种“假删除”，只是做了个标记，真正的删除工作需要后台purge线程去完成。

### 2.6 小结

![image-20220711165612956](MySQL事物篇.assets/image-20220711165612956.png)

undo log是逻辑日志，对事务回滚时，只是将数据库逻辑地恢复到原来的样子。

redo log是物理日志，记录的是数据页的物理变化，undo log不是redo log的逆过程。

# 第15章_锁

## 1. 概述

<img src="MySQL事物篇.assets/image-20220711165954976.png" alt="image-20220711165954976" style="float:left;" />

在数据库中，除传统的计算资源（如CPU、RAM、I/O等）的争用以外，数据也是一种供许多用户共享的 资源。为保证数据的一致性，需要对 `并发操作进行控制` ，因此产生了 `锁` 。同时 `锁机制` 也为实现MySQL 的各个隔离级别提供了保证。 `锁冲突` 也是影响数据库 `并发访问性能` 的一个重要因素。所以锁对数据库而言显得尤其重要，也更加复杂。

## 2. MySQL并发事务访问相同记录

并发事务访问相同记录的情况大致可以划分为3种：

### 2.1 读-读情况

`读-读`情况，即并发事务相继`读取相同的记录`。读取操作本身不会对记录有任何影响，并不会引起什么问题，所以允许这种情况的发生。

### 2.2 写-写情况

`写-写` 情况，即并发事务相继对相同的记录做出改动。

在这种情况下会发生 `脏写` 的问题，任何一种隔离级别都不允许这种问题的发生。所以在多个未提交事务相继对一条记录做改动时，需要让它们 `排队执行` ，这个排队的过程其实是通过 `锁` 来实现的。这个所谓的锁其实是一个内存中的结构 ，在事务执行前本来是没有锁的，也就是说一开始是没有 锁结构 和记录进 行关联的，如图所示：

![image-20220711181120639](MySQL事物篇.assets/image-20220711181120639.png)

当一个事务想对这条记录做改动时，首先会看看内存中有没有与这条记录关联的 `锁结构` ，当没有的时候 就会在内存中生成一个 `锁结构` 与之关联。比如，事务` T1` 要对这条记录做改动，就需要生成一个 `锁结构` 与之关联：

![image-20220711192633239](MySQL事物篇.assets/image-20220711192633239.png)

在`锁结构`里有很多信息，为了简化理解，只把两个比较重要的属性拿了出来：

* `trx信息`：代表这个锁结构是哪个事务生成的。
* `is_waiting`：代表当前事务是否在等待。

在事务`T1`改动了这条记录后，就生成了一个`锁结构`与该记录关联，因为之前没有别的事务为这条记录加锁，所以`is_waiting`属性就是`false`，我们把这个场景就称值为`获取锁成功`，或者`加锁成功`，然后就可以继续执行操作了。

在事务`T1`提交之前，另一个事务`T2`也想对该记录做改动，那么先看看有没有`锁结构`与这条记录关联，发现有一个`锁结构`与之关联后，然后也生成了一个锁结构与这条记录关联，不过锁结构的`is_waiting`属性值为`true`，表示当前事务需要等待，我们把这个场景就称之为`获取锁失败`，或者`加锁失败`，图示：

![image-20220711193732567](MySQL事物篇.assets/image-20220711193732567.png)

在事务T1提交之后，就会把该事务生成的`锁结构释放`掉，然后看看还有没有别的事务在等待获取锁，发现了事务T2还在等待获取锁，所以把事务T2对应的锁结构的`is_waiting`属性设置为`false`，然后把该事务对应的线程唤醒，让它继续执行，此时事务T2就算获取到锁了。效果就是这样。

![image-20220711194904328](MySQL事物篇.assets/image-20220711194904328.png)

小结几种说法：

* 不加锁

  意思就是不需要在内存中生成对应的 `锁结构` ，可以直接执行操作。

* 获取锁成功，或者加锁成功

  意思就是在内存中生成了对应的 `锁结构` ，而且锁结构的 `is_waiting` 属性为 `false` ，也就是事务 可以继续执行操作。

* 获取锁失败，或者加锁失败，或者没有获取到锁

  意思就是在内存中生成了对应的 `锁结构` ，不过锁结构的 `is_waiting` 属性为 `true` ，也就是事务 需要等待，不可以继续执行操作。

### 2.3 读-写或写-读情况

`读-写` 或 `写-读 `，即一个事务进行读取操作，另一个进行改动操作。这种情况下可能发生 `脏读 、 不可重 复读 、 幻读` 的问题。

各个数据库厂商对 `SQL标准` 的支持都可能不一样。比如MySQL在 `REPEATABLE READ` 隔离级别上就已经解决了 `幻读` 问题。

### 2.4 并发问题的解决方案

怎么解决 `脏读 、 不可重复读 、 幻读` 这些问题呢？其实有两种可选的解决方案：

* 方案一：读操作利用多版本并发控制（ `MVCC` ，下章讲解），写操作进行 `加锁` 。

<img src="MySQL事物篇.assets/image-20220711202206405.png" alt="image-20220711202206405" style="float:left;" />

> 普通的SELECT语句在READ COMMITTED和REPEATABLE READ隔离级别下会使用到MVCC读取记录。
>
> * 在 `READ COMMITTED` 隔离级别下，一个事务在执行过程中每次执行SELECT操作时都会生成一 个ReadView，ReadView的存在本身就保证了`事务不可以读取到未提交的事务所做的更改` ，也就是避免了脏读现象；
> * 在 `REPEATABLE READ` 隔离级别下，一个事务在执行过程中只有 `第一次执行SELECT操作` 才会生成一个ReadView，之后的SELECT操作都 `复用` 这个ReadView，这样也就避免了不可重复读和幻读的问题。

* 方案二：读、写操作都采用 `加锁` 的方式。

<img src="MySQL事物篇.assets/image-20220711203250284.png" alt="image-20220711203250284" style="float:left;" />

* 小结对比发现：

  * 采用 `MVCC` 方式的话， 读-写 操作彼此并不冲突， 性能更高 。
  * 采用 `加锁` 方式的话， 读-写 操作彼此需要 `排队执行` ，影响性能。

  一般情况下我们当然愿意采用 `MVCC` 来解决 `读-写` 操作并发执行的问题，但是业务在某些特殊情况下，要求必须采用 `加锁 `的方式执行。下面就讲解下MySQL中不同类别的锁。

## 3. 锁的不同角度分类

锁的分类图，如下：

![image-20220711203519162](MySQL事物篇.assets/image-20220711203519162.png)

### 3.1 从数据操作的类型划分：读锁、写锁

<img src="MySQL事物篇.assets/image-20220711203723941.png" alt="image-20220711203723941" style="float:left;" />

* `读锁` ：也称为 `共享锁` 、英文用 S 表示。针对同一份数据，多个事务的读操作可以同时进行而不会互相影响，相互不阻塞的。
* `写锁` ：也称为 `排他锁` 、英文用 X 表示。当前写操作没有完成前，它会阻断其他写锁和读锁。这样 就能确保在给定的时间里，只有一个事务能执行写入，并防止其他用户读取正在写入的同一资源。

**需要注意的是对于 InnoDB 引擎来说，读锁和写锁可以加在表上，也可以加在行上。**

<img src="MySQL事物篇.assets/image-20220711204843684.png" alt="image-20220711204843684" style="float:left;" />

#### 1. 锁定读

<img src="MySQL事物篇.assets/image-20220711212931912.png" alt="image-20220711212931912" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220711213741630.png" alt="image-20220711213741630" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220711214013208.png" alt="image-20220711214013208" style="float:left;" />

#### 2. 写操作

<img src="MySQL事物篇.assets/image-20220711214412163.png" alt="image-20220711214412163" style="float:left;" />

### 3.2 从数据操作的粒度划分：表级锁、页级锁、行锁

<img src="MySQL事物篇.assets/image-20220711214719510.png" alt="image-20220711214719510" style="float:left;" />

#### 1. 表锁（Table Lock）

<img src="MySQL事物篇.assets/image-20220711214805088.png" alt="image-20220711214805088" style="float:left;" />

##### ① 表级别的S锁、X锁

在对某个表执行SELECT、INSERT、DELETE、UPDATE语句时，InnoDB存储引擎是不会为这个表添加表级别的 `S锁` 或者 `X锁` 的。在对某个表执行一些诸如 `ALTER TABLE 、 DROP TABLE` 这类的 DDL 语句时，其 他事务对这个表并发执行诸如SELECT、INSERT、DELETE、UPDATE的语句会发生阻塞。同理，某个事务中对某个表执行SELECT、INSERT、DELETE、UPDATE语句时，在其他会话中对这个表执行 `DDL` 语句也会 发生阻塞。这个过程其实是通过在 server层使用一种称之为 `元数据锁` （英文名： Metadata Locks ， 简称 MDL ）结构来实现的。

一般情况下，不会使用InnoDB存储引擎提供的表级别的 `S锁` 和 `X锁` 。只会在一些特殊情况下，比方说 `崩溃恢复` 过程中用到。比如，在系统变量 `autocommit=0，innodb_table_locks = 1` 时， 手动 获取 InnoDB存储引擎提供的表t 的 `S锁` 或者 `X锁` 可以这么写：

* `LOCK TABLES t READ` ：InnoDB存储引擎会对表 t 加表级别的 `S锁 `。

* `LOCK TABLES t WRITE` ：InnoDB存储引擎会对表 t 加表级别的 `X锁` 。

不过尽量避免在使用InnoDB存储引擎的表上使用 `LOCK TABLES` 这样的手动锁表语句，它们并不会提供 什么额外的保护，只是会降低并发能力而已。InnoDB的厉害之处还是实现了更细粒度的 `行锁` ，关于 InnoDB表级别的 `S锁` 和` X锁` 大家了解一下就可以了。

**举例：**下面我们讲解MyISAM引擎下的表锁。

步骤1：创建表并添加数据

```mysql
CREATE TABLE mylock(
id INT NOT NULL PRIMARY KEY auto_increment,
NAME VARCHAR(20)
)ENGINE myisam;

# 插入一条数据
INSERT INTO mylock(NAME) VALUES('a');

# 查询表中所有数据
SELECT * FROM mylock;
+----+------+
| id | Name |
+----+------+
| 1  | a    |
+----+------+
```

步骤二：查看表上加过的锁

```mysql
SHOW OPEN TABLES; # 主要关注In_use字段的值
或者
SHOW OPEN TABLES where In_use > 0;
```

<img src="MySQL事物篇.assets/image-20220711220342251.png" alt="image-20220711220342251" style="float:left;" />

或者

<img src="MySQL事物篇.assets/image-20220711220418859.png" alt="image-20220711220418859" style="float:left;" />

上面的结果表明，当前数据库中没有被锁定的表

步骤3：手动增加表锁命令

```mysql
LOCK TABLES t READ; # 存储引擎会对表t加表级别的共享锁。共享锁也叫读锁或S锁（Share的缩写）
LOCK TABLES t WRITE; # 存储引擎会对表t加表级别的排他锁。排他锁也叫独占锁、写锁或X锁（exclusive的缩写）
```

比如：

<img src="MySQL事物篇.assets/image-20220711220442269.png" alt="image-20220711220442269" style="float:left;" />

步骤4：释放表锁

```mysql
UNLOCK TABLES; # 使用此命令解锁当前加锁的表
```

比如：

<img src="MySQL事物篇.assets/image-20220711220502141.png" alt="image-20220711220502141" style="float:left;" />

步骤5：加读锁

我们为mylock表加read锁（读阻塞写），观察阻塞的情况，流程如下：

![image-20220711220553225](MySQL事物篇.assets/image-20220711220553225.png)

![image-20220711220616537](MySQL事物篇.assets/image-20220711220616537.png)

步骤6：加写锁

为mylock表加write锁，观察阻塞的情况，流程如下：

![image-20220711220711630](MySQL事物篇.assets/image-20220711220711630.png)

![image-20220711220730112](MySQL事物篇.assets/image-20220711220730112.png)

总结：

MyISAM在执行查询语句（SELECT）前，会给涉及的所有表加读锁，在执行增删改操作前，会给涉及的表加写锁。InnoDB存储引擎是不会为这个表添加表级别的读锁和写锁的。

MySQL的表级锁有两种模式：（以MyISAM表进行操作的演示）

* 表共享读锁（Table Read Lock）

* 表独占写锁（Table Write Lock）

  ![image-20220711220929248](MySQL事物篇.assets/image-20220711220929248.png)

##### ② 意向锁 （intention lock）

InnoDB 支持 `多粒度锁（multiple granularity locking）` ，它允许 `行级锁` 与 `表级锁` 共存，而`意向锁`就是其中的一种 `表锁` 。

1. 意向锁的存在是为了协调行锁和表锁的关系，支持多粒度（表锁和行锁）的锁并存。
2. 意向锁是一种`不与行级锁冲突表级锁`，这一点非常重要。
3. 表明“某个事务正在某些行持有了锁或该事务准备去持有锁”

意向锁分为两种：

* **意向共享锁**（intention shared lock, IS）：事务有意向对表中的某些行加**共享锁**（S锁）

  ```mysql
  -- 事务要获取某些行的 S 锁，必须先获得表的 IS 锁。
  SELECT column FROM table ... LOCK IN SHARE MODE;
  ```

* **意向排他锁**（intention exclusive lock, IX）：事务有意向对表中的某些行加**排他锁**（X锁）

  ```mysql
  -- 事务要获取某些行的 X 锁，必须先获得表的 IX 锁。
  SELECT column FROM table ... FOR UPDATE;
  ```

即：意向锁是由存储引擎 `自己维护的` ，用户无法手动操作意向锁，在为数据行加共享 / 排他锁之前， InooDB 会先获取该数据行 `所在数据表的对应意向锁` 。

**1. 意向锁要解决的问题**

<img src="MySQL事物篇.assets/image-20220711222132300.png" alt="image-20220711222132300" style="float:left;" />

**举例：**创建表teacher,插入6条数据，事务的隔离级别默认为`Repeatable-Read`，如下所示。

```mysql
CREATE TABLE `teacher` (
	`id` int NOT NULL,
    `name` varchar(255) NOT NULL,
    PRIMARY KEY (`id`)
)ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `teacher` VALUES
('1', 'zhangsan'),
('2', 'lisi'),
('3', 'wangwu'),
('4', 'zhaoliu'),
('5', 'songhongkang'),
('6', 'leifengyang');
```

```mysql
mysql> SELECT @@transaction_isolation;
+-------------------------+
| @@transaction_isolation |
+-------------------------+
| REPEATABLE-READ         |
+-------------------------+
```

假设事务A获取了某一行的排他锁，并未提交，语句如下所示:

```mysql
BEGIN;

SELECT * FROM teacher WHERE id = 6 FOR UPDATE;
```

事务B想要获取teacher表的表读锁，语句如下：

```mysql
BEGIN;

LOCK TABLES teacher READ;
```

<img src="MySQL事物篇.assets/image-20220712124209006.png" alt="image-20220712124209006" style="float:left;" />

```mysql
BEGIN;

SELECT * FROM teacher WHERE id = 6 FOR UPDATE;
```

此时teacher表存在两把锁：teacher表上的意向排他锁与id未6的数据行上的排他锁。事务B想要获取teacher表的共享锁。

```mysql
BEGIN;

LOCK TABLES teacher READ;
```

此时事务B检测事务A持有teacher表的意向排他锁，就可以得知事务A必须持有该表中某些数据行的排他锁，那么事务B对teacher表的加锁请求就会被排斥（阻塞），而无需去检测表中的每一行数据是否存在排他锁。

**意向锁的并发性**

意向锁不会与行级的共享 / 排他锁互斥！正因为如此，意向锁并不会影响到多个事务对不同数据行加排他锁时的并发性。（不然我们直接用普通的表锁就行了）

我们扩展一下上面 teacher表的例子来概括一下意向锁的作用（一条数据从被锁定到被释放的过程中，可 能存在多种不同锁，但是这里我们只着重表现意向锁）。

事务A先获得了某一行的排他锁，并未提交：

```mysql
BEGIN;

SELECT * FROM teacher WHERE id = 6 FOR UPDATE;
```

事务A获取了teacher表上的意向排他锁。事务A获取了id为6的数据行上的排他锁。之后事务B想要获取teacher表上的共享锁。

```mysql
BEGIN;

LOCK TABLES teacher READ;
```

事务B检测到事务A持有teacher表的意向排他锁。事务B对teacher表的加锁请求被阻塞（排斥）。最后事务C也想获取teacher表中某一行的排他锁。

````mysql
BEGIN;

SELECT * FROM teacher WHERE id = 5 FOR UPDATE;
````

事务C申请teacher表的意向排他锁。事务C检测到事务A持有teacher表的意向排他锁。因为意向锁之间并不互斥，所以事务C获取到了teacher表的意向排他锁。因为id为5的数据行上不存在任何排他锁，最终事务C成功获取到了该数据行上的排他锁。

**从上面的案例可以得到如下结论：**

1. InnoDB 支持 `多粒度锁` ，特定场景下，行级锁可以与表级锁共存。 
2. 意向锁之间互不排斥，但除了 IS 与 S 兼容外， `意向锁会与 共享锁 / 排他锁 互斥` 。 
3. IX，IS是表级锁，不会和行级的X，S锁发生冲突。只会和表级的X，S发生冲突。 
4. 意向锁在保证并发性的前提下，实现了 `行锁和表锁共存` 且 `满足事务隔离性` 的要求。

##### ③ 自增锁（AUTO-INC锁）

在使用MySQL过程中，我们可以为表的某个列添加 `AUTO_INCREMENT` 属性。举例：

```mysql
CREATE TABLE `teacher` (
`id` int NOT NULL AUTO_INCREMENT,
`name` varchar(255) NOT NULL,
PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

由于这个表的id字段声明了AUTO_INCREMENT，意味着在书写插入语句时不需要为其赋值，SQL语句修改 如下所示。

```mysql
INSERT INTO `teacher` (name) VALUES ('zhangsan'), ('lisi');
```

上边的插入语句并没有为id列显式赋值，所以系统会自动为它赋上递增的值，结果如下所示。

```mysql
mysql> select * from teacher;
+----+----------+
| id | name     |
+----+----------+
| 1  | zhangsan |
| 2  | lisi     |
+----+----------+
2 rows in set (0.00 sec)
```

现在我们看到的上面插入数据只是一种简单的插入模式，所有插入数据的方式总共分为三类，分别是 “ `Simple inserts` ”，“ `Bulk inserts` ”和“ `Mixed-mode inserts `”。

**1. “Simple inserts” （简单插入）**

可以 `预先确定要插入的行数` （当语句被初始处理时）的语句。包括没有嵌套子查询的单行和多行` INSERT...VALUES() `和 `REPLACE` 语句。比如我们上面举的例子就属于该类插入，已经确定要插入的行 数。

**2. “Bulk inserts” （批量插入）**

`事先不知道要插入的行数` （和所需自动递增值的数量）的语句。比如 `INSERT ... SELECT` ， `REPLACE ... SELECT` 和 `LOAD DATA` 语句，但不包括纯INSERT。 InnoDB在每处理一行，为AUTO_INCREMENT列

**3. “Mixed-mode inserts” （混合模式插入）**

这些是“Simple inserts”语句但是指定部分新行的自动递增值。例如 `INSERT INTO teacher (id,name) VALUES (1,'a'), (NULL,'b'), (5,'c'), (NULL,'d');` 只是指定了部分id的值。另一种类型的“混合模式插入”是 `INSERT ... ON DUPLICATE KEY UPDATE` 。

<img src="MySQL事物篇.assets/image-20220712175552985.png" alt="image-20220712175552985" style="float:left;" />

innodb_autoinc_lock_mode有三种取值，分别对应与不同锁定模式：

`（1）innodb_autoinc_lock_mode = 0(“传统”锁定模式)`

在此锁定模式下，所有类型的insert语句都会获得一个特殊的表级AUTO-INC锁，用于插入具有 AUTO_INCREMENT列的表。这种模式其实就如我们上面的例子，即每当执行insert的时候，都会得到一个 表级锁(AUTO-INC锁)，使得语句中生成的auto_increment为顺序，且在binlog中重放的时候，可以保证 master与slave中数据的auto_increment是相同的。因为是表级锁，当在同一时间多个事务中执行insert的 时候，对于AUTO-INC锁的争夺会 `限制并发` 能力。

`（2）innodb_autoinc_lock_mode = 1(“连续”锁定模式)`

在 MySQL 8.0 之前，连续锁定模式是 `默认` 的。

在这个模式下，“bulk inserts”仍然使用AUTO-INC表级锁，并保持到语句结束。这适用于所有INSERT ... SELECT，REPLACE ... SELECT和LOAD DATA语句。同一时刻只有一个语句可以持有AUTO-INC锁。

对于“Simple inserts”（要插入的行数事先已知），则通过在 `mutex（轻量锁）` 的控制下获得所需数量的自动递增值来避免表级AUTO-INC锁， 它只在分配过程的持续时间内保持，而不是直到语句完成。不使用表级AUTO-INC锁，除非AUTO-INC锁由另一个事务保持。如果另一个事务保持AUTO-INC锁，则“Simple inserts”等待AUTO-INC锁，如同它是一个“bulk inserts”。

`（3）innodb_autoinc_lock_mode = 2(“交错”锁定模式)`

从 MySQL 8.0 开始，交错锁模式是 `默认` 设置。

在此锁定模式下，自动递增值 `保证` 在所有并发执行的所有类型的insert语句中是 `唯一` 且 `单调递增` 的。但是，由于多个语句可以同时生成数字（即，跨语句交叉编号），**为任何给定语句插入的行生成的值可能不是连续的。**

如果执行的语句是“simple inserts"，其中要插入的行数已提前知道，除了"Mixed-mode inserts"之外，为单个语句生成的数字不会有间隙。然后，当执行"bulk inserts"时，在由任何给定语句分配的自动递增值中可能存在间隙。

##### ④ 元数据锁（MDL锁）

MySQL5.5引入了meta data lock，简称MDL锁，属于表锁范畴。MDL 的作用是，保证读写的正确性。比 如，如果一个查询正在遍历一个表中的数据，而执行期间另一个线程对这个 `表结构做变更` ，增加了一 列，那么查询线程拿到的结果跟表结构对不上，肯定是不行的。

因此，**当对一个表做增删改查操作的时候，加 MDL读锁；当要对表做结构变更操作的时候，加 MDL 写锁**。

读锁之间不互斥，因此你可以有多个线程同时对一张表增删查改。读写锁之间、写锁之间都是互斥的，用来保证变更表结构操作的安全性，解决了DML和DDL操作之间的一致性问题。`不需要显式使用`，在访问一个表的时候会被自动加上。

**举例：元数据锁的使用场景模拟**

**会话A：**从表中查询数据

```mysql
mysql> BEGIN;
Query OK, 0 rows affected (0.00 sec)
mysql> SELECT COUNT(1) FROM teacher;
+----------+
| COUNT(1) |
+----------+
| 2        |
+----------+
1 row int set (7.46 sec)
```

**会话B：**修改表结构，增加新列

```mysql
mysql> BEGIN;
Query OK, 0 rows affected (0.00 sec)
mysql> alter table teacher add age int not null;
```

**会话C：**查看当前MySQL的进程

```mysql
mysql> show processlist;
```

![image-20220713142808924](MySQL事物篇.assets/image-20220713142808924.png)

通过会话C可以看出会话B被阻塞，这是由于会话A拿到了teacher表的元数据读锁，会话B想申请teacher表的元数据写锁，由于读写锁互斥，会话B需要等待会话A释放元数据锁才能执行。

<img src="MySQL事物篇.assets/image-20220713143156759.png" alt="image-20220713143156759" style="float:left;" />

#### 2. InnoDB中的行锁

行锁（Row Lock）也称为记录锁，顾名思义，就是锁住某一行（某条记录 row）。需要注意的是，MySQL服务器层并没有实现行锁机制，**行级锁只在存储引擎层实现**。

**优点：**锁定力度小，发生`锁冲突概率低`，可以实现的`并发度高`。

**缺点：**对于`锁的开销比较大`，加锁会比较慢，容易出现`死锁`情况。

InnoDB与MyISAM的最大不同有两点：一是支持事物（TRANSACTION）；二是采用了行级锁。

首先我们创建表如下：

```mysql
CREATE TABLE student (
	id INT,
    name VARCHAR(20),
    class VARCHAR(10),
    PRIMARY KEY (id)
) Engine=InnoDB CHARSET=utf8;
```

向这个表里插入几条记录：

```mysql
INSERT INTO student VALUES
(1, '张三', '一班'),
(3, '李四', '一班'),
(8, '王五', '二班'),
(15, '赵六', '二班'),
(20, '钱七', '三班');

mysql> SELECT * FROM student;
```

<img src="MySQL事物篇.assets/image-20220713161549241.png" alt="image-20220713161549241" style="float:left;" />

student表中的聚簇索引的简图如下所示。

![image-20220713163353648](MySQL事物篇.assets/image-20220713163353648.png)

这里把B+树的索引结构做了超级简化，只把索引中的记录给拿了出来，下面看看都有哪些常用的行锁类型。

##### ① 记录锁（Record Locks）

记录锁也就是仅仅把一条记录锁，官方的类型名称为：`LOCK_REC_NOT_GAP`。比如我们把id值为8的那条记录加一个记录锁的示意图如果所示。仅仅是锁住了id值为8的记录，对周围的数据没有影响。

![image-20220713164811567](MySQL事物篇.assets/image-20220713164811567.png)

举例如下：

![image-20220713164948405](MySQL事物篇.assets/image-20220713164948405.png)

记录锁是有S锁和X锁之分的，称之为 `S型记录锁` 和 `X型记录锁` 。

* 当一个事务获取了一条记录的S型记录锁后，其他事务也可以继续获取该记录的S型记录锁，但不可以继续获取X型记录锁；
* 当一个事务获取了一条记录的X型记录锁后，其他事务既不可以继续获取该记录的S型记录锁，也不可以继续获取X型记录锁。

##### ② 间隙锁（Gap Locks）

`MySQL` 在 `REPEATABLE READ` 隔离级别下是可以解决幻读问题的，解决方案有两种，可以使用 `MVCC` 方 案解决，也可以采用 `加锁 `方案解决。但是在使用加锁方案解决时有个大问题，就是事务在第一次执行读取操作时，那些幻影记录尚不存在，我们无法给这些 `幻影记录` 加上 `记录锁` 。InnoDB提出了一种称之为 `Gap Locks` 的锁，官方的类型名称为：` LOCK_GAP` ，我们可以简称为 `gap锁` 。比如，把id值为8的那条 记录加一个gap锁的示意图如下。

![image-20220713171650888](MySQL事物篇.assets/image-20220713171650888.png)

图中id值为8的记录加了gap锁，意味着 `不允许别的事务在id值为8的记录前边的间隙插入新记录` ，其实就是 id列的值(3, 8)这个区间的新记录是不允许立即插入的。比如，有另外一个事务再想插入一条id值为4的新 记录，它定位到该条新记录的下一条记录的id值为8，而这条记录上又有一个gap锁，所以就会阻塞插入 操作，直到拥有这个gap锁的事务提交了之后，id列的值在区间(3, 8)中的新记录才可以被插入。

**gap锁的提出仅仅是为了防止插入幻影记录而提出的。**虽然有`共享gap锁`和`独占gap锁`这样的说法，但是它们起到的作用是相同的。而且如果对一条记录加了gap锁（不论是共享gap锁还是独占gap锁），并不会限制其他事务对这条记录加记录锁或者继续加gap锁。

**举例：**

| Session1                                             | Session2                                     |
| ---------------------------------------------------- | -------------------------------------------- |
| select * from student where id=5 lock in share mode; |                                              |
|                                                      | select * from student where id=5 for update; |

这里session2并不会被堵住。因为表里并没有id=5这条记录，因此session1嘉的是间隙锁(3,8)。而session2也是在这个间隙加的间隙锁。它们有共同的目标，即：保护这个间隙锁，不允许插入值。但，它们之间是不冲突的。

<img src="MySQL事物篇.assets/image-20220713174726264.png" alt="image-20220713174726264" style="float:left;" />

* `Infimum`记录，表示该页面中最小的记录。
* `Supremun`记录，表示该页面中最大的记录。

为了实现阻止其他事务插入id值再(20,正无穷)这个区间的新纪录，我们可以给索引中的最后一条记录，也就是id值为20的那条记录所在页面的Supremun记录加上一个gap锁，如图所示。

![image-20220713174108634](MySQL事物篇.assets/image-20220713174108634.png)

```mysql
mysql> select * from student where id > 20 lock in share mode;
Empty set (0.01 sec)
```

检测：

![image-20220713174551814](MySQL事物篇.assets/image-20220713174551814.png)

![image-20220713174602102](MySQL事物篇.assets/image-20220713174602102.png)

<img src="MySQL事物篇.assets/image-20220713175032619.png" alt="image-20220713175032619" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220713192418730.png" alt="image-20220713192418730" style="float:left;" />

##### ③ 临键锁（Next-Key Locks）

有时候我们既想 `锁住某条记录` ，又想 阻止 其他事务在该记录前边的 间隙插入新记录 ，所以InnoDB就提 出了一种称之为 Next-Key Locks 的锁，官方的类型名称为： LOCK_ORDINARY ，我们也可以简称为 next-key锁 。Next-Key Locks是在存储引擎 innodb 、事务级别在 可重复读 的情况下使用的数据库锁， innodb默认的锁就是Next-Key locks。比如，我们把id值为8的那条记录加一个next-key锁的示意图如下：

![image-20220713192549340](MySQL事物篇.assets/image-20220713192549340.png)

`next-key锁`的本质就是一个`记录锁`和一个`gap锁`的合体，它既能保护该条记录，又能阻止别的事务将新记录插入被保护记录前边的`间隙`。

```mysql
begin;
select * from student where id <=8 and id > 3 for update;
```

<img src="MySQL事物篇.assets/image-20220713203124889.png" alt="image-20220713203124889" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220713203532124.png" alt="image-20220713203532124" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220713203619704.png" alt="image-20220713203619704" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220713203714577.png" alt="image-20220713203714577" style="float:left;" />

#### 3. 页锁

页锁就是在 `页的粒度` 上进行锁定，锁定的数据资源比行锁要多，因为一个页中可以有多个行记录。当我 们使用页锁的时候，会出现数据浪费的现象，但这样的浪费最多也就是一个页上的数据行。**页锁的开销介于表锁和行锁之间，会出现死锁。锁定粒度介于表锁和行锁之间，并发度一般。**

每个层级的锁数量是有限制的，因为锁会占用内存空间， `锁空间的大小是有限的` 。当某个层级的锁数量 超过了这个层级的阈值时，就会进行 `锁升级` 。锁升级就是用更大粒度的锁替代多个更小粒度的锁，比如 InnoDB 中行锁升级为表锁，这样做的好处是占用的锁空间降低了，但同时数据的并发度也下降了。

### 3.3 从对待锁的态度划分:乐观锁、悲观锁

从对待锁的态度来看锁的话，可以将锁分成乐观锁和悲观锁，从名字中也可以看出这两种锁是两种看待 `数据并发的思维方式` 。需要注意的是，乐观锁和悲观锁并不是锁，而是锁的 `设计思想` 。

#### 1. 悲观锁（Pessimistic Locking）

悲观锁是一种思想，顾名思义，就是很悲观，对数据被其他事务的修改持保守态度，会通过数据库自身的锁机制来实现，从而保证数据操作的排它性。

悲观锁总是假设最坏的情况，每次去拿数据的时候都认为别人会修改，所以每次在拿数据的时候都会上锁，这样别人想拿这个数据就会 `阻塞` 直到它拿到锁（**共享资源每次只给一个线程使用，其它线程阻塞， 用完后再把资源转让给其它线程**）。比如行锁，表锁等，读锁，写锁等，都是在做操作之前先上锁，当其他线程想要访问数据时，都需要阻塞挂起。Java中 `synchronized` 和 `ReentrantLock` 等独占锁就是悲观锁思想的实现。

**秒杀案例1：**

<img src="MySQL事物篇.assets/image-20220713204544767.png" alt="image-20220713204544767" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220713205010502.png" alt="image-20220713205010502" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220713205135694.png" alt="image-20220713205135694" style="float:left;" />

#### 2. 乐观锁（Optimistic Locking）

乐观锁认为对同一数据的并发操作不会总发生，属于小概率事件，不用每次都对数据上锁，但是在更新的时候会判断一下在此期间别人有没有去更新这个数据，也就是**不采用数据库自身的锁机制，而是通过程序来实现**。在程序上，我们可以采用 `版本号机制` 或者 `CAS机制` 实现。**乐观锁适用于多读的应用类型， 这样可以提高吞吐量**。在Java中` java.util.concurrent.atomic` 包下的原子变量类就是使用了乐观锁的一种实现方式：CAS实现的。

**1. 乐观锁的版本号机制**

在表中设计一个 `版本字段 version` ，第一次读的时候，会获取 version 字段的取值。然后对数据进行更新或删除操作时，会执行 `UPDATE ... SET version=version+1 WHERE version=version` 。此时 如果已经有事务对这条数据进行了更改，修改就不会成功。

这种方式类似我们熟悉的SVN、CVS版本管理系统，当我们修改了代码进行提交时，首先会检查当前版本号与服务器上的版本号是否一致，如果一致就可以直接提交，如果不一致就需要更新服务器上的最新代码，然后再进行提交。

**2. 乐观锁的时间戳机制**

时间戳和版本号机制一样，也是在更新提交的时候，将当前数据的时间戳和更新之前取得的时间戳进行 比较，如果两者一致则更新成功，否则就是版本冲突。

你能看到乐观锁就是程序员自己控制数据并发操作的权限，基本是通过给数据行增加一个戳（版本号或 者时间戳），从而证明当前拿到的数据是否最新。

<img src="MySQL事物篇.assets/image-20220713210951100.png" alt="image-20220713210951100" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220713211139670.png" alt="image-20220713211139670" style="float:left;" />

#### 3. 两种锁的适用场景

从这两种锁的设计思想中，我们总结一下乐观锁和悲观锁的适用场景：

1. `乐观锁` 适合 `读操作多` 的场景，相对来说写的操作比较少。它的优点在于 `程序实现` ， `不存在死锁` 问题，不过适用场景也会相对乐观，因为它阻止不了除了程序以外的数据库操作。
2. `悲观锁` 适合 `写操作多` 的场景，因为写的操作具有 `排它性` 。采用悲观锁的方式，可以在数据库层 面阻止其他事务对该数据的操作权限，防止 `读 - 写` 和 `写 - 写` 的冲突。

<img src="MySQL事物篇.assets/image-20220713211417909.png" alt="image-20220713211417909" style="float:left;" />

### 3.4 按加锁的方式划分：显式锁、隐式锁

#### 1. 隐式锁

<img src="MySQL事物篇.assets/image-20220713211525845.png" alt="image-20220713211525845" style="float:left;" />

* **情景一**：对于聚簇索引记录来说，有一个 `trx_id` 隐藏列，该隐藏列记录着最后改动该记录的 `事务 id` 。那么如果在当前事务中新插入一条聚簇索引记录后，该记录的 trx_id 隐藏列代表的的就是 当前事务的 事务id ，如果其他事务此时想对该记录添加 S锁 或者 X锁 时，首先会看一下该记录的 trx_id 隐藏列代表的事务是否是当前的活跃事务，如果是的话，那么就帮助当前事务创建一个 X 锁 （也就是为当前事务创建一个锁结构， is_waiting 属性是 false ），然后自己进入等待状态 （也就是为自己也创建一个锁结构， is_waiting 属性是 true ）。
* **情景二**：对于二级索引记录来说，本身并没有 trx_id 隐藏列，但是在二级索引页面的 Page Header 部分有一个 `PAGE_MAX_TRX_ID` 属性，该属性代表对该页面做改动的最大的 `事务id` ，如 果 PAGE_MAX_TRX_ID 属性值小于当前最小的活跃 事务id ，那么说明对该页面做修改的事务都已 经提交了，否则就需要在页面中定位到对应的二级索引记录，然后回表找到它对应的聚簇索引记 录，然后再重复 情景一 的做法。

<img src="MySQL事物篇.assets/image-20220713214522709.png" alt="image-20220713214522709" style="float:left;" />

**session 1:**

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)
mysql> insert INTO student VALUES(34,"周八","二班");
Query OK, 1 row affected (0.00 sec)
```

**session 2:**

```mysql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)
mysql> select * from student lock in share mode; #执行完，当前事务被阻塞
```

执行下述语句，输出结果：

```mysql
mysql> SELECT * FROM performance_schema.data_lock_waits\G;
*************************** 1. row ***************************
						ENGINE: INNODB
		REQUESTING_ENGINE_LOCK_ID: 140562531358232:7:4:9:140562535668584
REQUESTING_ENGINE_TRANSACTION_ID: 422037508068888
			REQUESTING_THREAD_ID: 64
			REQUESTING_EVENT_ID: 6
REQUESTING_OBJECT_INSTANCE_BEGIN: 140562535668584
		BLOCKING_ENGINE_LOCK_ID: 140562531351768:7:4:9:140562535619104
BLOCKING_ENGINE_TRANSACTION_ID: 15902
			BLOCKING_THREAD_ID: 64
			BLOCKING_EVENT_ID: 6
BLOCKING_OBJECT_INSTANCE_BEGIN: 140562535619104
1 row in set (0.00 sec)
```

隐式锁的逻辑过程如下：

A. InnoDB的每条记录中都一个隐含的trx_id字段，这个字段存在于聚簇索引的B+Tree中。 

B. 在操作一条记录前，首先根据记录中的trx_id检查该事务是否是活动的事务(未提交或回滚)。如果是活动的事务，首先将 `隐式锁` 转换为 `显式锁` (就是为该事务添加一个锁)。 

C. 检查是否有锁冲突，如果有冲突，创建锁，并设置为waiting状态。如果没有冲突不加锁，跳到E。 

D. 等待加锁成功，被唤醒，或者超时。 

E. 写数据，并将自己的trx_id写入trx_id字段。

#### 2. 显式锁

通过特定的语句进行加锁，我们一般称之为显示加锁，例如：

显示加共享锁：

```mysql
select .... lock in share mode
```

显示加排它锁：

```mysql
select .... for update
```

### 3.5 其它锁之：全局锁

全局锁就是对 `整个数据库实例` 加锁。当你需要让整个库处于 `只读状态` 的时候，可以使用这个命令，之后 其他线程的以下语句会被阻塞：数据更新语句（数据的增删改）、数据定义语句（包括建表、修改表结 构等）和更新类事务的提交语句。全局锁的典型使用 `场景` 是：做 `全库逻辑备份` 。

全局锁的命令：

```mysql
Flush tables with read lock
```

### 3.6 其它锁之：死锁

#### 1. 概念

两个事务都持有对方需要的锁，并且在等待对方释放，并且双方都不会释放自己的锁。

**举例1：**

![image-20220713220714098](MySQL事物篇.assets/image-20220713220714098.png)

**举例2：**

用户A给用户B转账100，再次同时，用户B也给用户A转账100。这个过程，可能导致死锁。

<img src="MySQL事物篇.assets/image-20220713220936236.png" alt="image-20220713220936236" style="float:left;" />

#### 2. 产生死锁的必要条件

1. 两个或者两个以上事务
2. 每个事务都已经持有锁并且申请新的锁
3. 锁资源同时只能被同一个事务持有或者不兼容
4. 事务之间因为持有锁和申请锁导致彼此循环等待

> 死锁的关键在于：两个（或以上）的Session加锁的顺序不一致。

#### 3. 如何处理死锁

**方式1：**等待，直到超时（innodb_lock_wait_timeout=50s)

<img src="MySQL事物篇.assets/image-20220713221418100.png" alt="image-20220713221418100" style="float:left;" />

**方式2：**使用死锁检测处理死锁程序

方式1检测死锁太过被动，innodb还提供了`wait-for graph算法`来主动进行死锁检测，每当加锁请求无法立即满足需要并进入等待时，wait-for graph算法都会被触发。

这是一种较为`主动的死锁检测机制`，要求数据库保存`锁的信息链表`和`事物等待链表`两部分信息。

![image-20220713221758941](MySQL事物篇.assets/image-20220713221758941.png)

基于这两个信息，可以绘制wait-for graph（等待图）

![image-20220713221830455](MySQL事物篇.assets/image-20220713221830455.png)

> 死锁检测的原理是构建一个以事务为顶点，锁为边的有向图，判断有向图是否存在环，存在既有死锁。

一旦检测到回路、有死锁，这时候InnoDB存储引擎会选择`回滚undo量最小的事务`，让其他事务继续执行（`innodb_deadlock_detect=on`表示开启这个逻辑）。

缺点：每个新的被阻塞的线程，都要判断是不是由于自己的加入导致了死锁，这个操作时间复杂度是O(n)。如果100个并发线程同时更新同一行，意味着要检测100*100=1万次，1万个线程就会有1千万次检测。

**如何解决？**

* 方式1：关闭死锁检测，但意味着可能会出现大量的超时，会导致业务有损。
* 方式2：控制并发访问的数量。比如在中间件中实现对于相同行的更新，在进入引擎之前排队，这样在InnoDB内部就不会有大量的死锁检测工作。

**进一步的思路：**

可以考虑通过将一行改成逻辑上的多行来减少`锁冲突`。比如，连锁超市账户总额的记录，可以考虑放到多条记录上。账户总额等于这多个记录的值的总和。

#### 4. 如何避免死锁

<img src="MySQL事物篇.assets/image-20220714131008260.png" alt="image-20220714131008260" style="float:left;" />

## 4. 锁的内部结构

我们前边说对一条记录加锁的本质就是在内存中创建一个`锁结构`与之关联，那么是不是一个事务对多条记录加锁，就要创建多个`锁结构`呢？比如：

```mysql
# 事务T1
SELECT * FROM user LOCK IN SHARE MODE;
```

理论上创建多个`锁结构`没问题，但是如果一个事务要获取10000条记录的锁，生成10000个锁结构也太崩溃了！所以决定在对不同记录加锁时，如果符合下边这些条件的记录会放在一个`锁结构`中。

* 在同一个事务中进行加锁操作
* 被加锁的记录在同一个页面中
* 加锁的类型是一样的
* 等待状态是一样的

`InnoDB` 存储引擎中的 `锁结构` 如下：

![image-20220714132306208](MySQL事物篇.assets/image-20220714132306208.png)

结构解析：

`1. 锁所在的事务信息 `：

不论是 `表锁` 还是 `行锁` ，都是在事务执行过程中生成的，哪个事务生成了这个锁结构 ，这里就记录这个 事务的信息。

此 `锁所在的事务信息` 在内存结构中只是一个指针，通过指针可以找到内存中关于该事务的更多信息，比方说事务id等。

`2. 索引信息` ：

对于 `行锁` 来说，需要记录一下加锁的记录是属于哪个索引的。这里也是一个指针。

`3. 表锁／行锁信息` ：

`表锁结构` 和 `行锁结构` 在这个位置的内容是不同的：

* 表锁：

  记载着是对哪个表加的锁，还有其他的一些信息。

* 行锁：

  记载了三个重要的信息：

  * `Space ID` ：记录所在表空间。
  * `Page Number` ：记录所在页号。
  * `n_bits `：对于行锁来说，一条记录就对应着一个比特位，一个页面中包含很多记录，用不同 的比特位来区分到底是哪一条记录加了锁。为此在行锁结构的末尾放置了一堆比特位，这个` n_bis `属性代表使用了多少比特位。

  > n_bits的值一般都比页面中记录条数多一些。主要是为了之后在页面中插入了新记录后 也不至于重新分配锁结构

`4. type_mode` ：

这是一个32位的数，被分成了 `lock_mode` 、 `lock_type` 和 `rec_lock_type` 三个部分，如图所示：

![image-20220714133319666](MySQL事物篇.assets/image-20220714133319666.png)

* 锁的模式（ `lock_mode` ），占用低4位，可选的值如下：
  * `LOCK_IS` （十进制的 0 ）：表示共享意向锁，也就是 `IS锁` 。 
  * `LOCK_IX` （十进制的 1 ）：表示独占意向锁，也就是 `IX锁` 。 
  * `LOCK_S` （十进制的 2 ）：表示共享锁，也就是 `S锁` 。 
  * `LOCK_X` （十进制的 3 ）：表示独占锁，也就是 `X锁` 。 
  * `LOCK_AUTO_INC` （十进制的 4 ）：表示 `AUTO-INC锁` 。

在InnoDB存储引擎中，LOCK_IS，LOCK_IX，LOCK_AUTO_INC都算是表级锁的模式，LOCK_S和 LOCK_X既可以算是表级锁的模式，也可以是行级锁的模式。

* 锁的类型（ `lock_type` ），占用第5～8位，不过现阶段只有第5位和第6位被使用：
  * `LOCK_TABLE` （十进制的 16 ），也就是当第5个比特位置为1时，表示表级锁。
  * `LOCK_REC `（十进制的 32 ），也就是当第6个比特位置为1时，表示行级锁。
* 行锁的具体类型（ `rec_lock_type` ），使用其余的位来表示。只有在 `lock_type` 的值为 `LOCK_REC` 时，也就是只有在该锁为行级锁时，才会被细分为更多的类型：
  * `LOCK_ORDINARY` （十进制的 0 ）：表示 `next-key锁` 。
  * `LOCK_GAP` （十进制的 512 ）：也就是当第10个比特位置为1时，表示 `gap锁` 。
  * `LOCK_REC_NOT_GAP` （十进制的 1024 ）：也就是当第11个比特位置为1时，表示正经 `记录锁` 。
  * `LOCK_INSERT_INTENTION` （十进制的 2048 ）：也就是当第12个比特位置为1时，表示插入意向锁。其他的类型：还有一些不常用的类型我们就不多说了。
* `is_waiting` 属性呢？基于内存空间的节省，所以把 `is_waiting` 属性放到了 `type_mode` 这个32 位的数字中：
  * `LOCK_WAIT` （十进制的 256 ） ：当第9个比特位置为 1 时，表示 `is_waiting` 为 `true` ，也 就是当前事务尚未获取到锁，处在等待状态；当这个比特位为 0 时，表示 `is_waiting` 为 `false` ，也就是当前事务获取锁成功。

`5. 其他信息` ：

为了更好的管理系统运行过程中生成的各种锁结构而设计了各种哈希表和链表。

`6. 一堆比特位` ：

如果是 `行锁结构` 的话，在该结构末尾还放置了一堆比特位，比特位的数量是由上边提到的 `n_bits` 属性 表示的。InnoDB数据页中的每条记录在 `记录头信息` 中都包含一个 `heap_no` 属性，伪记录 `Infimum` 的 `heap_no` 值为 0 ， `Supremum` 的 `heap_no` 值为 1 ，之后每插入一条记录， `heap_no` 值就增1。 锁结 构 最后的一堆比特位就对应着一个页面中的记录，一个比特位映射一个 `heap_no` ，即一个比特位映射 到页内的一条记录。

## 5. 锁监控

关于MySQL锁的监控，我们一般可以通过检查 InnoDB_row_lock 等状态变量来分析系统上的行锁的争夺情况

```mysql
mysql> show status like 'innodb_row_lock%';
+-------------------------------+-------+
| Variable_name                 | Value |
+-------------------------------+-------+
| Innodb_row_lock_current_waits | 0     |
| Innodb_row_lock_time          | 0     |
| Innodb_row_lock_time_avg      | 0     |
| Innodb_row_lock_time_max      | 0     |
| Innodb_row_lock_waits         | 0     |
+-------------------------------+-------+
5 rows in set (0.01 sec)
```

对各个状态量的说明如下：

* Innodb_row_lock_current_waits：当前正在等待锁定的数量； 
* `Innodb_row_lock_time` ：从系统启动到现在锁定总时间长度；（等待总时长） 
* `Innodb_row_lock_time_avg` ：每次等待所花平均时间；（等待平均时长） 
* Innodb_row_lock_time_max：从系统启动到现在等待最常的一次所花的时间； 
* `Innodb_row_lock_waits` ：系统启动后到现在总共等待的次数；（等待总次数）

对于这5个状态变量，比较重要的3个见上面（灰色）。

尤其是当等待次数很高，而且每次等待时长也不小的时候，我们就需要分析系统中为什么会有如此多的等待，然后根据分析结果着手指定优化计划。

**其他监控方法：**

MySQL把事务和锁的信息记录在了 `information_schema` 库中，涉及到的三张表分别是 `INNODB_TRX` 、 `INNODB_LOCKS` 和 `INNODB_LOCK_WAITS` 。

`MySQL5.7及之前` ，可以通过information_schema.INNODB_LOCKS查看事务的锁情况，但只能看到阻塞事 务的锁；如果事务并未被阻塞，则在该表中看不到该事务的锁情况。

MySQL8.0删除了information_schema.INNODB_LOCKS，添加了 `performance_schema.data_locks` ，可以通过performance_schema.data_locks查看事务的锁情况，和MySQL5.7及之前不同， performance_schema.data_locks不但可以看到阻塞该事务的锁，还可以看到该事务所持有的锁。

同时，information_schema.INNODB_LOCK_WAITS也被 `performance_schema.data_lock_waits` 所代 替。

我们模拟一个锁等待的场景，以下是从这三张表收集的信息

锁等待场景，我们依然使用记录锁中的案例，当事务2进行等待时，查询情况如下：

（1）查询正在被锁阻塞的sql语句。

```mysql
SELECT * FROM information_schema.INNODB_TRX\G;
```

重要属性代表含义已在上述中标注。

（2）查询锁等待情况

```mysql
SELECT * FROM data_lock_waits\G;
*************************** 1. row ***************************
							ENGINE: INNODB
		REQUESTING_ENGINE_LOCK_ID: 139750145405624:7:4:7:139747028690608
REQUESTING_ENGINE_TRANSACTION_ID: 13845 #被阻塞的事务ID
			REQUESTING_THREAD_ID: 72
			REQUESTING_EVENT_ID: 26
REQUESTING_OBJECT_INSTANCE_BEGIN: 139747028690608
		BLOCKING_ENGINE_LOCK_ID: 139750145406432:7:4:7:139747028813248
BLOCKING_ENGINE_TRANSACTION_ID: 13844 #正在执行的事务ID，阻塞了13845
			BLOCKING_THREAD_ID: 71
			BLOCKING_EVENT_ID: 24
BLOCKING_OBJECT_INSTANCE_BEGIN: 139747028813248
1 row in set (0.00 sec)
```

（3）查询锁的情况

```mysql
mysql > SELECT * from performance_schema.data_locks\G;
*************************** 1. row ***************************
ENGINE: INNODB
ENGINE_LOCK_ID: 139750145405624:1068:139747028693520
ENGINE_TRANSACTION_ID: 13847
THREAD_ID: 72
EVENT_ID: 31
OBJECT_SCHEMA: atguigu
OBJECT_NAME: user
PARTITION_NAME: NULL
SUBPARTITION_NAME: NULL
INDEX_NAME: NULL
OBJECT_INSTANCE_BEGIN: 139747028693520
LOCK_TYPE: TABLE
LOCK_MODE: IX
LOCK_STATUS: GRANTED
LOCK_DATA: NULL
*************************** 2. row ***************************
ENGINE: INNODB
ENGINE_LOCK_ID: 139750145405624:7:4:7:139747028690608
ENGINE_TRANSACTION_ID: 13847
THREAD_ID: 72
EVENT_ID: 31
OBJECT_SCHEMA: atguigu
OBJECT_NAME: user
PARTITION_NAME: NULL
SUBPARTITION_NAME: NULL
INDEX_NAME: PRIMARY
OBJECT_INSTANCE_BEGIN: 139747028690608
LOCK_TYPE: RECORD
LOCK_MODE: X,REC_NOT_GAP
LOCK_STATUS: WAITING
LOCK_DATA: 1
*************************** 3. row ***************************
ENGINE: INNODB
ENGINE_LOCK_ID: 139750145406432:1068:139747028816304
ENGINE_TRANSACTION_ID: 13846
THREAD_ID: 71
EVENT_ID: 28
OBJECT_SCHEMA: atguigu
OBJECT_NAME: user
PARTITION_NAME: NULL
SUBPARTITION_NAME: NULL
INDEX_NAME: NULL
OBJECT_INSTANCE_BEGIN: 139747028816304
LOCK_TYPE: TABLE
LOCK_MODE: IX
LOCK_STATUS: GRANTED
LOCK_DATA: NULL
*************************** 4. row ***************************
ENGINE: INNODB
ENGINE_LOCK_ID: 139750145406432:7:4:7:139747028813248
ENGINE_TRANSACTION_ID: 13846
THREAD_ID: 71
EVENT_ID: 28
OBJECT_SCHEMA: atguigu
OBJECT_NAME: user
PARTITION_NAME: NULL
SUBPARTITION_NAME: NULL
INDEX_NAME: PRIMARY
OBJECT_INSTANCE_BEGIN: 139747028813248
LOCK_TYPE: RECORD
LOCK_MODE: X,REC_NOT_GAP
LOCK_STATUS: GRANTED
LOCK_DATA: 1
4 rows in set (0.00 sec)

ERROR:
No query specified
```

从锁的情况可以看出来，两个事务分别获取了IX锁，我们从意向锁章节可以知道，IX锁互相时兼容的。所 以这里不会等待，但是事务1同样持有X锁，此时事务2也要去同一行记录获取X锁，他们之间不兼容，导 致等待的情况发生。

## 6. 附录

**间隙锁加锁规则（共11个案例）**

间隙锁是在可重复读隔离级别下才会生效的： next-key lock 实际上是由间隙锁加行锁实现的，如果切换 到读提交隔离级别 (read-committed) 的话，就好理解了，过程中去掉间隙锁的部分，也就是只剩下行锁 的部分。而在读提交隔离级别下间隙锁就没有了，为了解决可能出现的数据和日志不一致问题，需要把 binlog 格式设置为 row 。也就是说，许多公司的配置为：读提交隔离级别加 binlog_format=row。业务不 需要可重复读的保证，这样考虑到读提交下操作数据的锁范围更小（没有间隙锁），这个选择是合理的。

next-key lock的加锁规则

总结的加锁规则里面，包含了两个 “ “ 原则 ” ” 、两个 “ “ 优化 ” ” 和一个 “bug” 。

1. 原则 1 ：加锁的基本单位是 next-key lock 。 next-key lock 是前开后闭区间。 
2. 原则 2 ：查找过程中访问到的对象才会加锁。任何辅助索引上的锁，或者非索引列上的锁，最终 都要回溯到主键上，在主键上也要加一把锁。 
3. 优化 1 ：索引上的等值查询，给唯一索引加锁的时候， next-key lock 退化为行锁。也就是说如果 InnoDB扫描的是一个主键、或是一个唯一索引的话，那InnoDB只会采用行锁方式来加锁 
4. 优化 2 ：索引上（不一定是唯一索引）的等值查询，向右遍历时且最后一个值不满足等值条件的 时候， next-keylock 退化为间隙锁。 
5. 一个 bug ：唯一索引上的范围查询会访问到不满足条件的第一个值为止。

我们以表test作为例子，建表语句和初始化语句如下：其中id为主键索引

```mysql
CREATE TABLE `test` (
`id` int(11) NOT NULL,
`col1` int(11) DEFAULT NULL,
`col2` int(11) DEFAULT NULL,
PRIMARY KEY (`id`),
KEY `c` (`c`)
) ENGINE=InnoDB;
insert into test values(0,0,0),(5,5,5),
(10,10,10),(15,15,15),(20,20,20),(25,25,25);
```

**案例一：唯一索引等值查询间隙锁**

![image-20220714134603698](MySQL事物篇.assets/image-20220714134603698.png)

由于表 test 中没有 id=7 的记录

根据原则 1 ，加锁单位是 next-key lock ， session A 加锁范围就是 (5,10] ； 同时根据优化 2 ，这是一个等 值查询 (id=7) ，而 id=10 不满足查询条件， next-key lock 退化成间隙锁，因此最终加锁的范围是 (5,10)

**案例二：非唯一索引等值查询锁**

![image-20220714134623052](MySQL事物篇.assets/image-20220714134623052-16577775838551.png)

这里 session A 要给索引 col1 上 col1=5 的这一行加上读锁。

1. 根据原则 1 ，加锁单位是 next-key lock ，左开右闭，5是闭上的，因此会给 (0,5] 加上 next-key lock 。 
2. 要注意 c 是普通索引，因此仅访问 c=5 这一条记录是不能马上停下来的（可能有col1=5的其他记 录），需要向右遍历，查到c=10 才放弃。根据原则 2 ，访问到的都要加锁，因此要给 (5,10] 加 next-key lock 。 
3. 但是同时这个符合优化 2 ：等值判断，向右遍历，最后一个值不满足 col1=5 这个等值条件，因此退化成间隙锁 (5,10) 。
4. 根据原则 2 ， 只有访问到的对象才会加锁，这个查询使用覆盖索引，并不需要访问主键索引，所以主键索引上没有加任何锁，这就是为什么 session B 的 update 语句可以执行完成。

但 session C 要插入一个 (7,7,7) 的记录，就会被 session A 的间隙锁 (5,10) 锁住 这个例子说明，锁是加在索引上的。

执行 for update 时，系统会认为你接下来要更新数据，因此会顺便给主键索引上满足条件的行加上行锁。

如果你要用 lock in share mode来给行加读锁避免数据被更新的话，就必须得绕过覆盖索引的优化，因为覆盖索引不会访问主键索引，不会给主键索引上加锁

**案例三：主键索引范围查询锁**

上面两个例子是等值查询的，这个例子是关于范围查询的，也就是说下面的语句

```mysql
select * from test where id=10 for update
select * from tets where id>=10 and id<11 for update;
```

这两条查语句肯定是等价的，但是它们的加锁规则不太一样

![image-20220714134742049](MySQL事物篇.assets/image-20220714134742049.png)

1. 开始执行的时候，要找到第一个 id=10 的行，因此本该是 next-key lock(5,10] 。 根据优化 1 ，主键 id 上的等值条件，退化成行锁，只加了 id=10 这一行的行锁。 
2. 它是范围查询， 范围查找就往后继续找，找到 id=15 这一行停下来，不满足条件，因此需要加 next-key lock(10,15] 。

session A 这时候锁的范围就是主键索引上，行锁 id=10 和 next-key lock(10,15] 。**首次 session A 定位查找 id=10 的行的时候，是当做等值查询来判断的，而向右扫描到 id=15 的时候，用的是范围查询判断。**

**案例四：非唯一索引范围查询锁**

与案例三不同的是，案例四中查询语句的 where 部分用的是字段 c ，它是普通索引

这两条查语句肯定是等价的，但是它们的加锁规则不太一样

![image-20220714134822160](MySQL事物篇.assets/image-20220714134822160.png)

在第一次用 col1=10 定位记录的时候，索引 c 上加了 (5,10] 这个 next-key lock 后，由于索引 col1 是非唯 一索引，没有优化规则，也就是说不会蜕变为行锁，因此最终 sesion A 加的锁是，索引 c 上的 (5,10] 和 (10,15] 这两个 next-keylock 。

这里需要扫描到 col1=15 才停止扫描，是合理的，因为 InnoDB 要扫到 col1=15 ，才知道不需要继续往后找了。

**案例五：唯一索引范围查询锁 bug**

![image-20220714134846740](MySQL事物篇.assets/image-20220714134846740.png)

session A 是一个范围查询，按照原则 1 的话，应该是索引 id 上只加 (10,15] 这个 next-key lock ，并且因 为 id 是唯一键，所以循环判断到 id=15 这一行就应该停止了。

但是实现上， InnoDB 会往前扫描到第一个不满足条件的行为止，也就是 id=20 。而且由于这是个范围扫描，因此索引 id 上的 (15,20] 这个 next-key lock 也会被锁上。照理说，这里锁住 id=20 这一行的行为，其实是没有必要的。因为扫描到 id=15 ，就可以确定不用往后再找了。

**案例六：非唯一索引上存在 " " 等值 " " 的例子**

这里，我给表 t 插入一条新记录：insert into t values(30,10,30);也就是说，现在表里面有两个c=10的行

**但是它们的主键值 id 是不同的（分别是 10 和 30 ），因此这两个c=10 的记录之间，也是有间隙的。**

![image-20220714134923414](MySQL事物篇.assets/image-20220714134923414.png)

这次我们用 delete 语句来验证。注意， delete 语句加锁的逻辑，其实跟 select ... for update 是类似的， 也就是我在文章开始总结的两个 “ 原则 ” 、两个 “ 优化 ” 和一个 “bug” 。

这时， session A 在遍历的时候，先访问第一个 col1=10 的记录。同样地，根据原则 1 ，这里加的是 (col1=5,id=5) 到 (col1=10,id=10) 这个 next-key lock 。

由于c是普通索引，所以继续向右查找，直到碰到 (col1=15,id=15) 这一行循环才结束。根据优化 2 ，这是 一个等值查询，向右查找到了不满足条件的行，所以会退化成 (col1=10,id=10) 到 (col1=15,id=15) 的间隙锁。

![image-20220714134945012](MySQL事物篇.assets/image-20220714134945012.png)

这个 delete 语句在索引 c 上的加锁范围，就是上面图中蓝色区域覆盖的部分。这个蓝色区域左右两边都 是虚线，表示开区间，即 (col1=5,id=5) 和 (col1=15,id=15) 这两行上都没有锁

**案例七： limit 语句加锁**

例子 6 也有一个对照案例，场景如下所示：

![image-20220714135007118](MySQL事物篇.assets/image-20220714135007118.png)

session A 的 delete 语句加了 limit 2 。你知道表 t 里 c=10 的记录其实只有两条，因此加不加 limit 2 ，删除的效果都是一样的。但是加锁效果却不一样

这是因为，案例七里的 delete 语句明确加了 limit 2 的限制，因此在遍历到 (col1=10, id=30) 这一行之后， 满足条件的语句已经有两条，循环就结束了。因此，索引 col1 上的加锁范围就变成了从（ col1=5,id=5) 到（ col1=10,id=30) 这个前开后闭区间，如下图所示：

![image-20220714135025045](MySQL事物篇.assets/image-20220714135025045-16577778257713.png)

这个例子对我们实践的指导意义就是， 在删除数据的时候尽量加 limit 。

这样不仅可以控制删除数据的条数，让操作更安全，还可以减小加锁的范围。

**案例八：一个死锁的例子**

![image-20220714135047760](MySQL事物篇.assets/image-20220714135047760.png)

1. session A 启动事务后执行查询语句加 lock in share mode ，在索引 col1 上加了 next-keylock(5,10] 和 间隙锁 (10,15) （索引向右遍历退化为间隙锁）； 
2. session B 的 update 语句也要在索引 c 上加 next-key lock(5,10] ，进入锁等待； 实际上分成了两步， 先是加 (5,10) 的间隙锁，加锁成功；然后加 col1=10 的行锁，因为sessionA上已经给这行加上了读 锁，此时申请死锁时会被阻塞 
3. 然后 session A 要再插入 (8,8,8) 这一行，被 session B 的间隙锁锁住。由于出现了死锁， InnoDB 让 session B 回滚

**案例九：order by索引排序的间隙锁1**

如下面一条语句

```mysql
begin;
select * from test where id>9 and id<12 order by id desc for update;
```

下图为这个表的索引id的示意图。

![image-20220714135130668](MySQL事物篇.assets/image-20220714135130668.png)

1. 首先这个查询语句的语义是 order by id desc ，要拿到满足条件的所有行，优化器必须先找到 “ 第 一个 id<12 的值 ” 。 
2. 这个过程是通过索引树的搜索过程得到的，在引擎内部，其实是要找到 id=12 的这个值，只是最终 没找到，但找到了 (10,15) 这个间隙。（ id=15 不满足条件，所以 next-key lock 退化为了间隙锁 (10, 15) 。）
3. 然后向左遍历，在遍历过程中，就不是等值查询了，会扫描到 id=5 这一行，又因为区间是左开右 闭的，所以会加一个next-key lock (0,5] 。 也就是说，在执行过程中，通过树搜索的方式定位记录 的时候，用的是 “ 等值查询 ” 的方法。

**案例十：order by索引排序的间隙锁2**

![image-20220714135206504](MySQL事物篇.assets/image-20220714135206504.png)

1. 由于是 order by col1 desc ，第一个要定位的是索引 col1 上 “ 最右边的 ”col1=20 的行。这是一个非唯一索引的等值查询：

   左开右闭区间，首先加上 next-key lock (15,20] 。 向右遍历，col1=25不满足条件，退化为间隙锁 所以会 加上间隙锁(20,25) 和 next-key lock (15,20] 。

2. 在索引 col1 上向左遍历，要扫描到 col1=10 才停下来。同时又因为左开右闭区间，所以 next-key lock 会加到 (5,10] ，这正是阻塞session B 的 insert 语句的原因。

3. 在扫描过程中， col1=20 、 col1=15 、 col1=10 这三行都存在值，由于是 select * ，所以会在主键 id 上加三个行锁。 因此， session A 的 select 语句锁的范围就是：

   1. 索引 col1 上 (5, 25) ；
   2. 主键索引上 id=15 、 20 两个行锁。

**案例十一：update修改数据的例子-先插入后删除**

![image-20220714135300189](MySQL事物篇.assets/image-20220714135300189.png)

注意：根据 col1>5 查到的第一个记录是 col1=10 ，因此不会加 (0,5] 这个 next-key lock 。

session A 的加锁范围是索引 col1 上的 (5,10] 、 (10,15] 、 (15,20] 、 (20,25] 和(25,supremum] 。

之后 session B 的第一个 update 语句，要把 col1=5 改成 col1=1 ，你可以理解为两步：

1. 插入 (col1=1, id=5) 这个记录；
2. 删除 (col1=5, id=5) 这个记录。

通过这个操作， session A 的加锁范围变成了图 7 所示的样子:

![image-20220714135333089](MySQL事物篇.assets/image-20220714135333089.png)

好，接下来 session B 要执行 update t set col1 = 5 where col1 = 1 这个语句了，一样地可以拆成两步：

1. 插入 (col1=5, id=5) 这个记录；
2.  删除 (col1=1, id=5) 这个记录。 第一步试图在已经加了间隙锁的 (1,10) 中插入数据，所以就被堵住了。

# 第16章_多版本并发控制

## 1. 什么是MVCC

MVCC （Multiversion Concurrency Control），多版本并发控制。顾名思义，MVCC 是通过数据行的多个版本管理来实现数据库的 `并发控制 `。这项技术使得在InnoDB的事务隔离级别下执行 `一致性读` 操作有了保证。换言之，就是为了查询一些正在被另一个事务更新的行，并且可以看到它们被更新之前的值，这样 在做查询的时候就不用等待另一个事务释放锁。

MVCC没有正式的标准，在不同的DBMS中MVCC的实现方式可能是不同的，也不是普遍使用的（大家可以参考相关的DBMS文档）。这里讲解InnoDB中MVCC的实现机制（MySQL其他的存储引擎并不支持它）。

## 2. 快照读与当前读

MVCC在MySQL InnoDB中的实现主要是为了提高数据库并发性能，用更好的方式去处理 `读-写冲突` ，做到 即使有读写冲突时，也能做到 `不加锁` ， `非阻塞并发读` ，而这个读指的就是 `快照读` , 而非 `当前读` 。当前 读实际上是一种加锁的操作，是悲观锁的实现。而MVCC本质是采用乐观锁思想的一种方式。

### 2.1 快照读

快照读又叫一致性读，读取的是快照数据。**不加锁的简单的 SELECT 都属于快照读**，即不加锁的非阻塞 读；比如这样：

```mysql
SELECT * FROM player WHERE ...
```

之所以出现快照读的情况，是基于提高并发性能的考虑，快照读的实现是基于MVCC，它在很多情况下， 避免了加锁操作，降低了开销。

既然是基于多版本，那么快照读可能读到的并不一定是数据的最新版本，而有可能是之前的历史版本。 

快照读的前提是隔离级别不是串行级别，串行级别下的快照读会退化成当前读。

### 2.2 当前读

当前读读取的是记录的最新版本（最新数据，而不是历史版本的数据），读取时还要保证其他并发事务 不能修改当前记录，会对读取的记录进行加锁。加锁的 SELECT，或者对数据进行增删改都会进行当前 读。比如：

```mysql
SELECT * FROM student LOCK IN SHARE MODE; # 共享锁
SELECT * FROM student FOR UPDATE; # 排他锁
INSERT INTO student values ... # 排他锁
DELETE FROM student WHERE ... # 排他锁
UPDATE student SET ... # 排他锁
```

## 3. 复习

### 3.1 再谈隔离级别

我们知道事务有 4 个隔离级别，可能存在三种并发问题：

![image-20220714140441064](MySQL事物篇.assets/image-20220714140441064.png)

<img src="MySQL事物篇.assets/image-20220714140510426.png" alt="image-20220714140510426" style="float:left;" />

![image-20220714140541555](MySQL事物篇.assets/image-20220714140541555.png)

### 3.2 隐藏字段、Undo Log版本链

回顾一下undo日志的版本链，对于使用 InnoDB 存储引擎的表来说，它的聚簇索引记录中都包含两个必要的隐藏列。

* `trx_id` ：每次一个事务对某条聚簇索引记录进行改动时，都会把该事务的 `事务id` 赋值给 `trx_id` 隐藏列。 
* `roll_pointer` ：每次对某条聚簇索引记录进行改动时，都会把旧的版本写入到 `undo日志` 中，然 后这个隐藏列就相当于一个指针，可以通过它来找到该记录修改前的信息。

<img src="MySQL事物篇.assets/image-20220714140716427.png" alt="image-20220714140716427" style="float:left;" />

假设插入该记录的`事务id`为`8`，那么此刻该条记录的示意图如下所示：

![image-20220714140801595](MySQL事物篇.assets/image-20220714140801595.png)

> insert undo只在事务回滚时起作用，当事务提交后，该类型的undo日志就没用了，它占用的Undo Log Segment也会被系统回收（也就是该undo日志占用的Undo页面链表要么被重用，要么被释放）。

假设之后两个事务id分别为 `10` 、 `20` 的事务对这条记录进行` UPDATE` 操作，操作流程如下：

![image-20220714140846658](MySQL事物篇.assets/image-20220714140846658.png)

<img src="MySQL事物篇.assets/image-20220714140908661.png" alt="image-20220714140908661" style="float:left;" />

每次对记录进行改动，都会记录一条undo日志，每条undo日志也都有一个 `roll_pointer` 属性 （ `INSERT` 操作对应的undo日志没有该属性，因为该记录并没有更早的版本），可以将这些 `undo日志` 都连起来，串成一个链表：

![image-20220714141012874](MySQL事物篇.assets/image-20220714141012874.png)

对该记录每次更新后，都会将旧值放到一条 `undo日志` 中，就算是该记录的一个旧版本，随着更新次数 的增多，所有的版本都会被 `roll_pointer` 属性连接成一个链表，我们把这个链表称之为 `版本链` ，版 本链的头节点就是当前记录最新的值。

每个版本中还包含生成该版本时对应的` 事务id `。

## 4. MVCC实现原理之ReadView

MVCC 的实现依赖于：`隐藏字段`、`Undo Log`、`Read View`。

### 4.1 什么是ReadView

<img src="MySQL事物篇.assets/image-20220714141154235.png" alt="image-20220714141154235" style="float:left;" />

### 4.2 设计思路

使用 `READ UNCOMMITTED` 隔离级别的事务，由于可以读到未提交事务修改过的记录，所以直接读取记录的最新版本就好了。

使用 `SERIALIZABLE` 隔离级别的事务，InnoDB规定使用加锁的方式来访问记录。

使用 `READ COMMITTED` 和 `REPEATABLE READ` 隔离级别的事务，都必须保证读到 `已经提交了的` 事务修改过的记录。假如另一个事务已经修改了记录但是尚未提交，是不能直接读取最新版本的记录的，核心问题就是需要判断一下版本链中的哪个版本是当前事务可见的，这是ReadView要解决的主要问题。

这个ReadView中主要包含4个比较重要的内容，分别如下：

1. `creator_trx_id` ，创建这个 Read View 的事务 ID。

   > 说明：只有在对表中的记录做改动时（执行INSERT、DELETE、UPDATE这些语句时）才会为 事务分配事务id，否则在一个只读事务中的事务id值都默认为0。

2. `trx_ids` ，表示在生成ReadView时当前系统中活跃的读写事务的 `事务id列表` 。

3. `up_limit_id` ，活跃的事务中最小的事务 ID。

4. `low_limit_id` ，表示生成ReadView时系统中应该分配给下一个事务的 id 值。low_limit_id 是系 统最大的事务id值，这里要注意是系统中的事务id，需要区别于正在活跃的事务ID。

> 注意：low_limit_id并不是trx_ids中的最大值，事务id是递增分配的。比如，现在有id为1， 2，3这三个事务，之后id为3的事务提交了。那么一个新的读事务在生成ReadView时， trx_ids就包括1和2，up_limit_id的值就是1，low_limit_id的值就是4。

<img src="MySQL事物篇.assets/image-20220714142254768.png" alt="image-20220714142254768" style="float:left;" />

### 4.3 ReadView的规则

有了这个ReadView，这样在访问某条记录时，只需要按照下边的步骤判断记录的某个版本是否可见。

* 如果被访问版本的trx_id属性值与ReadView中的 creator_trx_id 值相同，意味着当前事务在访问它自己修改过的记录，所以该版本可以被当前事务访问。 
* 如果被访问版本的trx_id属性值小于ReadView中的 up_limit_id 值，表明生成该版本的事务在当前事务生成ReadView前已经提交，所以该版本可以被当前事务访问。 
* 如果被访问版本的trx_id属性值大于或等于ReadView中的 low_limit_id 值，表明生成该版本的事务在当前事务生成ReadView后才开启，所以该版本不可以被当前事务访问。 
* 如果被访问版本的trx_id属性值在ReadView的 up_limit_id 和 low_limit_id 之间，那就需要判断一下trx_id属性值是不是在 trx_ids 列表中。
  * 如果在，说明创建ReadView时生成该版本的事务还是活跃的，该版本不可以被访问。 
  * 如果不在，说明创建ReadView时生成该版本的事务已经被提交，该版本可以被访问。

### 4.4 MVCC整体操作流程

了解了这些概念之后，我们来看下当查询一条记录的时候，系统如何通过MVCC找到它：

1. 首先获取事务自己的版本号，也就是事务 ID； 
2. 获取 ReadView； 
3. 查询得到的数据，然后与 ReadView 中的事务版本号进行比较；
4. 如果不符合 ReadView 规则，就需要从 Undo Log 中获取历史快照； 
5. 最后返回符合规则的数据。

<img src="MySQL事物篇.assets/image-20220715130639408.png" alt="image-20220715130639408" style="float:left;" />

在隔离级别为读已提交（Read Committed）时，一个事务中的每一次 SELECT 查询都会重新获取一次 Read View。

如表所示：

![image-20220715130843147](MySQL事物篇.assets/image-20220715130843147.png)

> 注意，此时同样的查询语句都会重新获取一次 Read View，这时如果 Read View 不同，就可能产生不可重复读或者幻读的情况。

当隔离级别为可重复读的时候，就避免了不可重复读，这是因为一个事务只在第一次 SELECT 的时候会获取一次 Read View，而后面所有的 SELECT 都会复用这个 Read View，如下表所示：

![image-20220715130916437](MySQL事物篇.assets/image-20220715130916437.png)

## 5. 举例说明

<img src="MySQL事物篇.assets/image-20220715131200077.png" alt="image-20220715131200077" style="float:left;" />

### 5.1 READ COMMITTED隔离级别下

**READ COMMITTED ：每次读取数据前都生成一个ReadView。**

现在有两个 `事务id` 分别为 `10` 、 `20` 的事务在执行:

```mysql
# Transaction 10
BEGIN;
UPDATE student SET name="李四" WHERE id=1;
UPDATE student SET name="王五" WHERE id=1;
# Transaction 20
BEGIN;
# 更新了一些别的表的记录
...
```

> 说明：事务执行过程中，只有在第一次真正修改记录时（比如使用INSERT、DELETE、UPDATE语句），才会被分配一个单独的事务id，这个事务id是递增的。所以我们才在事务2中更新一些别的表的记录，目的是让它分配事务id。

此刻，表student 中 id 为 1 的记录得到的版本链表如下所示：

![image-20220715133640655](MySQL事物篇.assets/image-20220715133640655.png)

假设现在有一个使用 `READ COMMITTED` 隔离级别的事务开始执行：

```mysql
# 使用READ COMMITTED隔离级别的事务
BEGIN;

# SELECT1：Transaction 10、20未提交
SELECT * FROM student WHERE id = 1; # 得到的列name的值为'张三'
```

<img src="MySQL事物篇.assets/image-20220715134540737.png" alt="image-20220715134540737" style="float:left;" />

之后，我们把 `事务id` 为 `10` 的事务提交一下：

```mysql
# Transaction 10
BEGIN;
UPDATE student SET name="李四" WHERE id=1;
UPDATE student SET name="王五" WHERE id=1;
COMMIT;
```

然后再到 `事务id` 为 `20` 的事务中更新一下表 `student` 中 `id` 为 `1` 的记录：

```mysql
# Transaction 20
BEGIN;
# 更新了一些别的表的记录
...
UPDATE student SET name="钱七" WHERE id=1;
UPDATE student SET name="宋八" WHERE id=1;
```

此刻，表student中 `id` 为 `1` 的记录的版本链就长这样：

![image-20220715134839081](MySQL事物篇.assets/image-20220715134839081.png)

然后再到刚才使用 `READ COMMITTED` 隔离级别的事务中继续查找这个 id 为 1 的记录，如下：

```mysql
# 使用READ COMMITTED隔离级别的事务
BEGIN;

# SELECT1：Transaction 10、20均未提交
SELECT * FROM student WHERE id = 1; # 得到的列name的值为'张三'

# SELECT2：Transaction 10提交，Transaction 20未提交
SELECT * FROM student WHERE id = 1; # 得到的列name的值为'王五'
```

<img src="MySQL事物篇.assets/image-20220715135017000.png" alt="image-20220715135017000" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220715135143939.png" alt="image-20220715135143939" style="float:left;" />

### 5.2 REPEATABLE READ隔离级别下

使用 `REPEATABLE READ` 隔离级别的事务来说，只会在第一次执行查询语句时生成一个 `ReadView` ，之后的查询就不会重复生成了。

比如，系统里有两个 `事务id` 分别为 `10` 、 `20` 的事务在执行：

```mysql
# Transaction 10
BEGIN;
UPDATE student SET name="李四" WHERE id=1;
UPDATE student SET name="王五" WHERE id=1;
# Transaction 20
BEGIN;
# 更新了一些别的表的记录
...
```

此刻，表student 中 id 为 1 的记录得到的版本链表如下所示：

![image-20220715140006061](MySQL事物篇.assets/image-20220715140006061.png)

假设现在有一个使用 `REPEATABLE READ` 隔离级别的事务开始执行：

```mysql
# 使用REPEATABLE READ隔离级别的事务
BEGIN;

# SELECT1：Transaction 10、20未提交
SELECT * FROM student WHERE id = 1; # 得到的列name的值为'张三'
```

<img src="MySQL事物篇.assets/image-20220715140155744.png" alt="image-20220715140155744" style="float:left;" />

之后，我们把 `事务id` 为 `10` 的事务提交一下，就像这样：

```mysql
# Transaction 10
BEGIN;

UPDATE student SET name="李四" WHERE id=1;
UPDATE student SET name="王五" WHERE id=1;

COMMIT;
```

然后再到 `事务id` 为 `20` 的事务中更新一下表 `student` 中 `id` 为 `1` 的记录：

```mysql
# Transaction 20
BEGIN;
# 更新了一些别的表的记录
...
UPDATE student SET name="钱七" WHERE id=1;
UPDATE student SET name="宋八" WHERE id=1;
```

此刻，表student 中 `id` 为 `1` 的记录的版本链长这样：

![image-20220715140354217](MySQL事物篇.assets/image-20220715140354217.png)

然后再到刚才使用 `REPEATABLE READ` 隔离级别的事务中继续查找这个 `id` 为 `1` 的记录，如下：

```mysql
# 使用REPEATABLE READ隔离级别的事务
BEGIN;
# SELECT1：Transaction 10、20均未提交
SELECT * FROM student WHERE id = 1; # 得到的列name的值为'张三'
# SELECT2：Transaction 10提交，Transaction 20未提交
SELECT * FROM student WHERE id = 1; # 得到的列name的值仍为'张三'
```

<img src="MySQL事物篇.assets/image-20220715140555172.png" alt="image-20220715140555172" style="float:left;" />

<img src="MySQL事物篇.assets/image-20220715140620328.png" alt="image-20220715140620328" style="float:left;" />

这次`SELECT`查询得到的结果是重复的，记录的列`c`值都是`张三`，这就是`可重复读`的含义。如果我们之后再把`事务id`为`20`的记录提交了，然后再到刚才使用`REPEATABLE READ`隔离级别的事务中继续查找这个`id`为`1`的记录，得到的结果还是`张三`，具体执行过程大家可以自己分析一下。

### 5.3 如何解决幻读

接下来说明InnoDB 是如何解决幻读的。

假设现在表 student 中只有一条数据，数据内容中，主键 id=1，隐藏的 trx_id=10，它的 undo log 如下图所示。

<img src="MySQL事物篇.assets/image-20220715141002035.png" alt="image-20220715141002035" style="zoom:80%;" />

假设现在有事务 A 和事务 B 并发执行，`事务 A` 的事务 id 为 `20` ， `事务 B` 的事务 id 为 `30` 。

步骤1：事务 A 开始第一次查询数据，查询的 SQL 语句如下。

```mysql
select * from student where id >= 1;
```

在开始查询之前，MySQL 会为事务 A 产生一个 ReadView，此时 ReadView 的内容如下： `trx_ids= [20,30] ， up_limit_id=20 ， low_limit_id=31 ， creator_trx_id=20` 。

由于此时表 student 中只有一条数据，且符合 where id>=1 条件，因此会查询出来。然后根据 ReadView 机制，发现该行数据的trx_id=10，小于事务 A 的 ReadView 里 up_limit_id，这表示这条数据是事务 A 开启之前，其他事务就已经提交了的数据，因此事务 A 可以读取到。

结论：事务 A 的第一次查询，能读取到一条数据，id=1。

步骤2：接着事务 B(trx_id=30)，往表 student 中新插入两条数据，并提交事务。

```mysql
insert into student(id,name) values(2,'李四');
insert into student(id,name) values(3,'王五');
```

此时表student 中就有三条数据了，对应的 undo 如下图所示：

![image-20220715141208667](MySQL事物篇.assets/image-20220715141208667.png)

步骤3：接着事务 A 开启第二次查询，根据可重复读隔离级别的规则，此时事务 A 并不会再重新生成 ReadView。此时表 student 中的 3 条数据都满足 where id>=1 的条件，因此会先查出来。然后根据 ReadView 机制，判断每条数据是不是都可以被事务 A 看到。

1）首先 id=1 的这条数据，前面已经说过了，可以被事务 A 看到。 

2）然后是 id=2 的数据，它的 trx_id=30，此时事务 A 发现，这个值处于 up_limit_id 和 low_limit_id 之 间，因此还需要再判断 30 是否处于 trx_ids 数组内。由于事务 A 的 trx_ids=[20,30]，因此在数组内，这表 示 id=2 的这条数据是与事务 A 在同一时刻启动的其他事务提交的，所以这条数据不能让事务 A 看到。

3）同理，id=3 的这条数据，trx_id 也为 30，因此也不能被事务 A 看见。

![image-20220715141243993](MySQL事物篇.assets/image-20220715141243993.png)

结论：最终事务 A 的第二次查询，只能查询出 id=1 的这条数据。这和事务 A 的第一次查询的结果是一样 的，因此没有出现幻读现象，所以说在 MySQL 的可重复读隔离级别下，不存在幻读问题。

## 6. 总结

这里介绍了 MVCC 在 `READ COMMITTD` 、 `REPEATABLE READ` 这两种隔离级别的事务在执行快照读操作时 访问记录的版本链的过程。这样使不同事务的 `读-写` 、 `写-读` 操作并发执行，从而提升系统性能。

核心点在于 ReadView 的原理， `READ COMMITTD` 、 `REPEATABLE READ` 这两个隔离级别的一个很大不同 就是生成ReadView的时机不同：

* `READ COMMITTD` 在每一次进行普通SELECT操作前都会生成一个ReadView 
* `REPEATABLE READ` 只在第一次进行普通SELECT操作前生成一个ReadView，之后的查询操作都重复 使用这个ReadView就好了。

<img src="MySQL事物篇.assets/image-20220715141413135.png" alt="image-20220715141413135" style="float:left;" />

通过MVCC我们可以解决：

<img src="MySQL事物篇.assets/image-20220715141515370.png" alt="image-20220715141515370" style="float:left;" />
