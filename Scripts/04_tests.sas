/*************************************************
 Program : 04_tests.sas
 Project : MS4S08 Road Safety in Wales (group project)
 Purpose : Statistical tests (Task B), chosen from the
           module's hypothesis testing table
 Question: In Wales in 2025, are collisions on faster roads
           more likely to cause death or serious injury,
           and who is most affected?
 Input   : rs.wales_collisions (one row per collision)
           rs.wales_analysis (one row per casualty)
           rs.collisions_raw (for DfT adjusted severity)
 Tests   : 1. Pearson correlation: fast road share vs KSI
              rate across the 22 councils
           2. Paired test: KSI rate on fast vs slower roads
              within each council
           3. Mann-Whitney: age of KSI vs slight casualties
 Notes   : Fast roads are 60 or 70 mph; slower roads are
           20 to 50 mph.
           Casualties with unknown age (50) are excluded
           from Test 3.
           ODS SELECT limits output to the tables used in
           the poster. Remove it to see the full output.
*************************************************/
libname rs "~/stats19_project";

/* Council names for tables and charts */
proc format;
  value $council
    "W06000001" = "Isle of Anglesey"
    "W06000002" = "Gwynedd"
    "W06000003" = "Conwy"
    "W06000004" = "Denbighshire"
    "W06000005" = "Flintshire"
    "W06000006" = "Wrexham"
    "W06000008" = "Ceredigion"
    "W06000009" = "Pembrokeshire"
    "W06000010" = "Carmarthenshire"
    "W06000011" = "Swansea"
    "W06000012" = "Neath Port Talbot"
    "W06000013" = "Bridgend"
    "W06000014" = "Vale of Glamorgan"
    "W06000015" = "Cardiff"
    "W06000016" = "Rhondda Cynon Taf"
    "W06000018" = "Caerphilly"
    "W06000019" = "Blaenau Gwent"
    "W06000020" = "Torfaen"
    "W06000021" = "Monmouthshire"
    "W06000022" = "Newport"
    "W06000023" = "Powys"
    "W06000024" = "Merthyr Tydfil";
run;

/*------------------------------------------------
 Test 1: Pearson correlation (council level, 22 councils)
 H0: no correlation between fast road share and KSI rate
 H1: there is a correlation
 Main test uses DfT adjusted severity, which allows for
 differences in how police forces record injuries.
 Recorded severity is the sensitivity check.
------------------------------------------------*/

/* One row per council */
proc sql;
  create table rs.councils as
  select a.local_authority_ons_district,
         put(a.local_authority_ons_district, $council.) as council
           length=20 label="Council",
         a.collisions, a.ksi_pct, b.adj_ksi_pct, a.fast_pct, a.rural_pct
  from
    (select local_authority_ons_district,
            count(*) as collisions label="Collisions",
            mean(collision_ksi_pct) as ksi_pct
              format=5.1 label="KSI rate (%)",
            mean(case when speed_limit in (60, 70) then 100
                      when not missing(speed_limit) then 0
                 end) as fast_pct
              format=5.1 label="On 60 or 70 mph roads (%)",
            mean(case when urban_rural = "Rural" then 100
                      when not missing(urban_rural) then 0
                 end) as rural_pct
              format=5.1 label="Rural (%)"
     from rs.wales_collisions
     group by local_authority_ons_district) as a
  left join
    /* Adjusted KSI: fatal counts as 1, otherwise DfT's
       adjusted probability of being serious */
    (select local_authority_ons_district,
            mean(case when collision_severity = 1 then 100
                      when collision_adjusted_severity_seri >= 0
                      then 100 * collision_adjusted_severity_seri
                 end) as adj_ksi_pct
              format=5.1 label="Adjusted KSI rate (%)"
     from rs.collisions_raw
     where local_authority_ons_district like "W%"
     group by local_authority_ons_district) as b
  on a.local_authority_ons_district = b.local_authority_ons_district
  order by fast_pct desc;
quit;

title "Test 1 data: one row per council";
proc print data=rs.councils noobs label;
  var council collisions ksi_pct adj_ksi_pct fast_pct rural_pct;
run;

/* Assumption check: Shapiro-Wilk p > 0.05 means Pearson is suitable */
title "Test 1 check: are the council rates normal?";
ods select TestsForNormality Histogram;
proc univariate data=rs.councils normal;
  var adj_ksi_pct ksi_pct fast_pct;
  histogram adj_ksi_pct ksi_pct fast_pct / normal;
run;

/* Main test, saving r and p for the plot */
title "Test 1: Pearson correlation, fast roads vs adjusted KSI rate";
ods output PearsonCorr=work.r_adj;
proc corr data=rs.councils pearson spearman nosimple;
  var fast_pct adj_ksi_pct;
run;

data _null_;
  set work.r_adj;
  if Variable = "fast_pct";
  call symputx("r_adj", put(adj_ksi_pct, 4.2));
  call symputx("p_adj", put(Padj_ksi_pct, pvalue6.4));
