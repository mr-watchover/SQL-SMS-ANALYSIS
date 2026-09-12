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

## SQL Query and Explanation

## 1. First Naive Approach — Total Send Attempts

The first approach is to check the total number of rows in the `communication_log` table.

Each row represents a send attempt, so this provides the initial baseline.

    SELECT COUNT(*) AS total_attempts
    FROM communication_log;

---

## 2. Check Campaign Structure

The `campaign` table is checked to identify retry chains, parent-child relationships, standalone campaigns, and campaign statuses.

    SELECT
        id,
        name,
        parent_id,
        creation_status,
        processing_status
    FROM campaign
    ORDER BY id;

---

## 3. Identify Send Attempts per Campaign

This query identifies how many SMS/send attempts each campaign generated.

    SELECT
        communication_id,
        COUNT(*) AS send_attempts
    FROM communication_log
    GROUP BY communication_id
    ORDER BY communication_id;

---

## 4. Identify Eligible Campaign Attempts

According to the README/documentation, the eligible campaigns are determined using the merchant ID, creation status, and processing status.

Campaign `9004` was identified as ineligible according to the provided requirements.

    SELECT COUNT(*) AS eligible_attempts
    FROM communication_log cl
    JOIN campaign c
        ON cl.communication_id = c.id
    WHERE c.merchant_id = 501
      AND c.creation_status IN (
          'approved',
          'aborted',
          'resumed',
          'stopped'
      )
      AND c.processing_status = 'processed';

---

## 5. Check Retry Chain — 9001 → 9002 → 9003

The following query checks the underlying communication records for campaigns `9001`, `9002`, and `9003`.

The purpose is to identify the customers involved in the retry chain and determine whether the same customer appears across multiple communication attempts.

    SELECT
        communication_id,
        customer_id,
        delivery_status
    FROM communication_log
    WHERE communication_id IN (9001, 9002, 9003)
    ORDER BY customer_id, communication_id;

The identified retry branch is:

    9001 → 9002 → 9003

Because these campaigns represent retry attempts, the same customer should not be counted multiple times when calculating the target base.

Therefore, `COUNT(DISTINCT customer_id)` is used for this retry chain.

---

## 6. Check Retry Chain — 9201 → 9202

The second retry branch is examined separately.

    SELECT
        communication_id,
        customer_id,
        delivery_status
    FROM communication_log
    WHERE communication_id IN (9201, 9202)
    ORDER BY customer_id, communication_id;

The identified retry branch is:

    9201 → 9202

As with the first retry chain, the same customer may appear in multiple communication attempts.

Therefore, customers in this retry branch are counted using `COUNT(DISTINCT customer_id)`.

---

## 7. Check Standalone Campaign — 9101

Campaign `9101` is treated as a standalone campaign because it did not originate from another campaign.

The underlying communication records are inspected using:

    SELECT
        communication_id,
        customer_id,
        delivery_status
    FROM communication_log
    WHERE communication_id = 9101
    ORDER BY customer_id, id;

Since `9101` is a standalone campaign, its targets are counted separately from the retry chains.

---

## 8. Calculate the Target Base

The final target base combines three components:

1. Unique customers from retry chain `9001 → 9002 → 9003`
2. Targets from standalone campaign `9101`
3. Unique customers from retry chain `9201 → 9202`

    SELECT
        (
            SELECT COUNT(DISTINCT customer_id)
            FROM communication_log
            WHERE communication_id IN (9001, 9002, 9003)
        )
        +
        (
            SELECT COUNT(*)
            FROM communication_log
            WHERE communication_id = 9101
        )
        +
        (
            SELECT COUNT(DISTINCT customer_id)
            FROM communication_log
            WHERE communication_id IN (9201, 9202)
        ) AS target_base;

---

## 9. Why COUNT(DISTINCT customer_id) Is Used

A retry represents another attempt to reach the same target, rather than a completely new target.

For example:

    Customer C1
        ↓
    9001 — First attempt
        ↓
    9002 — Retry
        ↓
    9003 — Retry

There are three communication attempts:

    9001
    9002
    9003

But there is only one unique customer:

    C1

Therefore, the customer should contribute only one target to the target base.

