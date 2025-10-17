SELECT * FROM patients

SELECT * FROM doctors

SELECT * FROM appointments

SELECT * FROM billing

SELECT * FROM treatments

--Checking for null Values
--Identify missing values that could break joins or cause inaccurate KPIs.
SELECT *
FROM patients
WHERE patient_id is null
	OR first_name is null
	OR last_name is null
	OR date_of_birth is null
	OR contact_number is null
	or insurance_provider is null
	or insurance_number is null
	or email is null

SELECT * 
FROM doctors
WHERE doctor_id is null
	OR first_name is null
	OR last_name is null
	OR specialization is null
	or phone_number is null
	or years_experience is null
	or hospital_branch is null
	or email is null

SELECT * 
FROM appointments
WHERE appointment_id is null
	or patient_id is null
	or doctor_id is null
	or appointment_date is null
	or reason_for_visit is null
	or [status] is null


SELECT * 
FROM billing
WHERE bill_id is null
	or patient_id is null
	or treatment_id is null
	or bill_date is null
	or amount is null
	or payment_method is null
	or payment_status is null

SELECT * 
FROM treatments
WHERE treatment_id is null
	or appointment_id is null
	or treatment_type is null
	or description is null
	or cost is null
	or treatment_date is null

--Uniqueness Checks
--Verify that key fields are unique where expected.

SELECT patient_id, count(*) FROM patients group by patient_id having count(*) > 1
SELECT doctor_id, count(*) FROM doctors group by doctor_id having count(*) > 1
SELECT appointment_id, count(*) FROM appointments group by appointment_id having count(*) > 1
SELECT bill_id, count(*) FROM billing group by bill_id having count(*) > 1
SELECT treatment_id, count(*) FROM treatments group by treatment_id having count(*) > 1

--Validity / Domain Checks
--Ensure data falls within expected ranges or formats.

SELECT DISTINCT gender FROM patients;

SELECT DISTINCT payment_status FROM billing;

SELECT DISTINCT [status] FROM appointments;

--Validate categorical values and ensure no illogical numeric values.
SELECT COUNT(*) AS negative_costs
FROM treatments
WHERE cost < 0;

SELECT COUNT(*) AS negative_amounts
FROM billing
WHERE amount < 0;

--Consistency Checks
--Ensure logical relationships across columns and tables.

SELECT COUNT(*) AS invalid_billing_dates
FROM billing b
JOIN treatments t ON b.treatment_id = t.treatment_id
WHERE b.bill_date < t.treatment_date;

SELECT COUNT(*) AS invalid_treatment_dates
FROM treatments t
JOIN appointments a ON t.appointment_id = a.appointment_id
WHERE t.treatment_date < a.appointment_date;

SELECT COUNT(*) AS invalid_registrations
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
WHERE a.appointment_date < p.registration_date;

--Referential Integrity
--Ensure all foreign keys correctly reference existing parent table records.

SELECT COUNT(*) AS invalid_patient_refs
FROM appointments a
LEFT JOIN patients p ON a.patient_id = p.patient_id
WHERE p.patient_id IS NULL;

SELECT COUNT(*) AS invalid_doctor_refs
FROM appointments a
LEFT JOIN doctors d ON a.doctor_id = d.doctor_id
WHERE d.doctor_id IS NULL;


--Accuracy / Reasonableness
--Check whether data makes practical sense (business rules).
--Age Validation
SELECT min(date_of_birth), max(date_of_birth) FROM patients

SELECT ROUND(min(DATEDIFF(YEAR, date_of_birth, GETDATE())), 0) AS min_age
, ROUND(max(DATEDIFF(YEAR, date_of_birth, GETDATE())), 0) as max_age
FROM patients


--Treatment Cost vs. Billing Amount
SELECT 
    COUNT(*) AS inconsistent_costs
FROM billing b
JOIN treatments t ON b.treatment_id = t.treatment_id
WHERE ABS(b.amount - t.cost) > 100; 

--Appointments Scheduled in the Future
--Ensure dataset includes recent records and no illogical future entries (unless simulation-based).
SELECT COUNT(*) AS future_appointments
FROM appointments
WHERE appointment_date > getdate();



----Exploratory SQL Queries
--Patient Overview - Patients distribution and average age by gender
SELECT 
    gender,
    COUNT(*) AS total_patients,
    ROUND(AVG(DATEDIFF(YEAR, date_of_birth, GETDATE())), 0) AS avg_age
FROM patients
GROUP BY gender;

--Identify top specializations and experience levels.
SELECT 
    specialization,
    COUNT(*) AS total_doctors,
    ROUND(AVG(years_experience),1) AS avg_experience
FROM doctors
GROUP BY specialization
ORDER BY total_doctors DESC;

--Measure completion and cancellation rates.
SELECT 
    status,
    COUNT(*) AS total_appointments,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM appointments), 2) AS percent_share
