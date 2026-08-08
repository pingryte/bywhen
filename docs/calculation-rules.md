# Calculation rules

## Savings

The number of contributions is `ceil((target - current) / contribution)`. A contribution is considered to occur one complete frequency period after the chosen start date.

Daily, weekly, and fortnightly frequencies use exact day counts. Monthly and yearly frequencies use calendar arithmetic: adding months preserves the day of month when it exists and otherwise clamps to the final valid day. Therefore 31 January plus one month is 28 February (29 in a leap year). Repeated periods are added to the original date in one operation, so 31 January plus two months is 31 March.

Amounts must be finite; target and contribution must be positive; current cannot be negative; and a reached target returns a typed domain message rather than a zero-length success.

Milestones use 25%, 50%, 75%, and 100% of the target, omitting those already reached. Scenario rates are 75%, 100%, 125%, and 150% of the entered rate.