run;

title "Test 1 check: is the relationship linear? (fast roads vs adjusted KSI rate)";
proc sgplot data=rs.councils noautolegend;
  reg x=fast_pct y=adj_ksi_pct / clm datalabel=council
      markerattrs=(symbol=circlefilled size=9)
      lineattrs=(thickness=2) datalabelattrs=(size=7);
  inset "Pearson r = &r_adj, p = &p_adj" / position=topleft border;
  xaxis label="Collisions on 60 or 70 mph roads (%)";
  yaxis label="Adjusted KSI rate (%)";
run;

/* Sensitivity check: recorded KSI rate */
title "Test 1 sensitivity check: fast roads vs recorded KSI rate";
proc corr data=rs.councils pearson spearman nosimple;
  var fast_pct ksi_pct;
run;

/* Context: fast roads and rural areas overlap */
title "Test 1 context: fast roads, rural share and KSI rates";
proc corr data=rs.councils pearson nosimple;
  var fast_pct rural_pct adj_ksi_pct ksi_pct;
run;

/*------------------------------------------------
 Test 2: Paired test (council level, 22 councils)
 H0: mean difference between the fast road and slower
     road KSI rates within councils is zero
 H1: the mean difference is not zero
 Each council is compared with itself, so differences
 between councils (rurality, police recording) cancel out.
 Recorded severity is used for this reason.
------------------------------------------------*/

/* One row per council: fast and slower road KSI rates */
proc sql;
  create table rs.council_speed as
  select local_authority_ons_district,
         put(local_authority_ons_district, $council.) as council
           length=20 label="Council",
         sum(speed_limit in (60, 70)) as n_fast
           label="Fast road collisions",
         sum(speed_limit in (20, 30, 40, 50)) as n_slow
           label="Slower road collisions",
         mean(case when speed_limit in (60, 70)
                   then collision_ksi_pct end) as ksi_fast
           format=5.1 label="KSI rate, fast roads (%)",
         mean(case when speed_limit in (20, 30, 40, 50)
                   then collision_ksi_pct end) as ksi_slow
           format=5.1 label="KSI rate, slower roads (%)",
         calculated ksi_fast - calculated ksi_slow as ksi_diff
           format=5.1 label="Difference, fast minus slower"
  from rs.wales_collisions
  group by 1, 2
  order by n_fast;
quit;

title "Test 2 data: fast and slower road KSI rates by council";
proc print data=rs.council_speed noobs label;
  var council n_fast n_slow ksi_fast ksi_slow ksi_diff;
run;

/* Assumption check: are the differences normal?
   Normal: paired t test. Not normal: Wilcoxon signed rank,
   shown in the Tests for Location table */
title "Test 2 check: are the differences normal?";
ods select TestsForNormality TestsForLocation Histogram;
proc univariate data=rs.council_speed normal;
  var ksi_diff;
  histogram ksi_diff / normal;
run;

title "Test 2: paired t test, fast vs slower road KSI rate";
ods select Statistics ConfLimits TTests;
proc ttest data=rs.council_speed plots=none;
  paired ksi_fast*ksi_slow;
run;

/* Sensitivity check: leave out councils with fewer than
   10 fast road collisions (Swansea, Blaenau Gwent) */
title "Test 2 sensitivity check: councils with 10 or more fast road collisions";
ods select Statistics ConfLimits TTests;
proc ttest data=rs.council_speed plots=none;
  where n_fast >= 10;
  paired ksi_fast*ksi_slow;
run;

/*------------------------------------------------
 Test 3: Mann-Whitney U test (casualty level)
 H0: age distribution is the same for KSI and slight casualties
 H1: age distribution differs between the two groups
------------------------------------------------*/

/* Assumption check: is age normal in each group? */
title "Test 3 check: is age normal in each severity group?";
ods select TestsForNormality Histogram QQPlot;
proc univariate data=rs.wales_analysis normal;
  where not missing(age);
  class severity_group;
  var age;
  histogram age / normal;
  qqplot age / normal(mu=est sigma=est);
run;

title "Test 3: age summary by severity group";
proc means data=rs.wales_analysis n median q1 q3 mean std maxdec=1;
  where not missing(age);
  class severity_group;
  var age;
run;

/* HL gives the size of the age difference with a 95% CI */
title "Test 3: Mann-Whitney, age of KSI vs slight casualties";
ods select WilcoxonTest HodgesLehmann;
proc npar1way data=rs.wales_analysis wilcoxon hl plots=none;
  where not missing(age);
  class severity_group;
  var age;
run;

/* Sensitivity check: the t test should agree */
title "Test 3 sensitivity check: two sample t test";
ods select ConfLimits TTests Equality;
proc ttest data=rs.wales_analysis plots=none;
  where not missing(age);
  class severity_group;
  var age;
run;

title;