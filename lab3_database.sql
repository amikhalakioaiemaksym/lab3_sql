SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE credit_bank_lab2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE credit_bank_lab2;

CREATE TABLE ownership_type (
    ownership_type_id INT AUTO_INCREMENT PRIMARY KEY,
    name              VARCHAR(100) NOT NULL UNIQUE
) ENGINE = InnoDB;

CREATE TABLE client (
    client_id           INT AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(200) NOT NULL,
    ownership_type_id   INT          NOT NULL,
    address             VARCHAR(255) NOT NULL,
    phone               VARCHAR(20)  NULL    ,
    contact_last_name   VARCHAR(60)  NULL    ,
    contact_first_name  VARCHAR(60)  NULL    ,
    contact_middle_name VARCHAR(60)  NULL,
    CHECK ((contact_last_name IS NULL) = (contact_first_name IS NULL)),
    FOREIGN KEY (ownership_type_id)
        REFERENCES ownership_type (ownership_type_id)
) ENGINE = InnoDB;

CREATE TABLE credit_type (
    credit_type_id INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100) NOT NULL UNIQUE,
    conditions     TEXT         NOT NULL,
    annual_rate    DECIMAL(5,2) NOT NULL,
    term_days      INT          NOT NULL,
    penalty_rate   DECIMAL(5,3) NOT NULL, 
    CHECK (annual_rate >= 0),
    CHECK (term_days > 0),
    CHECK (penalty_rate >= 0)
) ENGINE = InnoDB;

CREATE TABLE credit (
    credit_id      INT AUTO_INCREMENT PRIMARY KEY,
    client_id      INT           NOT NULL,
    credit_type_id INT           NOT NULL,
    amount         DECIMAL(15,2) NOT NULL,
    issue_date     DATE          NOT NULL,
    CHECK (amount > 0),
    FOREIGN KEY (client_id)      REFERENCES client (client_id),
    FOREIGN KEY (credit_type_id) REFERENCES credit_type (credit_type_id)
) ENGINE = InnoDB;

CREATE TABLE repayment (
    credit_id      INT           NOT NULL,
    payment_no     INT           NOT NULL,
    payment_date   DATE          NOT NULL,
    payment_amount DECIMAL(15,2) NOT NULL,
    penalty_amount DECIMAL(15,2) NOT NULL DEFAULT 0, 
    PRIMARY KEY (credit_id, payment_no),
    CHECK (payment_no > 0),
    CHECK (payment_amount > 0),
    CHECK (penalty_amount >= 0),
    FOREIGN KEY (credit_id) REFERENCES credit (credit_id)
) ENGINE = InnoDB;


DELIMITER //

CREATE TRIGGER trg_repayment_before_insert
BEFORE INSERT ON repayment
FOR EACH ROW
BEGIN
    DECLARE v_amount       DECIMAL(15,2);
    DECLARE v_issue_date   DATE;
    DECLARE v_term_days    INT;
    DECLARE v_penalty_rate DECIMAL(5,3);
    DECLARE v_paid         DECIMAL(15,2);
    DECLARE v_days_late    INT;

    SELECT c.amount, c.issue_date, t.term_days, t.penalty_rate
      INTO v_amount, v_issue_date, v_term_days, v_penalty_rate
      FROM credit c
      JOIN credit_type t ON t.credit_type_id = c.credit_type_id
     WHERE c.credit_id = NEW.credit_id;

    IF NEW.payment_date < v_issue_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Дата платежу раніша за дату видачі кредиту';
    END IF;

    SELECT COALESCE(SUM(payment_amount), 0)
      INTO v_paid
      FROM repayment
     WHERE credit_id = NEW.credit_id;

    IF v_paid + NEW.payment_amount > v_amount THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Платіж перевищує залишок боргу';
    END IF;

    SET v_days_late = GREATEST(
        DATEDIFF(NEW.payment_date,
                 DATE_ADD(v_issue_date, INTERVAL v_term_days DAY)),
        0);

    SET NEW.penalty_amount = ROUND(
        NEW.payment_amount * v_penalty_rate / 100 * v_days_late, 2);
END//

DELIMITER ;

INSERT INTO ownership_type (ownership_type_id, name) VALUES
(1,'ТОВ'), (2,'ПАТ'), (3,'ТДВ'), (4,'ПрАТ'), (5,'ДП'), (6,'ПП');

INSERT INTO client (client_id, name, ownership_type_id, address, phone,
    contact_last_name, contact_first_name, contact_middle_name) VALUES
