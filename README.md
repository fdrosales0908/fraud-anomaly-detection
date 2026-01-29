# 🛡️ Compliance & Fraud Dashboard (Shiny)
**Fraud Pattern Detection in Subscription-Based Digital Services**

🔗 **Live Dashboard:**  
https://latency-fraud-analysis.shinyapps.io/fraud_latency_test/

---

## 📌 Project overview
This project shows how we can detect **potential fraud patterns** in **digital subscription services** (Telco / VAS) using **latency analysis** and **statistical comparison**.

The analysis uses **fully simulated data** (about **3 months**) for **one country** and **multiple merchants**.  
It is inspired by real compliance and antifraud monitoring, but **no real data** is used.

⚠️ **Disclaimer**  
All data in this project is **simulated** and created only for portfolio and learning purposes.  
No real customers, companies, or transactions are included.

---

## 🙋‍♀️ My contribution
I developed this project end-to-end as a portfolio case:
- I designed the monitoring approach (merchant baseline + deviation signals).
- I created the simulated dataset structure and assumptions (3 months, multiple merchants).
- I built the Shiny dashboard (pages, filters, and investigation views).
- I wrote the documentation, limitations, and interpretation for non-technical audiences.

---

## 🧰 Skillset & tools demonstrated

**Skills**
- Fraud / anomaly monitoring logic (pattern-based signals)
- Robust statistics (median, IQR, z-scores)
- Feature design (fast-rate, volume filters)
- Dashboard design for investigation workflows
- Technical communication (clear definitions + limitations)

**Tools**
- R, Shiny  
- Data wrangling and visualization in R *(add your real packages here, e.g., dplyr, ggplot2, plotly, etc.)*

---

## 🎯 Business problem
In digital subscription flows, fraud usually does not appear as one abnormal event.  
It appears as **repeated behaviour patterns**, for example:
- interactions that are **too fast**
- behaviour that is **too consistent**
- repeated actions with **enough volume**

The goal is to detect these patterns **early**, without fixed rules that create many false positives.

---

## 🧠 Core concepts

### 1) Latency
**Latency** is the time (in seconds) between a landing page visit and the first valid user interaction.

Latency formula:  
**Latency = First_Query_Timestamp − Landing_Page_Time**

**Normal latency**
- irregular and variable
- wide dispersion (p25–p75)
- different across users and merchants  
→ typical human behaviour

**Suspicious latency**
- unusually fast
- very consistent
- repeated many times  
→ possible automation (bots, scripts, induced flows)

---

### 2) Fraud risk (risk score)
This project does **not** label fraud directly.

Instead, it calculates a **risk score (0–100)** that shows **how abnormal the behaviour is**, compared to the **merchant’s own historical behaviour**.

This makes the approach:
- adaptive
- explainable
- useful for compliance and operations teams

---

## 🔬 Methodology

### Merchant-specific baseline
Instead of fixed rules like *“latency < 2 seconds = fraud”*, the dashboard builds a **baseline for each merchant**, using:
- typical **median** latency
- **variability** (IQR / dispersion)
- typical **share of very fast events** (<2 seconds)

Each **day × hour** block is compared to the baseline using **statistical deviation (z-scores)**.

---

### Signals used
Fraud risk increases when:
- median latency is much lower than normal
- the proportion of very fast events (<2s) is high
- volume is large enough to avoid random noise

---

### Why not averages?
Averages are limited because:
- they are sensitive to outliers
- fraud behaviour is often asymmetric
- bots can create extreme and stable patterns

For this reason, the dashboard uses:
- median
- IQR
- z-scores
- fast-event rates

This is closer to real antifraud monitoring, not only academic theory.

---

## 🏢 Merchant-level insights (summary)
The analysis is done **per merchant**, not globally. Each merchant has different typical latency and variability, so we evaluate anomalies **relative to its own historical baseline**.

**Example patterns**
- **Merchant B:** fast but still normal (healthy dispersion) → low risk.
- **Merchant C:** risk spikes with high fast-rate and reduced variability → possible automation bursts.

---

## 📊 Dashboard structure
The dashboard is designed for **monitoring and investigation** and includes:

- **Overview** – General configuration and context
- **Avg by Hour (Top N)** – Average transaction time by hour
- **Boxplot by Hour (Top N)** – Latency distribution and stability
- **Median + IQR (Top N)** – Robust central value and dispersion
- **Fast Rate <2s (Top N)** – Share of very fast interactions
- **Heatmap Risk (Top N)** – Risk hotspots by day and hour
- **Daily (Latency vs Risk) (Top N)** – Relationship between latency and risk over time
- **Weekday Risk (Top N)** – Risk patterns by day of week
- **Escalation (Top N)** – Priority list for investigation

---

## 📊 Dashboard examples

### Average transaction time by hour
![Avg transaction time by hour](images/avg_per_hour.png)

### Transaction time distribution (boxplot)
![Latency boxplot by hour](images/boxplot_per_hour.png)

### Median latency and IQR
![Median latency and IQR](images/median_iqr.png)

### Fraud risk heatmap (day × hour)
![Risk heatmap](images/heatmap.png)

### Daily latency vs risk
![Daily latency vs risk](images/daily_latency.png)

### Fraud risk by weekday
![Weekday risk](images/weekday_risk.png)

### Escalation view
![Escalation view](images/escalation.png)

---

## 📦 Deliverables
- Live Shiny dashboard (link above)
- Source code and documentation (this repository)
- Images with examples of key views (in `/images`)

---

## ⚠️ Limitations
- Data is simulated, so results show **method behaviour**, not real fraud cases.
- The risk score supports prioritization; it does not prove fraud.
- Thresholds (e.g., <2s fast-rate) are illustrative and should be tuned per market.

---

## ✅ Conclusion
This dashboard shows clear behaviour patterns that support **latency analysis** as an early signal of possible fraud or automation.

Latency becomes meaningful **only when measured against each merchant’s own baseline**, and when confirmed by repetition and enough volume.

This approach reduces false positives and reflects how compliance and antifraud teams prioritize investigations.
