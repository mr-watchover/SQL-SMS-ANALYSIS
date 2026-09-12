**# Comm-Log Send Reconciliation**



**## Objective**



**Reproduce Finance's reported `target\_base` of 22 for**

**merchant 501 for October 2026 across the Diwali campaigns.**



**## Dataset**



**The analysis uses the supplied SQLite database containing:**



**- `campaign`**

**- `communication\_log`**



**The scope is:**



**- Merchant: 501**

**- Period: October 2026**

**- Communication type: `2` (Campaign)**



**## Investigation**



**### Step 0 — Naive count**



**The initial query counted all rows in `communication\_log`.**



**\*\*Result: 30\*\***



**This is the naive starting point because each row represents an individual send attempt.**



**### Step 1 — Campaign eligibility**



**Campaign 9004 was identified as `approval\_awaiting`.**



**The data dictionary states that a campaign is included in official**

**reporting only when its creation workflow has cleared and its**

**processing workflow has completed.**



**Campaign 9004 had 4 send attempts, so these were excluded.**



**\*\*30 → 26\*\***



**### Step 2 — Retry chain: 9001 → 9002 → 9003**



**Campaigns 9002 and 9003 are retries in the same campaign chain.**



**Customers appearing in multiple campaigns within the retry chain**

**represent the same underlying communication and are therefore**

**counted once.**



**The chain contained 13 send attempts representing 10 distinct**

**customers.**



**\*\*26 → 23\*\***



**### Step 3 — Retry chain: 9201 → 9202**



**Campaign 9202 is a retry of campaign 9201.**



**The chain contained 6 send attempts representing 5 distinct**

**customers.**



**\*\*23 → 22\*\***



**### Standalone campaign: 9101**



**Campaign 9101 is standalone.**



**Customer C20 appears twice, but both rows are retained because**

**standalone campaigns count each send as a separate event.**



**Therefore, `COUNT(DISTINCT customer\_id)` was not applied to this**

**campaign.**



**## Reconciliation**



**| Step | Description | Result | Change |**

**|---|---|---:|---:|**

**| 0 | Naive count of `communication\_log` rows | 30 | — |**

**| 1 | Exclude ineligible campaign 9004 | 26 | -4 |**

**| 2 | Collapse retry chain 9001 → 9002 → 9003 | 23 | -3 |**

**| 3 | Collapse retry chain 9201 → 9202 | 22 | -1 |**

**| Final | `target\_base` | \*\*22\*\* | — |**



**## Final SQL**



**The final reconciliation query is available in:**



**`SQL/reconciliation.sql`**



**The investigation queries are available in:**



**`SQL/investigation.sql`**



**## Surprising Observation**



**One thing that surprised me was that a customer can appear more than**

**once within the same campaign without those records being considered**

**a retry. Campaign 9101 contains two send events for C20, and both**

**must be retained because the campaign is standalone. This means that**

**blindly applying `COUNT(DISTINCT customer\_id)` across all campaigns**

**would produce the wrong result.**



**## Result**



**\*\*Final target\_base: 22\*\***