(1,'Агро-Приклад',1,'м. Прикладне, вул. Садова, 1','+000000000001','Іваненко','Петро','Олегович'),
(2,'Зразок-Транс',5,'м. Прикладне, вул. Лісова, 7','+000000000002','Коваль','Ірина','Василівна'),
(3,'Тест-Буд',2,'м. Прикладне, вул. Польова, 3',NULL,'Мельник','Андрій',NULL),
(4,'Агросвіт-Тест',3,'м. Прикладне, вул. Шкільна, 12','+000000000004',NULL,NULL,NULL),
(5,'Демо-Маркет',1,'м. Прикладне, вул. Нова, 5',NULL,NULL,NULL,NULL),
(6,'Агротехніка-Зразок',4,'м. Прикладне, вул. Зелена, 8','+000000000006','Бондар','Олена','Ігорівна'),
(7,'Умовний Млин',6,'м. Прикладне, вул. Річкова, 2','+000000000007','Шевчук','Максим','Юрійович'),
(8,'Приклад-Енерго',2,'м. Прикладне, вул. Заводська, 20','+000000000008','Ткаченко','Марія','Сергіївна');

INSERT INTO credit_type (credit_type_id, name, conditions, annual_rate, term_days, penalty_rate) VALUES
( 1,'Короткостроковий','Фінансовий звіт за квартал',18.00,  90,0.200),
( 2,'Оборотний','Застава товарів в обороті',16.00, 180,0.100),
( 3,'Інвестиційний','Бізнес-план і застава майна',14.00, 365,0.050),
( 4,'Овердрафт','Регулярні обороти за рахунком',22.00,  30,0.300),
( 5,'Лізинговий','Договір лізингу',15.00, 730,0.050),
( 6,'Сезонний','Підтвердження сезонності робіт',16.00, 270,0.100),
( 7,'Експортний','Експортний контракт',12.00, 180,0.100),
( 8,'Будівельний','Проєктна документація',17.00, 540,0.080),
( 9,'Аграрний','Договір страхування врожаю',13.00, 300,0.070),
(10,'Експрес','Спрощений пакет документів',24.00,  60,0.400),
(11,'Енергоефективний','Енергетичний аудит',11.00, 720,0.040),
(12,'Тендерний','Участь у тендері',18.00, 120,0.150),
(13,'Стартовий','Бізнес-план і порука',19.00, 365,0.100),
(14,'Іпотечний','Іпотека нерухомості',13.00,1825,0.030);   -- видач немає

INSERT INTO credit (credit_id, client_id, credit_type_id, amount, issue_date) VALUES
( 1,1, 2, 100000.00,'2026-03-01'),
( 2,2, 3, 500000.00,'2026-04-10'),
( 3,3, 1,  60000.00,'2026-05-01'),
( 4,4, 7, 750000.00,'2026-02-15'),
( 5,5,10,  40000.00,'2026-06-01'),
( 6,6, 9,1500000.00,'2026-03-20'),
( 7,7, 5, 900000.00,'2025-12-01'),
( 8,8,11,2500000.00,'2026-01-15'),
( 9,1, 8,1200000.00,'2026-07-01'),
(10,2,13,  80000.00,'2026-08-01');

INSERT INTO credit (credit_id, client_id, credit_type_id, amount, issue_date) VALUES
(11,3, 4,  50000.00, DATE_SUB(CURDATE(), INTERVAL  25 DAY)),  -- через 5 днів
(12,4,12, 300000.00, DATE_SUB(CURDATE(), INTERVAL 108 DAY)),  -- через 12 днів
(13,6, 6, 450000.00, DATE_SUB(CURDATE(), INTERVAL 250 DAY)),  -- через 20 днів
(14,8, 1,  95000.00, DATE_SUB(CURDATE(), INTERVAL  62 DAY)),  -- через 28 днів
(15,1, 2, 100000.00, DATE_SUB(CURDATE(), INTERVAL 135 DAY));  -- через 45 днів

INSERT INTO repayment (credit_id, payment_no, payment_date, payment_amount) VALUES
(1,1,'2026-06-01', 40000.00),
(1,2,'2026-08-28', 35000.00),
(1,3,'2026-09-07', 25000.00),
(2,1,'2026-10-10',120000.00),
(3,1,'2026-07-15', 20000.00),
(4,1,'2026-08-10',750000.00),
(5,1,'2026-08-10', 40000.00),
(6,1,'2026-09-15',500000.00),
(7,1,'2026-06-01',200000.00),
(8,1,'2026-07-15',300000.00);

INSERT INTO repayment (credit_id, payment_no, payment_date, payment_amount) VALUES
(13,1, DATE_SUB(CURDATE(), INTERVAL 30 DAY), 150000.00);
