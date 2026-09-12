# Comm-Log Send Reconciliation

## Objective

Reproduce Finance's reported `target_base` of **22** for merchant `501`
for October 2026 across the Diwali campaigns.

The goal was to reconcile the initial raw send-attempt count with the
reported Finance metric by investigating campaign eligibility, retry
chains, and standalone campaign behavior.

---

## Dataset

The analysis uses the supplied SQLite database:

- `campaign`
- `communication_log`

### Scope

- **Merchant:** `501`
- **Period:** October 2026
- **Communication type:** `2` (Campaign)
- **Expected Finance `target_base`:** `22`

Each row in `communication_log` represents an individual send attempt.
The `campaign.parent_id` field identifies retry relationships between
campaigns.

---

## Business Rules

The investigation followed the rules provided in the data dictionary:

1. A campaign is eligible for reporting only when its creation workflow
   has cleared and `processing_status = 'processed'`.
2. `approval_awaiting` campaigns are not included in official reporting.
3. A campaign with a `parent_id` is a retry of its parent campaign.
4. Customers appearing across a retry chain represent the same
   underlying communication and are counted once.
5. Standalone campaigns are different: every send event counts separately,
   even when the same customer appears more than once.

---

## Investigation

### Step 0 — Naive Count

The first query counted every row in `communication_log`.

**Result: 30 send attempts**

This was the starting point because each row represents one individual
send attempt.

---

### Step 1 — Campaign Eligibility

Campaign `9004` was identified as `approval_awaiting`.

Although four communication-log rows existed for this campaign, the
campaign had not cleared the approval workflow and therefore was not
eligible for official reporting.

**Reconciliation:**

`30 → 26`

**Adjustment: -4**

---

### Step 2 — Retry Chain: 9001 → 9002 → 9003

Campaigns `9002` and `9003` are retries connected to campaign `9001`.

This chain contained **13 send attempts**, but only **10 distinct
customers**.

Customers who appeared across multiple campaigns in this retry chain
were treated as one underlying communication.

**Reconciliation:**

`26 → 23`

**Adjustment: -3**

---

### Step 3 — Retry Chain: 9201 → 9202

Campaign `9202` is a retry of campaign `9201`.

This chain contained **6 send attempts**, representing **5 distinct
customers**.

The repeated customer within the retry chain was therefore counted once.

**Reconciliation:**

`23 → 22`

**Adjustment: -1**

---

### Standalone Campaign: 9101

Campaign `9101` is standalone and does not belong to a retry chain.

Customer `C20` appears twice in the campaign. Both records were retained
because standalone campaigns count each send as a separate event.

Therefore, `COUNT(DISTINCT customer_id)` cannot be applied indiscriminately
across the entire dataset.

---

## Reconciliation Bridge

| Step | Description | Result | Adjustment |
|---|---|---:|---:|
| 0 | Naive count of `communication_log` rows | 30 | — |
| 1 | Exclude ineligible campaign `9004` | 26 | -4 |
| 2 | Deduplicate retry chain `9001 → 9002 → 9003` | 23 | -3 |
| 3 | Deduplicate retry chain `9201 → 9202` | 22 | -1 |
| **Final** | **`target_base`** | **22** | **—** |

### Reconciliation Summary

```text
30  naive send-attempt count
 -4 ineligible campaign 9004
 -3 duplicate retry attempts in 9001 → 9002 → 9003
 -1 duplicate retry attempt in 9201 → 9202
-----------------------------------------------
22  final target_base
