-- First naive approach checking the total number of rows that is the send attempt

SELECT COUNT(*) AS total_attempts
FROM communication_log;

-- checking the campaign table for identifying the retry chain, parent chain and standalone logic:

SELECT
    id,
    name,
    parent_id,
    creation_status,
    processing_status
FROM campaign
ORDER BY id;

--identifying how may SMS attempts, did each campaign took:

SELECT
    communication_id,
    COUNT(*) AS send_attempts
FROM communication_log
GROUP BY communication_id
ORDER BY communication_id;

--as the 9004 campaign was ineligible according to the readme provided in the word document:

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

--checking how many retry chains are present and also checking the underlying communications as the retry block is in (9001,9002,9003 also in 9201, 9202

SELECT
    communication_id,
    customer_id,
    delivery_status
FROM communication_log
WHERE communication_id IN (9001, 9002, 9003)
ORDER BY customer_id, communication_id;

-- identifying the underlying send attempts or communication for campaign (9201 & 9202)

SELECT
    communication_id,
    customer_id,
    delivery_status
FROM communication_log
WHERE communication_id IN (9201, 9202)
ORDER BY customer_id, communication_id;

--Campaign 9101 is standalone that is, it did not came from another campaign:

SELECT
    communication_id,
    customer_id,
    delivery_status
FROM communication_log
WHERE communication_id = 9101
ORDER BY customer_id, id;


