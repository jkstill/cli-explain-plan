
<html>
<body>
<h3>cli-explain-plan</h3>


A fairly simple command line text based plan formatter that operations on Oracle 10046 trace files.

Unlike tkprof, this tool does not require a login to the database.

<h3>Changes</h3>

- 2016-09-30 now correctly processes cursor handle reuse in trace files

<h3>To Do</h3>

Currently these things need fixed:

- attribute row source operations only to the stat line that incurred them
- <strike>version cursor IDs - cursor addresses may be reused, and this script does not yet know how to deal with that.</strike>

<h3>Example Output</h3>



<blockquote style='border: 2px solid #000;background-color:#D8D8D8;color:#0B0B61; white-space: pre-wrap;'>
<pre><code><i>

./plan-format.pl --file DWDB_ora_63389.trc --op-line-len 80

########################################################################################################################

Cursor: #140266215464672:

SQL:with chkdata as (
        SELECT /*+ no_merge */ DWC.BILL_DETAIL_ID
        FROM MY_COMPLEX_VIEW DWC
)
SELECT /*+ gather_plan_statistics */ vhc.*
FROM V_HEALTH_CHK VHC
right outer join chkdata cd on cd.BILL_DETAIL_ID = vhc.BILL_DETAIL_ID
        and cd.BILL_DETAIL_ID is not null

Line#  Operation                                                                                Rows        LIO      Read   Written Seconds
====== ================================================================================ ============  ========= ========= ========= =========
000001 NESTED LOOPS OUTER                                                                       1598  519191595        48         0 25006.33
000002   VIEW                                                                                   1598        824        11         0   0.01
000003     TABLE ACCESS FULL MY_COMPLEX_VIEW                                             1598        824        11         0   0.01
000004   VIEW VW_LAT_66BF064A                                                                   1598  519190771        37         0 21855.46
000005     FILTER                                                                               1598  519190771        37         0 21855.45
000006       HASH JOIN                                                                          1598  519190771        37         0 21855.44
000007         VIEW                                                                         11831592     153453         0         0  53.92
000008           FILTER                                                                     11831592     153453         0         0  51.84
000009             SORT GROUP BY                                                            18897948     153453         0         0  50.46
000010               VIEW VM_NWVW_1                                                         43801180     153453         0         0  30.30
000011                 SORT GROUP BY                                                        43801180     153453         0         0  22.46
000012                   INDEX RANGE SCAN CC_B_D_IDX                                        43804376     153453         0         0   9.21
000013         VIEW BILL_DETAIL_VIEW                                                            1598  519037318        37         0 21800.54
000014           UNION-ALL                                                                6152322372  519037318        37         0 22700.84
000015             TABLE ACCESS FULL BILL_DETAIL                                          3609655084   60199856         0         0 1039.59
000016             COUNT STOPKEY                                                             1097894    2384488         0         0  12.16
000017               TABLE ACCESS BY INDEX ROWID BATCHED PROXY_RESPONSE_CODE                 1097894    2384488         0         0   9.98
000018                 INDEX RANGE SCAN PROXY_RESP_CODE_PK                                   1097894    1286594         0         0   6.74
000019             COUNT STOPKEY                                                                1627      27236         0         0   0.32
000020               TABLE ACCESS BY INDEX ROWID BATCHED PROXY_RESPONSE_CODE                    1627      27236         0         0   0.26
000021                 INDEX RANGE SCAN PROXY_RESP_CODE_PK                                      1627      25609         0         0   0.19
000022             HASH JOIN                                                              2440486374  371041402        37         0 13401.29
000023               TABLE ACCESS FULL BILL_STATUS                                             31960       4794         0         0   0.11
000024               TABLE ACCESS FULL CC_BILL_DETAIL                                     2440486374  371036608        37         0 4693.37
000025             FILTER                                                                          0          0         0         0   0.00
000026               TABLE ACCESS FULL CHK_BILL_DETAIL                                             0          0         0         0   0.00
000027             HASH JOIN                                                                93388718   81159224         0         0 1113.51
000028               TABLE ACCESS FULL NEW_FEECODE_TO_FREQ                                28764       4794         0         0   0.10
000029               TABLE ACCESS FULL NEW_BILL_DETAIL                                 95595556   81154430         0         0 1018.78
000030             TABLE ACCESS FULL OLD_BILL_DETAIL                                         1930384    1388662         0         0  18.30
000031             HASH JOIN                                                                 6861812    2836450         0         0  50.01
000032               NESTED LOOPS                                                            6861812    2635102         0         0  49.44
000033                 NESTED LOOPS                                                          6861812    2635102         0         0  48.41
000034                   STATISTICS COLLECTOR                                                6861812    2635102         0         0  47.41
000035                     FILTER                                                            6861812    2635102         0         0  46.32
000036                       HASH JOIN RIGHT OUTER                                          27447248    2635102         0         0 124.12
000037                         TABLE ACCESS FULL MY_RESPONSE_CODE                              46342       4794         0         0   0.05
000038                         HASH JOIN                                                     6861812    2630308         0         0  35.98
000039                           TABLE ACCESS FULL MY_PROCESS_STATUS                           49538       4794         0         0   0.06
000040                           FILTER                                                      6861812    2625514         0         0  30.94
000041                             HASH JOIN RIGHT OUTER                                     9549648    2625514         0         0  24.13
000042                               TABLE ACCESS FULL MY_RESPONSE_CODE                        46342       4794         0         0   0.04
000043                               TABLE ACCESS FULL MY_BILL_DETAIL                        6861812    2620720         0         0  24.55
000044                   INDEX UNIQUE SCAN SYS_C0085925                                            0          0         0         0   0.00
000045                 TABLE ACCESS BY INDEX ROWID MY_BILL_BATCH                                   0          0         0         0   0.00
000046               TABLE ACCESS FULL MY_BILL_BATCH                                        10938310     201348         0         0   2.04
########################################################################################################################


</i></code></pre>
</blockquote>


