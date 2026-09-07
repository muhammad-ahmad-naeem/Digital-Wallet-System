DROP DATABASE IF EXISTS fintech_ledger_db;
CREATE DATABASE fintech_ledger_db;
USE fintech_ledger_db;

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    kyc_status ENUM('Pending', 'Verified', 'Rejected') DEFAULT 'Pending',
    risk_score INT DEFAULT 10,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE account_types (
    type_id INT AUTO_INCREMENT PRIMARY KEY,
    name ENUM('Asset', 'Liability', 'Equity', 'Revenue', 'Expense') NOT NULL,
    normal_balance ENUM('Debit', 'Credit') NOT NULL,
    description VARCHAR(255)
);

CREATE TABLE accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    account_number VARCHAR(34) UNIQUE NOT NULL,
    user_id INT NULL,
    type_id INT NOT NULL,
    currency CHAR(3) DEFAULT 'USD',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (type_id) REFERENCES account_types(type_id)
);

CREATE TABLE transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_ref VARCHAR(64) UNIQUE NOT NULL,
    type ENUM('Deposit', 'Transfer', 'Withdrawal', 'Fee', 'Settlement') NOT NULL,
    status ENUM('Pending', 'Posted', 'Failed') DEFAULT 'Posted',
    description VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE journal_entries (
    entry_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT NOT NULL,
    account_id INT NOT NULL,
    entry_direction ENUM('Debit', 'Credit') NOT NULL,
    amount DECIMAL(14, 4) NOT NULL,
    posted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_positive_amount CHECK (amount > 0)
);

CREATE TABLE fraud_alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    transaction_id INT NOT NULL,
    reason VARCHAR(255) NOT NULL,
    severity ENUM('Low', 'Medium', 'High') DEFAULT 'Medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
);

INSERT INTO account_types (name, normal_balance, description) VALUES
('Asset', 'Debit', 'External bank settlement accounts and cash reserves'),
('Liability', 'Credit', 'User wallet balances held by platform'),
('Revenue', 'Credit', 'Interchange and transaction processing fee income'),
('Expense', 'Debit', 'Operational, payout, and gateway costs');

INSERT INTO users (full_name, email, kyc_status, risk_score) VALUES
('System Treasury', 'ops@platform.local', 'Verified', 0),
('Ahmad Jamal', 'ahmad.jamal@gmail.com', 'Verified', 12),
('Sarah Jenkins', 'sarah.j@techcorp.io', 'Verified', 5),
('Apex Merchant Services', 'finance@apexms.com', 'Verified', 8),
('Danyal Khan', 'danyal.k@outlook.com', 'Pending', 45);

INSERT INTO accounts (account_number, user_id, type_id, currency) VALUES
('ACC-SYSTEM-CASH-001', 1, 1, 'USD'),
('ACC-SYSTEM-FEE-REV-001', 1, 3, 'USD'),
('ACC-WAL-AHMAD-101', 2, 2, 'USD'),
('ACC-WAL-SARAH-102', 3, 2, 'USD'),
('ACC-WAL-APEX-103', 4, 2, 'USD'),
('ACC-WAL-DANYAL-104', 5, 2, 'USD');

START TRANSACTION;
INSERT INTO transactions (transaction_ref, type, status, description)
VALUES ('TX-DEP-20260901-01', 'Deposit', 'Posted', 'Card top-up: Ahmad wallet funded');

INSERT INTO journal_entries (transaction_id, account_id, entry_direction, amount) VALUES
(1, 1, 'Debit', 2500.0000),
(1, 3, 'Credit', 2500.0000);
COMMIT;

START TRANSACTION;
INSERT INTO transactions (transaction_ref, type, status, description)
VALUES ('TX-DEP-20260901-02', 'Deposit', 'Posted', 'Wire transfer: Sarah wallet funded');

INSERT INTO journal_entries (transaction_id, account_id, entry_direction, amount) VALUES
(2, 1, 'Debit', 4200.0000),
(2, 4, 'Credit', 4200.0000);
COMMIT;

START TRANSACTION;
INSERT INTO transactions (transaction_ref, type, status, description)
VALUES ('TX-P2P-20260902-01', 'Transfer', 'Posted', 'Peer-to-peer transfer: Ahmad to Sarah');

INSERT INTO journal_entries (transaction_id, account_id, entry_direction, amount) VALUES
(3, 3, 'Debit', 350.0000),
(3, 4, 'Credit', 350.0000);
COMMIT;

START TRANSACTION;
INSERT INTO transactions (transaction_ref, type, status, description)
VALUES ('TX-PUR-20260903-01', 'Transfer', 'Posted', 'Checkout: Sarah buys hardware with 2% platform fee');