FROM appointments
GROUP BY status;

--Identify top-earning doctors and specializations.
Select D.doctor_id, concat(d.first_name, ' ', d.last_name) as Doctor_Name, d.specialization, FORMAT(sum(b.amount), 'C', 'en-US') as Revenue
From doctors d 
	LEFT OUTER JOIN  appointments a on d.doctor_id = a.doctor_id
	LEFT OUTER JOIN treatments T on T.appointment_id = A.appointment_id
	LEFT OUTER JOIN billing b on b.treatment_id = T.treatment_id
Where b.payment_status = 'Paid'
group by D.doctor_id, concat(d.first_name, ' ', d.last_name), d.specialization
order by Revenue desc 

--Average Treatment Cost per Type
Select treatment_type, FORMAT(avg(cost), 'C', 'en-US') as avg_treatment_Cost
FROM treatments
group by treatment_type
order by avg_treatment_Cost

--Outstanding Payments by Insurance Provider
SELECT P.insurance_provider
, COUNT(*) AS pending_bills
, FORMAT(sum(b.amount), 'C', 'en-US') AS total_due
FROM patients p inner join billing b on p.patient_id = b.patient_id
where b.payment_status = 'Pending'
group by P.insurance_provider
Order by total_due desc 



--Most Common Visit Reasons
SELECT reason_for_visit, count(*) as total_visits
FROM appointments
Group by reason_for_visit
order by total_visits desc


--Patient Lifetime Value (LTV)
SELECT 
    p.patient_id,
    concat(p.first_name ,' ', p.last_name) AS patient_name,
    FORMAT(sum(b.amount), 'C', 'en-US') AS lifetime_value
FROM billing b
JOIN patients p ON b.patient_id = p.patient_id
WHERE b.payment_status = 'Paid'
GROUP BY p.patient_id, concat(p.first_name ,' ', p.last_name)
ORDER BY lifetime_value DESC;


--Branch-Level Performance

SELECT 
    d.hospital_branch,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    FORMAT(sum(b.amount), 'C', 'en-US') AS total_revenue
FROM appointments a
JOIN doctors d ON a.doctor_id = d.doctor_id
JOIN treatments t ON a.appointment_id = t.appointment_id
JOIN billing b ON t.treatment_id = b.treatment_id
GROUP BY d.hospital_branch
ORDER BY total_revenue DESC;

--Appointment-to-Treatment Conversion Rate
SELECT 
    d.specialization,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    COUNT(DISTINCT t.treatment_id) AS total_treatments,
    ROUND(COUNT(DISTINCT t.treatment_id) * 100.0 / COUNT(DISTINCT a.appointment_id), 2) AS conversion_rate
FROM appointments a
LEFT JOIN treatments t ON a.appointment_id = t.appointment_id
JOIN doctors d ON a.doctor_id = d.doctor_id
GROUP BY d.specialization
ORDER BY conversion_rate DESC;

--Doctor Performance Insights --? Ranking & Trends - Rank doctors by monthly revenue contribution
--Shows top-performing doctors month over month, using window functions.
WITH MonthlyRevenue AS (
    SELECT 
        d.doctor_id,
        CONCAT(d.first_name, ' ', d.last_name) AS doctor_name,
        FORMAT(b.bill_date, 'yyyy-MM') AS month_year,
        FORMAT(sum(b.amount), 'C', 'en-US') AS total_revenue
    FROM doctors d
    JOIN appointments a ON d.doctor_id = a.doctor_id
    JOIN treatments t ON a.appointment_id = t.appointment_id
    JOIN billing b ON t.treatment_id = b.treatment_id
    WHERE b.payment_status = 'Paid'
    GROUP BY d.doctor_id, d.first_name, d.last_name, FORMAT(b.bill_date, 'yyyy-MM')
)
SELECT *,
       RANK() OVER (PARTITION BY month_year ORDER BY total_revenue DESC) AS revenue_rank
FROM MonthlyRevenue
ORDER BY month_year DESC, revenue_rank ASC;


--Revenue Trend Analysis --? Monthly Revenue Growth with % Change
--Tracks month-over-month hospital revenue and growth rate.
WITH MonthlyRevenue AS (
    SELECT 
        FORMAT(b.bill_date, 'yyyy-MM') AS month_year,
        SUM(b.amount) AS total_revenue
    FROM billing b
    WHERE b.payment_status = 'Paid'
    GROUP BY FORMAT(b.bill_date, 'yyyy-MM')
)
SELECT 
    month_year,
    FORMAT(total_revenue, 'C', 'en-US') AS total_revenue,
    FORMAT(LAG(total_revenue) OVER (ORDER BY month_year), 'C', 'en-US') AS prev_month_revenue,
    ROUND(
        ( (total_revenue - LAG(total_revenue) OVER (ORDER BY month_year)) * 100.0 / 
           NULLIF(LAG(total_revenue) OVER (ORDER BY month_year), 0) ), 2
    ) AS pct_change
