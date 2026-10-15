/*************************************************
 Program : 05_charts.sas
 Project : MS4S08 Road Safety in Wales (group project)
 Purpose : Poster charts (Task C) for the main findings
           from Tasks A and B
 Input   : rs.wales_collisions, rs.wales_analysis,
           rs.councils, rs.council_speed (from 04_tests)
 Output  : six PNG files (300 dpi) in the Charts folder
 Colours : blue = ordinary groups, red = the key finding
           (KSI, fast roads, 60 mph, motorcyclists),
           the same scheme as 03_eda
 Notes   : Old PNGs are removed first, so the folder only
           holds this run's six charts. Charts have no
           titles; each gets a numbered caption on the poster.
*************************************************/
%let path = /home/u64610698/stats19_project;
libname rs "&path";

/* Create the Charts folder if it does not exist */
options dlcreatedir;
libname charts "&path/Charts";
libname charts clear;

/* Remove old chart files: list them first, then delete */
data work.old_files;
  length fname $200;
  rc  = filename("dir", "&path/Charts");
  did = dopen("dir");
  if did > 0 then do;
    do i = 1 to dnum(did);
      fname = dread(did, i);
      if lowcase(scan(fname, -1, ".")) = "png" then output;
    end;
    rc = dclose(did);
  end;
  keep fname;
run;

data _null_;
  set work.old_files;
  rc = filename("f", cats("&path/Charts/", fname));
  rc = fdelete("f");
run;

/* Save each chart as a 300 dpi PNG */
ods listing gpath="&path/Charts" image_dpi=300;
ods graphics on / reset imagefmt=png noborder width=7in height=4.5in;
title;
footnote;

/* Colour map: blue for ordinary groups, red for the key finding */
data work.attrmap;
  length id $9 value $6 fillcolor linecolor markercolor $8;
  id = "highlight";
  value = "Focus";  fillcolor = "cxD7301F"; linecolor = "cxD7301F"; markercolor = "cxD7301F"; output;
  value = "Other";  fillcolor = "cx2C7FB8"; linecolor = "cx2C7FB8"; markercolor = "cx2C7FB8"; output;
  id = "severity";
  value = "KSI";    fillcolor = "cxD7301F"; linecolor = "cx404040"; markercolor = "cxD7301F"; output;
  value = "Slight"; fillcolor = "cx2C7FB8"; linecolor = "cx404040"; markercolor = "cx2C7FB8"; output;
run;

/*------------------------------------------------
 Figure 1 (Task A): collisions by speed limit
------------------------------------------------*/
ods graphics / imagename="fig1_collisions_by_speed_limit";
proc sgplot data=rs.wales_collisions noautolegend;
  where not missing(speed_limit);
  vbar speed_limit / datalabel datalabelattrs=(size=12pt)
                     fillattrs=(color=cx2C7FB8);
  xaxis label="Speed limit (mph)" labelattrs=(size=13pt) valueattrs=(size=12pt);
  yaxis label="Number of collisions" labelattrs=(size=13pt) valueattrs=(size=12pt)
        grid offsetmin=0;
run;

/*------------------------------------------------
 Figure 2 (Task A): KSI rate by speed band,
 60 mph (highest) in red. Values sit inside the bars;
 the dashed line (all collisions) is drawn behind them
------------------------------------------------*/
proc sql noprint;
  select mean(collision_ksi_pct) format=4.1 into :ksi_all trimmed
  from rs.wales_collisions;
quit;

proc means data=rs.wales_collisions nway noprint;
  where not missing(speed_band);
  class speed_band;
  var collision_ksi_pct;
  output out=work.fig2 mean=ksi_rate;
run;

data work.fig2;
  set work.fig2;
  length highlight $6;
  highlight = ifc(speed_band = "60 mph", "Focus", "Other");
  label_y = ksi_rate - 2.5;
run;

ods graphics / imagename="fig2_ksi_rate_by_speed_band";
proc sgplot data=work.fig2 dattrmap=work.attrmap noautolegend;
  refline &ksi_all / axis=y lineattrs=(pattern=dash color=cx404040)
                     label="All collisions (&ksi_all%)" labelattrs=(size=11pt);
  vbarparm category=speed_band response=ksi_rate / group=highlight
           attrid=highlight groupdisplay=stack;
  text x=speed_band y=label_y text=ksi_rate /
       textattrs=(color=white size=12pt weight=bold);
  format ksi_rate 4.1;
  xaxis label="Speed limit" labelattrs=(size=13pt) valueattrs=(size=12pt);
  yaxis label="Collisions killed or seriously injured (%)"
        labelattrs=(size=13pt) valueattrs=(size=12pt) grid offsetmin=0;
run;

/*------------------------------------------------
 Figure 3 (Task A): KSI rate by road user,
 motorcyclists (highest) in red, highest at the top.
 Other is left out as it mixes many vehicle types.
 Values sit inside the bars; dashed line drawn behind
------------------------------------------------*/
proc sql noprint;
  select mean(ksi_pct) format=4.1 into :ksi_cas trimmed
  from rs.wales_analysis;
quit;

proc means data=rs.wales_analysis nway noprint;
  where road_user ne "Other";
  class road_user;
  var ksi_pct;
  output out=work.fig3 mean=ksi_rate;
run;

proc sort data=work.fig3;
  by descending ksi_rate;
run;

