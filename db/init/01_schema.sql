-- Enable necessary PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- 1. MASTER EMPLOYEE DIRECTORY
-- ============================================================================
CREATE TABLE IF NOT EXISTS employees (
    employee_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_code          VARCHAR(64) UNIQUE NOT NULL,       -- e.g., 'T27689'
    national_id_hash    CHAR(64),                          -- SHA-256 hash
    full_name           VARCHAR(200) NOT NULL,             -- e.g., 'James Mark'
    department          VARCHAR(128),
    job_title           VARCHAR(128),
    is_pep              BOOLEAN DEFAULT FALSE,
    employment_status   VARCHAR(32) DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 2. DECLARATION FILINGS & AUDIT LIFECYCLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS declaration_filings (
    filing_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id         UUID NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    filing_year         SMALLINT NOT NULL,
    filing_date         DATE NOT NULL,                     -- e.g., '2026-08-28'
    form_title          VARCHAR(255) DEFAULT 'JN Group Confidential Statement of Affairs',
    approval_status     VARCHAR(32) DEFAULT 'COMPLETED',   -- COMPLETED, PENDING, FLAGGED
    calculated_total    NUMERIC(18, 2),                    -- Auto-calculated total from audit (e.g., 21750945.76)
    notification_email  VARCHAR(255),                      -- e.g., 'dennish@jngroup.com'
    source_pdf_filename VARCHAR(255) NOT NULL,
    source_pdf_sha256   CHAR(64) NOT NULL,
    parsed_at           TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_employee_year_date UNIQUE (employee_id, filing_year, filing_date)
);

-- ============================================================================
-- 3. SUMMARY BALANCE SHEET (Form Level Summary)
-- ============================================================================
CREATE TABLE IF NOT EXISTS declaration_summaries (
    summary_id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filing_id                   UUID UNIQUE NOT NULL REFERENCES declaration_filings(filing_id) ON DELETE CASCADE,
    currency                    CHAR(3) DEFAULT 'JMD',
    
    -- Summary Asset Fields (in JMD)
    real_estate_val             NUMERIC(15, 2) DEFAULT 0.00,
    motor_vehicles_val          NUMERIC(15, 2) DEFAULT 0.00,
    furniture_equipment_val     NUMERIC(15, 2) DEFAULT 0.00,
    life_insurance_cash_val     NUMERIC(15, 2) DEFAULT 0.00,
    other_non_cash_assets_val   NUMERIC(15, 2) DEFAULT 0.00,
    amounts_owed_to_you         NUMERIC(15, 2) DEFAULT 0.00,
    savings_deposits_jmd        NUMERIC(15, 2) DEFAULT 0.00,
    savings_deposits_foreign    NUMERIC(15, 2) DEFAULT 0.00, -- USD/GBP/EUR converted or tracked
    other_accounts_val          NUMERIC(15, 2) DEFAULT 0.00,
    other_investments_val       NUMERIC(15, 2) DEFAULT 0.00,
    
    -- Summary Liability Fields (in JMD)
    loans_on_real_estate        NUMERIC(15, 2) DEFAULT 0.00,
    loans_on_motor_vehicles     NUMERIC(15, 2) DEFAULT 0.00,
    loans_on_furniture_equip    NUMERIC(15, 2) DEFAULT 0.00,
    overdraft_current_account   NUMERIC(15, 2) DEFAULT 0.00,
    other_loans_payable         NUMERIC(15, 2) DEFAULT 0.00,
    other_liabilities           NUMERIC(15, 2) DEFAULT 0.00,
    
    source_pdf_page             SMALLINT DEFAULT 1
);

-- ============================================================================
-- 4. MONTHLY CASH FLOW (Inflows & Outflows)
-- ============================================================================
CREATE TABLE IF NOT EXISTS monthly_cash_flows (
    cash_flow_id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filing_id                   UUID UNIQUE NOT NULL REFERENCES declaration_filings(filing_id) ON DELETE CASCADE,
    currency                    CHAR(3) DEFAULT 'JMD',
    
    -- Inflows
    monthly_employed_net_income NUMERIC(15, 2) DEFAULT 0.00,
    monthly_other_income        NUMERIC(15, 2) DEFAULT 0.00, -- Rent, side business
    
    -- Outflows
    outflow_utilities           NUMERIC(15, 2) DEFAULT 0.00, -- Light, water, cable
    outflow_transportation      NUMERIC(15, 2) DEFAULT 0.00, -- Gas, maintenance
    outflow_living_expenses     NUMERIC(15, 2) DEFAULT 0.00, -- Food, medical, school
    outflow_property_costs      NUMERIC(15, 2) DEFAULT 0.00, -- Rent, maintenance
    outflow_statutory_deduct    NUMERIC(15, 2) DEFAULT 0.00, -- Income Tax, NHT, etc.
    
    source_pdf_page             SMALLINT DEFAULT 2
);

-- ============================================================================
-- 5. DETAILED ASSET & LIABILITY SCHEDULES
-- ============================================================================

-- Detailed Motor Vehicles Schedule
CREATE TABLE IF NOT EXISTS schedule_motor_vehicles (
    vehicle_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filing_id           UUID NOT NULL REFERENCES declaration_filings(filing_id) ON DELETE CASCADE,
    make_and_type       VARCHAR(128) NOT NULL,             -- e.g., 'Toyota/Rav4'
    year_and_model      VARCHAR(128),                      -- e.g., '2026/Standard'
    estimated_val       NUMERIC(15, 2) NOT NULL,
    loan_balance        NUMERIC(15, 2) DEFAULT 0.00,
    monthly_payment     NUMERIC(15, 2) DEFAULT 0.00,
    currency            CHAR(3) DEFAULT 'JMD',
    source_pdf_page     SMALLINT DEFAULT 2
);

-- Detailed Real Estate Holdings Schedule
CREATE TABLE IF NOT EXISTS schedule_real_estate (
    property_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filing_id           UUID NOT NULL REFERENCES declaration_filings(filing_id) ON DELETE CASCADE,
    property_address    TEXT NOT NULL,                     -- e.g., '85 Knutsford Crescent'
    valuation           NUMERIC(15, 2) NOT NULL,
    existing_loan_bal   NUMERIC(15, 2) DEFAULT 0.00,
    monthly_payment     NUMERIC(15, 2) DEFAULT 0.00,
    account_number      VARCHAR(128),                      -- e.g., '35245245'
    lender_name         VARCHAR(255),                      -- e.g., 'JN BANK'
    currency            CHAR(3) DEFAULT 'JMD',
    source_pdf_page     SMALLINT DEFAULT 2
);

-- Detailed Outside Business Interests & Shareholdings
CREATE TABLE IF NOT EXISTS outside_business_interests (
    interest_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filing_id           UUID NOT NULL REFERENCES declaration_filings(filing_id) ON DELETE CASCADE,
    business_name       VARCHAR(255) NOT NULL,             -- e.g., 'Next Incorporate Ltd'
    shareholder_pct     NUMERIC(5, 2) NOT NULL,            -- e.g., 35.00
    is_vendor_conflict  BOOLEAN DEFAULT FALSE,
    source_pdf_page     SMALLINT DEFAULT 2
);

-- Detailed Other Non-Cash Assets & Investments
CREATE TABLE IF NOT EXISTS schedule_investments (
    investment_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filing_id           UUID NOT NULL REFERENCES declaration_filings(filing_id) ON DELETE CASCADE,
    description         TEXT NOT NULL,                     -- e.g., 'Stocks'
    estimated_val       NUMERIC(15, 2) NOT NULL,
    currency            CHAR(3) DEFAULT 'JMD',
    source_pdf_page     SMALLINT DEFAULT 2
);

-- ============================================================================
-- 6. PERFORMANCE & COVERING INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_filings_emp_year_cover 
    ON declaration_filings(employee_id, filing_year DESC) 
    INCLUDE (filing_id, source_pdf_filename);

CREATE INDEX IF NOT EXISTS idx_summaries_filing 
    ON declaration_summaries(filing_id);

CREATE INDEX IF NOT EXISTS idx_cash_flows_filing 
    ON monthly_cash_flows(filing_id);

CREATE INDEX IF NOT EXISTS idx_re_lender_trgm 
    ON schedule_real_estate USING gin (lender_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_business_name_trgm 
    ON outside_business_interests USING gin (business_name gin_trgm_ops);