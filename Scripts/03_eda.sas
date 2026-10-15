/*************************************************
 Program : 03_eda.sas
 Project : MS4S08 Road Safety in Wales (group project)
 Purpose : Exploratory data analysis (Task A)
 Input   : rs.wales_analysis (one row per casualty)
           rs.wales_collisions (one row per collision)
 Notes   : Each result appears once. Group sizes (n) are
           shown on the charts, so no separate count tables.
           Road conditions are compared at collision level,
           personal factors at casualty level.
           The mean of a 0/100 KSI variable is the KSI rate (%).
 Colours : blue for all groups. Red is kept for the poster
           charts, where the key findings are highlighted.
*************************************************/
libname rs "~/stats19_project";

/* Readable labels for day and month codes */
proc format;
  value dayf   1="Sun" 2="Mon" 3="Tue" 4="Wed" 5="Thu" 6="Fri" 7="Sat";
  value monthf 1="Jan" 2="Feb" 3="Mar" 4="Apr" 5="May" 6="Jun"
               7="Jul" 8="Aug" 9="Sep" 10="Oct" 11="Nov" 12="Dec";
run;

/* Pie template for two part splits: count and percent */
proc template;
  define statgraph pie2;
    dynamic _var;
    begingraph / datacolors=(cx2C7FB8 cx9ECAE1);
      layout region;
        piechart category=_var /
                 datalabelcontent=(category response percent)
                 datalabellocation=outside start=90
                 datalabelattrs=(color=black size=11pt);
      endlayout;
    endgraph;
  end;
run;

%macro pie(var=, title=, data=rs.wales_collisions);
  title "&title";
  proc sgrender data=&data(where=(not missing(&var))) template=pie2;
    dynamic _var="&var";
  run;
%mend pie;

/* KSI rate by group, with group size in each label.
   sort=yes: highest at the top. sort=no: natural order */
%macro ksi_chart(var=, label=, title=, data=rs.wales_collisions,
                 resp=collision_ksi_pct, sort=yes);
  proc means data=&data nway noprint;
    where not missing(&var);
    class &var;
    var &resp;
    output out=work.ksi_&var n=n mean=ksi_rate;
  run;

  data work.ksi_&var;
    set work.ksi_&var;
    length group_label $40;
    group_label = catx(" ", &var, cats("(n=", put(n, comma6.), ")"));
  run;

  %if &sort = yes %then %do;
    proc sort data=work.ksi_&var;
      by descending ksi_rate;
    run;
  %end;

  title "&title";
  proc sgplot data=work.ksi_&var noautolegend;
    hbarparm category=group_label response=ksi_rate / datalabel
             fillattrs=(color=cx2C7FB8);
    format ksi_rate 4.1;
    xaxis label="Killed or seriously injured (%)" min=0 grid;
    yaxis label="&label" discreteorder=data;
  run;
%mend ksi_chart;

/* Collision counts over a time unit */
%macro time_line(var=, label=, title=, values=, fmt=);
  proc freq data=rs.wales_collisions noprint;
    where not missing(&var);
    tables &var / out=work.count_&var;
  run;

  title "&title";
  proc sgplot data=work.count_&var;
    series x=&var y=count / markers lineattrs=(color=cx2C7FB8 thickness=2)
           markerattrs=(symbol=circlefilled color=cx2C7FB8);
    %if &fmt ne %then %do; format &var &fmt; %end;
    xaxis label="&label" values=(&values);
    yaxis label="Number of collisions" min=0 grid;
  run;
%mend time_line;

/*------------------------------------------------
 Section 1: How serious were the injuries?
------------------------------------------------*/
title "Section 1: Injury severity of casualties";
proc freq data=rs.wales_analysis;
  tables injury_severity severity_group;
run;

title "Section 1: Severity of collisions";
proc freq data=rs.wales_collisions;
  tables collision_severity_group;
run;

/*------------------------------------------------
 Section 2: Who was injured?
------------------------------------------------*/
%pie(var=sex, title=Section 2: Casualties by sex, data=rs.wales_analysis)

title "Section 2: Age of casualties";
proc means data=rs.wales_analysis n nmiss mean median std min max skewness maxdec=1;
  var age;
run;

title "Section 2: Age distribution of casualties";
proc sgplot data=rs.wales_analysis;
  histogram age / binwidth=5 fillattrs=(color=cx2C7FB8);
  xaxis label="Age (years)";
  yaxis label="Percent of casualties";
run;

/* Check: is missing age linked to severity? */
data work.age_check;
  set rs.wales_analysis;
  length age_known $7;
  if missing(age) then age_known = "Unknown";
  else age_known = "Known";
run;

title "Section 2 check: missing age by severity group";
proc freq data=work.age_check;
  tables age_known*severity_group / nocol nopercent;
run;

/*------------------------------------------------
 Section 3: When did collisions happen?
------------------------------------------------*/
%time_line(var=month, label=Month, values=1 to 12 by 1, fmt=monthf.,
           title=Section 3: Collisions by month)
%time_line(var=day_of_week, label=Day of week, values=1 to 7 by 1, fmt=dayf.,
           title=Section 3: Collisions by day of week)
%time_line(var=hour, label=Hour of day (24 hour clock), values=0 to 23 by 2,
           title=Section 3: Collisions by hour of day)

/*------------------------------------------------
 Section 4: Where did collisions happen?
------------------------------------------------*/
%pie(var=urban_rural,      title=Section 4: Collisions by area)
%pie(var=light_conditions, title=Section 4: Collisions by light conditions)

/* What kind of road each speed band is */
title "Section 4: Road type and area within each speed band";
proc freq data=rs.wales_collisions;
  tables speed_band*road_type speed_band*urban_rural / nocol nopercent;
run;

/*------------------------------------------------
 Section 5: What is linked to more serious outcomes?
 Collision level for road conditions,
 casualty level for people
------------------------------------------------*/
%ksi_chart(var=speed_band, label=Speed limit, sort=no,
           title=Section 5: KSI rate of collisions by speed limit)
%ksi_chart(var=road_type, label=Road type,
           title=Section 5: KSI rate of collisions by road type)
%ksi_chart(var=urban_rural, label=Area,
           title=Section 5: KSI rate of collisions by area)
%ksi_chart(var=light_conditions, label=Light conditions,
           title=Section 5: KSI rate of collisions by light conditions)
%ksi_chart(var=weather, label=Weather,
           title=Section 5: KSI rate of collisions by weather)
%ksi_chart(var=road_surface, label=Road surface,
           title=Section 5: KSI rate of collisions by road surface)

%ksi_chart(var=road_user, label=Road user, data=rs.wales_analysis, resp=ksi_pct,
           title=Section 5: KSI rate of casualties by road user)
%ksi_chart(var=age_group, label=Age group, data=rs.wales_analysis, resp=ksi_pct,
           sort=no, title=Section 5: KSI rate of casualties by age group)
%ksi_chart(var=sex, label=Sex, data=rs.wales_analysis, resp=ksi_pct,
           title=Section 5: KSI rate of casualties by sex)

title;