data work.fig3;
  set work.fig3;
  length highlight $6;
  highlight = ifc(road_user = "Motorcyclist", "Focus", "Other");
  label_x = ksi_rate - 1;
run;

ods graphics / imagename="fig3_ksi_rate_by_road_user";
proc sgplot data=work.fig3 dattrmap=work.attrmap noautolegend;
  refline &ksi_cas / axis=x lineattrs=(pattern=dash color=cx404040)
                     label="All casualties (&ksi_cas%)" labelattrs=(size=11pt)
                     labelloc=inside labelpos=max;
  hbarparm category=road_user response=ksi_rate / group=highlight
           attrid=highlight groupdisplay=stack;
  text x=label_x y=road_user text=ksi_rate / position=left
       textattrs=(color=white size=12pt weight=bold);
  format ksi_rate 4.1;
  xaxis label="Casualties killed or seriously injured (%)"
        labelattrs=(size=13pt) valueattrs=(size=12pt) grid min=0 offsetmin=0;
  yaxis display=(nolabel) discreteorder=data valueattrs=(size=12pt)
        offsetmax=0.12;
run;

/*------------------------------------------------
 Figure 4 (Test 1): fast roads vs adjusted KSI rate,
 22 councils, red fitted line with 95% confidence band
------------------------------------------------*/
ods exclude all;
ods output PearsonCorr=work.r_adj;
proc corr data=rs.councils pearson;
  var fast_pct adj_ksi_pct;
run;
ods exclude none;

data _null_;
  set work.r_adj;
  if Variable = "fast_pct";
  call symputx("r_adj", put(adj_ksi_pct, 4.2));
  call symputx("p_adj", put(Padj_ksi_pct, 5.3));
run;

ods graphics / imagename="fig4_test1_councils" height=5.5in;
proc sgplot data=rs.councils noautolegend;
  reg x=fast_pct y=adj_ksi_pct / clm clmattrs=(clmfillattrs=(color=cxFCBBA1))
      lineattrs=(color=cxD7301F thickness=3)
      markerattrs=(symbol=circlefilled size=10 color=cx2C7FB8)
      datalabel=council datalabelattrs=(size=9pt);
  inset "Pearson r = &r_adj, p = &p_adj" / position=topleft border
        textattrs=(size=12pt);
  xaxis label="Collisions on 60 or 70 mph roads (%)"
        labelattrs=(size=13pt) valueattrs=(size=12pt) grid;
  yaxis label="Adjusted KSI rate (%)"
        labelattrs=(size=13pt) valueattrs=(size=12pt) grid;
run;
ods graphics / height=4.5in;

/*------------------------------------------------
 Figure 5 (Test 2): fast (red) vs slower (blue) road
 KSI rate within each council, largest gap at the top.
 The test result goes in the poster caption.
------------------------------------------------*/
proc sort data=rs.council_speed out=work.fig5;
  by ksi_diff;
run;

data work.fig5;
  set work.fig5;
  lo = min(ksi_fast, ksi_slow);
  hi = max(ksi_fast, ksi_slow);
run;

ods graphics / imagename="fig5_test2_fast_vs_slower" height=7in;
proc sgplot data=work.fig5;
  highlow y=council low=lo high=hi / lineattrs=(color=cxBDBDBD thickness=4);
  scatter x=ksi_slow y=council / name="slow"
          markerattrs=(symbol=circlefilled size=11 color=cx2C7FB8)
          legendlabel="Slower roads (20 to 50 mph)";
  scatter x=ksi_fast y=council / name="fast"
          markerattrs=(symbol=circlefilled size=11 color=cxD7301F)
          legendlabel="Fast roads (60 or 70 mph)";
  keylegend "slow" "fast" / position=top valueattrs=(size=12pt) noborder;
  yaxis display=(nolabel) discreteorder=data valueattrs=(size=11pt);
  xaxis label="Collisions killed or seriously injured (%)"
        labelattrs=(size=13pt) valueattrs=(size=12pt) grid;
run;
ods graphics / height=4.5in;

/*------------------------------------------------
 Figure 6 (Test 3): age by severity group,
 KSI in red, slight in blue
------------------------------------------------*/
proc means data=rs.wales_analysis noprint nway;
  where not missing(age);
  class severity_group;
  var age;
  output out=work.medians median=med_age;
run;

data _null_;
  set work.medians;
  call symputx(cats("med_", severity_group), put(med_age, 3.));
run;

ods graphics / imagename="fig6_test3_age_by_severity";
proc sgplot data=rs.wales_analysis dattrmap=work.attrmap noautolegend;
  where not missing(age);
  vbox age / category=severity_group group=severity_group attrid=severity
             medianattrs=(color=black thickness=2)
             meanattrs=(color=black symbol=diamondfilled);
  inset "Median age: KSI &med_KSI, slight &med_Slight years"
        / position=topright border textattrs=(size=12pt);
  xaxis display=(nolabel) valueattrs=(size=12pt);
  yaxis label="Age (years)" labelattrs=(size=13pt) valueattrs=(size=12pt)
        grid offsetmax=0.12;
run;

ods listing close;

/* Check: the Charts folder should hold exactly six PNGs */
data work.chart_files;
  length file $200;
  rc  = filename("dir", "&path/Charts");
  did = dopen("dir");
  do i = 1 to dnum(did);
    file = dread(did, i);
    output;
  end;
  rc = dclose(did);
  keep file;
run;

title "Check: files in the Charts folder";
proc print data=work.chart_files noobs;
run;
title;