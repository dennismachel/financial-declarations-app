CREATE OR REPLACE VIEW view_employee_annual_wealth_deltas AS
WITH filing_base AS (
    SELECT 
        df.filing_id,
        df.employee_id,
        df.filing_year,
        df.filing_date,
        df.approval_status,
        df.source_pdf_filename,
        e.staff_code,
        e.full_name AS employee_name,
        e.department,
        e.job_title,
        e.is_pep,

        -- Aggregated Asset Totals from Summary
        (
            s.real_estate_val + 
            s.motor_vehicles_val + 
            s.furniture_equipment_val + 
            s.life_insurance_cash_val + 
            s.other_non_cash_assets_val + 
            s.amounts_owed_to_you + 
            s.savings_deposits_jmd + 
            s.savings_deposits_foreign + 
            s.other_accounts_val + 
            s.other_investments_val
        ) AS total_assets_jmd,

        -- Aggregated Liability Totals from Summary
        (
            s.loans_on_real_estate + 
            s.loans_on_motor_vehicles + 
            s.loans_on_furniture_equip + 
            s.overdraft_current_account + 
            s.other_loans_payable + 
            s.other_liabilities
        ) AS total_liabilities_jmd,

        -- Monthly Cash Flow Dynamics
        cf.monthly_employed_net_income,
        cf.monthly_other_income,
        (cf.monthly_employed_net_income + cf.monthly_other_income) AS total_monthly_inflow,
        (
            cf.outflow_utilities + 
            cf.outflow_transportation + 
            cf.outflow_living_expenses + 
            cf.outflow_property_costs + 
            cf.outflow_statutory_deduct
        ) AS total_monthly_outflow,

        -- Annualized Net Savings Capacity
        (
            (cf.monthly_employed_net_income + cf.monthly_other_income) - 
            (cf.outflow_utilities + cf.outflow_transportation + cf.outflow_living_expenses + cf.outflow_property_costs + cf.outflow_statutory_deduct)
        ) * 12.0 AS annualized_net_savings_capacity

    FROM declaration_filings df
    JOIN employees e ON df.employee_id = e.employee_id
    LEFT JOIN declaration_summaries s ON df.filing_id = s.filing_id
    LEFT JOIN monthly_cash_flows cf ON df.filing_id = cf.filing_id
),
wealth_calc AS (
    SELECT 
        *,
        (total_assets_jmd - total_liabilities_jmd) AS net_wealth_jmd
    FROM filing_base
),
trend_computation AS (
    SELECT 
        *,
        LAG(net_wealth_jmd) OVER (PARTITION BY employee_id ORDER BY filing_date ASC) AS prior_net_wealth_jmd,
        LAG(filing_year) OVER (PARTITION BY employee_id ORDER BY filing_date ASC) AS prior_filing_year
    FROM wealth_calc
)
SELECT 
    filing_id,
    employee_id,
    staff_code,
    employee_name,
    department,
    job_title,
    is_pep,
    filing_year,
    prior_filing_year,
    filing_date,
    approval_status,
    source_pdf_filename,
    
    -- Current Period Financial Status
    total_assets_jmd,
    total_liabilities_jmd,
    net_wealth_jmd,
    prior_net_wealth_jmd,
    
    -- Cash Flow Metrics
    total_monthly_inflow,
    total_monthly_outflow,
    annualized_net_savings_capacity,
    
    -- Realized Net Wealth Delta
    (net_wealth_jmd - COALESCE(prior_net_wealth_jmd, net_wealth_jmd)) AS net_wealth_delta,
    
    -- Unexplained Growth Gap: Wealth Delta - Annualized Net Savings Capacity
    CASE 
        WHEN prior_net_wealth_jmd IS NOT NULL 
        THEN (net_wealth_jmd - prior_net_wealth_jmd) - annualized_net_savings_capacity
        ELSE 0.00
    END AS unexplained_wealth_gap,
    
    -- Anomaly Flag:
    -- Net wealth jump exceeds 125% of annual net income OR exceeds net savings capacity by > 1.5M JMD
    CASE 
        WHEN prior_net_wealth_jmd IS NOT NULL 
             AND (net_wealth_jmd - prior_net_wealth_jmd) > (total_monthly_inflow * 12.0 * 1.25)
             AND (net_wealth_jmd - prior_net_wealth_jmd) > 1500000.00
        THEN TRUE
        ELSE FALSE
    END AS flag_wealth_anomaly
FROM trend_computation;

-- ============================================================================
-- 2. MATERIALIZED VIEW FOR RAPID DASHBOARD QUERIES
-- ============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_employee_annual_wealth_deltas AS
SELECT * FROM view_employee_annual_wealth_deltas;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_jn_filing_id 
    ON mv_employee_annual_wealth_deltas(filing_id);

CREATE INDEX IF NOT EXISTS idx_mv_jn_anomaly 
    ON mv_employee_annual_wealth_deltas(filing_year, flag_wealth_anomaly) 
    WHERE flag_wealth_anomaly = TRUE;