INSERT INTO journal_entries (transaction_id, account_id, entry_direction, amount) VALUES
(4, 4, 'Debit', 1000.0000),
(4, 5, 'Credit', 980.0000),
(4, 2, 'Credit', 20.0000);
COMMIT;

START TRANSACTION;
INSERT INTO transactions (transaction_ref, type, status, description)
VALUES ('TX-WDR-20260904-01', 'Withdrawal', 'Posted', 'Merchant cashout: Apex payout to local bank');

INSERT INTO journal_entries (transaction_id, account_id, entry_direction, amount) VALUES
(5, 5, 'Debit', 500.0000),
(5, 1, 'Credit', 500.0000);
COMMIT;

INSERT INTO fraud_alerts (user_id, transaction_id, reason, severity) VALUES
(5, 4, 'Transaction initiated without fully cleared Tier-2 KYC verification', 'Medium');

SELECT 
    t.transaction_ref,
    t.type,
    SUM(CASE WHEN je.entry_direction = 'Debit' THEN je.amount ELSE 0 END) AS total_debits,
    SUM(CASE WHEN je.entry_direction = 'Credit' THEN je.amount ELSE 0 END) AS total_credits,
    (SUM(CASE WHEN je.entry_direction = 'Debit' THEN je.amount ELSE 0 END) - 
     SUM(CASE WHEN je.entry_direction = 'Credit' THEN je.amount ELSE 0 END)) AS ledger_imbalance,
    CASE 
        WHEN SUM(CASE WHEN je.entry_direction = 'Debit' THEN je.amount ELSE 0 END) = 
             SUM(CASE WHEN je.entry_direction = 'Credit' THEN je.amount ELSE 0 END) 
        THEN 'BALANCED' 
        ELSE 'RECONCILIATION_FAILED' 
    END AS audit_status
FROM transactions t
JOIN journal_entries je ON t.transaction_id = je.transaction_id
GROUP BY t.transaction_id, t.transaction_ref, t.type;

SELECT 
    a.account_id,
    a.account_number,
    COALESCE(u.full_name, 'Platform Treasury') AS account_holder,
    at.name AS account_type,
    at.normal_balance,
    ROUND(
        CASE 
            WHEN at.normal_balance = 'Debit' THEN
                COALESCE(SUM(CASE WHEN je.entry_direction = 'Debit' THEN je.amount ELSE -je.amount END), 0)
            ELSE
                COALESCE(SUM(CASE WHEN je.entry_direction = 'Credit' THEN je.amount ELSE -je.amount END), 0)
        END, 2
    ) AS real_time_balance
FROM accounts a
JOIN account_types at ON a.type_id = at.type_id
LEFT JOIN users u ON a.user_id = u.user_id
LEFT JOIN journal_entries je ON a.account_id = je.account_id
GROUP BY a.account_id, a.account_number, u.full_name, at.name, at.normal_balance
ORDER BY a.account_id ASC;

SELECT 
    t.transaction_ref,
    t.created_at,
    t.description,
    u.full_name AS counterparty,
    a.account_number,
    je.entry_direction,
    je.amount,
    SUM(
        CASE 
            WHEN at.normal_balance = 'Credit' AND je.entry_direction = 'Credit' THEN je.amount
            WHEN at.normal_balance = 'Credit' AND je.entry_direction = 'Debit' THEN -je.amount
            WHEN at.normal_balance = 'Debit' AND je.entry_direction = 'Debit' THEN je.amount
            ELSE -je.amount
        END
    ) OVER (
        PARTITION BY je.account_id 
        ORDER BY je.entry_id ASC
    ) AS rolling_balance_after_event
FROM journal_entries je
JOIN transactions t ON je.transaction_id = t.transaction_id
JOIN accounts a ON je.account_id = a.account_id
JOIN account_types at ON a.type_id = at.type_id
JOIN users u ON a.user_id = u.user_id
ORDER BY a.account_id, je.entry_id ASC;

SELECT 
    COUNT(DISTINCT t.transaction_id) AS total_processed_transactions,
    SUM(CASE WHEN t.type = 'Transfer' THEN je.amount ELSE 0 END) / 2 AS total_p2p_volume,
    SUM(CASE WHEN a.account_number = 'ACC-SYSTEM-FEE-REV-001' AND je.entry_direction = 'Credit' THEN je.amount ELSE 0 END) AS platform_revenue_earned,
    SUM(CASE WHEN at.name = 'Asset' AND je.entry_direction = 'Debit' THEN je.amount 
             WHEN at.name = 'Asset' AND je.entry_direction = 'Credit' THEN -je.amount ELSE 0 END) AS cash_in_custody
FROM transactions t
JOIN journal_entries je ON t.transaction_id = je.transaction_id
JOIN accounts a ON je.account_id = a.account_id
JOIN account_types at ON a.type_id = at.type_id;