FROM MonthlyRevenue
ORDER BY month_year;


--Appointment Timeliness — No-Show / Cancellation Ratio
--Helps identify service quality issues or peak cancellation months.
SELECT 
    FORMAT(appointment_date, 'yyyy-MM') AS month,
    SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed,
    ROUND(SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancel_rate
FROM appointments
GROUP BY FORMAT(appointment_date, 'yyyy-MM')
ORDER BY month;

--Patient Retention & Visit Frequency--? How many patients visited multiple times?
--Measures patient retention rate and engagement level.
SELECT 
    COUNT(*) AS total_patients,
    SUM(CASE WHEN visit_count > 1 THEN 1 ELSE 0 END) AS returning_patients,
    ROUND(SUM(CASE WHEN visit_count > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS retention_rate
FROM (
    SELECT patient_id, COUNT(*) AS visit_count
    FROM appointments
    GROUP BY patient_id
) AS patient_visits;


--Payment Performance Metrics--? Average payment delay and outstanding balances
--Adds operational insight into billing efficiency and delays.
SELECT 
    p.insurance_provider,
    AVG(DATEDIFF(DAY, t.treatment_date, b.bill_date)) AS avg_billing_delay,
    FORMAT(SUM(CASE WHEN b.payment_status = 'Pending' THEN b.amount ELSE 0 END), 'C', 'en-US') AS total_pending,
    COUNT(CASE WHEN b.payment_status = 'Failed' THEN 1 END) AS failed_payments
FROM billing b
JOIN treatments t ON b.treatment_id = t.treatment_id
JOIN patients p ON b.patient_id = p.patient_id
GROUP BY p.insurance_provider
ORDER BY avg_billing_delay DESC;

--Treatment Effectiveness (Cost vs Frequency)--? Which treatments generate the highest total revenue or volume?
--Identifies high-impact or high-value treatments.
SELECT 
    t.treatment_type,
    COUNT(*) AS total_treatments,
    FORMAT(sum(b.amount), 'C', 'en-US') AS total_revenue,
    FORMAT(ROUND(AVG(t.cost), 2), 'C', 'en-US') AS avg_cost
FROM treatments t
JOIN billing b ON t.treatment_id = b.treatment_id
WHERE b.payment_status = 'Paid'
GROUP BY t.treatment_type
ORDER BY total_revenue DESC;


--Doctor Workload vs Revenue
SELECT 
    d.specialization,
    COUNT(DISTINCT a.appointment_id) AS total_appointments,
    COUNT(DISTINCT t.treatment_id) AS total_treatments,
    FORMAT(sum(b.amount), 'C', 'en-US') AS total_revenue,
    FORMAT(ROUND(SUM(b.amount) / NULLIF(COUNT(DISTINCT a.appointment_id), 0), 2), 'C', 'en-US') AS avg_revenue_per_appointment
FROM doctors d
JOIN appointments a ON d.doctor_id = a.doctor_id
JOIN treatments t ON a.appointment_id = t.appointment_id
JOIN billing b ON t.treatment_id = b.treatment_id
WHERE b.payment_status = 'Paid'
GROUP BY d.specialization
ORDER BY avg_revenue_per_appointment DESC;

--Peak Time & Day Analysis --? Find the busiest appointment hours and weekdays
--Useful for resource planning and scheduling optimization.
SELECT 
    DATENAME(WEEKDAY, appointment_date) AS weekday,
    DATEPART(HOUR, appointment_time) AS hour_slot,
    COUNT(*) AS total_appointments
FROM appointments
GROUP BY DATENAME(WEEKDAY, appointment_date), DATEPART(HOUR, appointment_time)
ORDER BY total_appointments DESC;


--Average Revenue per Patient (ARPP)
--Adds a financial KPI often used in healthcare reporting.
SELECT 
    FORMAT(ROUND(SUM(b.amount) * 1.0 / COUNT(DISTINCT p.patient_id), 2), 'C', 'en-US') AS avg_revenue_per_patient
FROM billing b
JOIN patients p ON b.patient_id = p.patient_id
WHERE b.payment_status = 'Paid';


--Top Returning Patients
--Great for patient loyalty analysis.
SELECT 
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    COUNT(a.appointment_id) AS total_appointments,
    FORMAT(sum(b.amount), 'C', 'en-US') AS total_spent
FROM patients p
JOIN appointments a ON p.patient_id = a.patient_id
JOIN treatments t ON a.appointment_id = t.appointment_id
JOIN billing b ON t.treatment_id = b.treatment_id
GROUP BY p.patient_id, p.first_name, p.last_name
HAVING COUNT(a.appointment_id) > 2
ORDER BY total_spent DESC;

