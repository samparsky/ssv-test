# Test

The uses the foundry / forge framework.

## Part B

This will follow the approach of using CourseSummary snapshots to calculate the expected salary of the teacher.

Since the teacher salary is based on per block basis and the number of students can change, we take snapshots of CourseSummary at block heights where it changes and use it to calculate the teacher salary.

**Potential Issues**

-  We are following a lazy approach of evaluating the teacher salary it's possible when the teacher wants to claim there will be high gas cost depending on when last they claimed their salary. This is because we would have to loop through the pending snapshots to evaluate the user salary.


## Gas Report

```sh
forge test --gas-report
```