This is why the retry branches use:

    COUNT(DISTINCT customer_id)

instead of:

    COUNT(*)

---

## 10. Target Base Calculation Logic

The final calculation can be represented as:

    Target Base
        =
        Unique customers in 9001 → 9002 → 9003
        +
        Targets in standalone campaign 9101
        +
        Unique customers in 9201 → 9202

The important distinction is between a **send attempt** and a **target**.

A send attempt represents an individual communication event.

A target represents the customer being contacted.

Therefore, multiple retry attempts for the same customer should not artificially increase the target base.

---

## 11. Complete SQL Investigation

The complete SQL investigation is provided below.

    -- First naive approach checking the total number of rows that is the send attempt

    SELECT COUNT(*) AS total_attempts
    FROM communication_log;


    -- checking the campaign table for identifying the retry chain, parent chain and standalone logic

    SELECT
        id,
        name,
        parent_id,
        creation_status,
        processing_status
    FROM campaign
    ORDER BY id;


    -- identifying how many SMS attempts did each campaign take

    SELECT
        communication_id,
        COUNT(*) AS send_attempts
    FROM communication_log
    GROUP BY communication_id
    ORDER BY communication_id;


    -- as the 9004 campaign was ineligible according to the readme provided in the word document

    SELECT COUNT(*) AS eligible_attempts
    FROM communication_log cl
    JOIN campaign c
        ON cl.communication_id = c.id
    WHERE c.merchant_id = 501
      AND c.creation_status IN (
          'approved',
          'aborted',
          'resumed',
          'stopped'
      )
      AND c.processing_status = 'processed';


    -- checking how many retry chains are present and also checking
    -- the underlying communications as the retry block is in
    -- 9001, 9002, 9003 and also in 9201, 9202

    SELECT
        communication_id,
        customer_id,
        delivery_status
    FROM communication_log
    WHERE communication_id IN (9001, 9002, 9003)
    ORDER BY customer_id, communication_id;


    -- identifying the underlying send attempts or communication
    -- for campaign 9201 & 9202

    SELECT
        communication_id,
        customer_id,
        delivery_status
    FROM communication_log
    WHERE communication_id IN (9201, 9202)
    ORDER BY customer_id, communication_id;


    -- Campaign 9101 is standalone,
    -- that is, it did not come from another campaign

    SELECT
        communication_id,
        customer_id,
        delivery_status
    FROM communication_log
    WHERE communication_id = 9101
    ORDER BY customer_id, id;


    -- Retry branch 9001 -> 9002 -> 9003

    SELECT
        (
            SELECT COUNT(DISTINCT customer_id)
            FROM communication_log
            WHERE communication_id IN (9001, 9002, 9003)
        )

        +

        -- Standalone campaign 9101

        (
            SELECT COUNT(*)
            FROM communication_log
            WHERE communication_id = 9101
        )

        +

        -- Retry branch 9201 -> 9202

        (
            SELECT COUNT(DISTINCT customer_id)
            FROM communication_log
            WHERE communication_id IN (9201, 9202)
        ) AS target_base;

---

## 12. Overall Investigation Flow

The analysis progresses from a simple row count to a business-rule-based calculation:

    Total communication_log rows
                ↓
    Identify campaign structure
                ↓
    Identify send attempts
                ↓
    Check campaign eligibility
                ↓
    Identify retry chains
                ↓
    Identify standalone campaign
                ↓
    Deduplicate customers within retry chains
                ↓
    Combine valid targets
                ↓
    Calculate target_base

---

## 13. Key Takeaway

The initial `COUNT(*)` gives the total number of **send attempts**, but send attempts are not necessarily equal to the number of **unique targets**.

The retry chains:

    9001 → 9002 → 9003

and:

    9201 → 9202

can contain multiple communication attempts for the same customer.

Therefore, the target base uses `COUNT(DISTINCT customer_id)` for retry chains so that the same customer is not counted multiple times.

The standalone campaign `9101` is counted separately.

The final target base is therefore calculated as:

    Unique customers from 9001 → 9002 → 9003
    +
    Targets from standalone campaign 9101
    +
    Unique customers from 9201 → 9202
