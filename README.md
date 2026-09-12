## Investigation

### Step 0 — Naive Count

The first query counted every row in `communication_log`.

**Result: 30 send attempts**

This was the starting point because each row represents one individual
send attempt.

---

### Step 1 — Campaign Eligibility

Campaign `9004` was identified as `approval_awaiting`.

Although four communication-log rows existed for this campaign, it had
not cleared the approval workflow and therefore was not eligible for
official reporting.

**Reconciliation:**

`30 → 26`

**Adjustment: -4**

---

### Step 2 — Retry Chain: 9001 → 9002 → 9003

Campaigns `9002` and `9003` are retries connected to campaign `9001`.

This chain contained **13 send attempts**, but only **10 distinct
customers**.

Customers appearing across multiple campaigns within the retry chain
represent the same underlying communication and are therefore counted
once.

**Reconciliation:**

`26 → 23`

**Adjustment: -3**

---

### Step 3 — Retry Chain: 9201 → 9202

Campaign `9202` is a retry of campaign `9201`.

This chain contained **6 send attempts**, representing **5 distinct
customers**.

The repeated customer within the retry chain therefore counts once.

**Reconciliation:**

`23 → 22`

**Adjustment: -1**

---

### Step 4 — Standalone Campaign: 9101

Campaign `9101` is a standalone campaign and is not part of a retry chain.

It contains 7 send events:

- C20
- C20
- C21
- C22
- C23
- C24
- C25

The two sends to C20 are both retained.

This is important because standalone campaigns count each send as a
separate event. Therefore, `COUNT(DISTINCT customer_id)` should **not**
be applied to this campaign.

**Reconciliation impact: 0**

The standalone rule confirms that the two C20 records should remain in
the final count rather than removing one as a duplicate.

## Reconciliation Bridge

| Step | Description | Result | Adjustment | Reason |
|---|---|---:|---:|---|
| 0 | Naive count of `communication_log` rows | 30 | — | Starting point |
| 1 | Exclude ineligible campaign `9004` | 26 | -4 | `approval_awaiting` campaigns are not reportable |
| 2 | Deduplicate retry chain `9001 → 9002 → 9003` | 23 | -3 | Customers across a retry chain count once |
| 3 | Deduplicate retry chain `9201 → 9202` | 22 | -1 | Retry attempts represent the same underlying communication |
| 4 | Validate standalone campaign `9101` | 22 | 0 | Every send event counts separately, including both C20 sends |
| **Final** | **`target_base`** | **22** | **—** | **Matches Finance's reported number** |
