/*************************************************
 Program : 02_clean.sas
 Project : MS4S08 Road Safety in Wales (group project)
 Purpose : Keep Welsh collisions, recode codes into
           readable groups, join casualties to their
           collisions, check the recoding, save clean tables
 Input   : rs.collisions_raw, rs.casualties_raw
 Output  : rs.wales_collisions (one row per collision)
           rs.wales_analysis (one row per casualty)
 Notes   : Code meanings from the DfT 2025 data guide.
           Missing (-1) and unknown codes are left missing.
           Casualty type 33 is not in the guide, so it is Other.
 Version : 3. 20 and 30 mph kept apart, unknown weather
           left missing, taxis grouped as car occupants,
           council code kept for the council level test.
*************************************************/
libname rs "~/stats19_project";

/*------------------------------------------------
 Section 1: Welsh collisions (temporary, with codes)
------------------------------------------------*/
data work.collisions_wales;
  set rs.collisions_raw
      (rename=(collision_severity      = col_severity_code
               speed_limit             = speed_code
               road_type               = road_type_code
               light_conditions        = light_code
               weather_conditions      = weather_code
               road_surface_conditions = surface_code
               urban_or_rural_area     = area_code));

  /* Welsh council codes start with W */
  where local_authority_ons_district =: "W";

  length collision_severity_group $6 speed_band $12 road_type $18
         light_conditions $8 weather $7 road_surface $10 urban_rural $5;

  /* Collision severity: KSI (fatal or serious) or Slight */
  if col_severity_code in (1, 2) then do;
    collision_severity_group = "KSI";
    collision_ksi_pct = 100;
  end;
  else if col_severity_code = 3 then do;
    collision_severity_group = "Slight";
    collision_ksi_pct = 0;
  end;

  /* Speed limit: only 20 to 70 mph are valid */
  if speed_code in (20, 30, 40, 50, 60, 70) then speed_limit = speed_code;
  else speed_limit = .;

  /* Speed bands: 20 and 30 mph kept apart because of the
     Welsh 20 mph default (Sept 2023) */
  if speed_limit = 20 then speed_band = "20 mph";
  else if speed_limit = 30 then speed_band = "30 mph";
  else if speed_limit in (40, 50) then speed_band = "40 or 50 mph";
  else if speed_limit = 60 then speed_band = "60 mph";
  else if speed_limit = 70 then speed_band = "70 mph";

  /* Road type: single, dual or other. Unknown (9) left missing */
  if road_type_code = 6 then road_type = "Single carriageway";
  else if road_type_code = 3 then road_type = "Dual carriageway";
  else if road_type_code in (1, 2, 7, 12) then road_type = "Other";

  /* Light: daylight or darkness */
  if light_code = 1 then light_conditions = "Daylight";
  else if light_code in (4, 5, 6, 7) then light_conditions = "Darkness";

  /* Weather: fine, adverse or other. Unknown (9) left missing */
  if weather_code = 1 then weather = "Fine";
  else if weather_code in (2, 3, 4, 5, 6, 7) then weather = "Adverse";
  else if weather_code = 8 then weather = "Other";

  /* Road surface: dry, or wet or icy */
  if surface_code = 1 then road_surface = "Dry";
  else if surface_code in (2, 3, 4, 5) then road_surface = "Wet or icy";

  /* Urban or rural. Unallocated (3) left missing */
  if area_code = 1 then urban_rural = "Urban";
  else if area_code = 2 then urban_rural = "Rural";

  /* Month and hour for time charts */
  month = month(date);
  hour  = hour(time);

  label local_authority_ons_district = "Local authority (ONS code)"
        date                     = "Date"
        time                     = "Time"
        month                    = "Month"
        day_of_week              = "Day of week (1 = Sunday)"
        hour                     = "Hour of day"
        collision_severity_group = "Collision severity group"
        collision_ksi_pct        = "Collision KSI rate (%)"
        speed_limit              = "Speed limit (mph)"
        speed_band               = "Speed limit band"
        road_type                = "Road type"
        light_conditions         = "Light conditions"
        weather                  = "Weather"
        road_surface             = "Road surface"
        urban_rural              = "Urban or rural";
run;

/*------------------------------------------------
 Section 2: Sort both tables by the join key
------------------------------------------------*/
proc sort data=work.collisions_wales;
  by collision_index;
run;

proc sort data=rs.casualties_raw out=work.casualties_sorted
          (keep=collision_index sex_of_casualty age_of_casualty
                casualty_severity casualty_type);
  by collision_index;
run;

/*------------------------------------------------
 Section 3: Join casualties to their Welsh collision
------------------------------------------------*/
data work.merged;
  merge work.collisions_wales (in=in_col)
        work.casualties_sorted (in=in_cas
          rename=(sex_of_casualty   = sex_code
                  age_of_casualty   = age_code
                  casualty_severity = severity_code
                  casualty_type     = type_code));
  by collision_index;

  /* Keep only casualties from Welsh collisions */
  if in_col and in_cas;

  length age_group $8 sex $6 road_user $12
         injury_severity $7 severity_group $6;

  /* Age: -1 means unknown */
  if age_code >= 0 then age = age_code;
  else age = .;

  if missing(age) then age_group = "";
  else if age <= 16 then age_group = "0 to 16";
  else if age <= 24 then age_group = "17 to 24";
  else if age <= 64 then age_group = "25 to 64";
  else age_group = "65+";

  /* Sex. Unknown (-1, 9) left missing */
  if sex_code = 1 then sex = "Male";
  else if sex_code = 2 then sex = "Female";

  /* Road user. Car occupant includes taxis (code 8).
     Codes 23 and 33 sit in Other */
  if type_code = 0 then road_user = "Pedestrian";
  else if type_code = 1 then road_user = "Cyclist";
  else if type_code in (2, 3, 4, 5, 97) then road_user = "Motorcyclist";
  else if type_code in (8, 9) then road_user = "Car occupant";
  else if type_code in (19, 20, 21, 98) then road_user = "Van or lorry";
  else if type_code >= 0 then road_user = "Other";

  /* Injury severity of the casualty */
  if severity_code = 1 then injury_severity = "Fatal";
  else if severity_code = 2 then injury_severity = "Serious";
  else if severity_code = 3 then injury_severity = "Slight";

  /* Severity group: KSI (killed or seriously injured) or Slight */
  if severity_code in (1, 2) then do;
    severity_group = "KSI";
    ksi_pct = 100;
  end;
  else if severity_code = 3 then do;
    severity_group = "Slight";
    ksi_pct = 0;
  end;

  label age             = "Age"
        age_group       = "Age group"
        sex             = "Sex"
        road_user       = "Road user"
        injury_severity = "Injury severity"
        severity_group  = "Severity group"
        ksi_pct         = "KSI rate (%)";
run;

/*------------------------------------------------
 Section 4: Checks on the temporary tables
------------------------------------------------*/
title "Check: Welsh collision and casualty counts";
proc sql;
  select count(*) as wales_collisions from work.collisions_wales;
  select count(*) as wales_casualties from work.merged;
  select count(distinct local_authority_ons_district) as wales_councils
    from work.collisions_wales;
quit;

title "Check: collision recoding matches the original codes";
proc freq data=work.collisions_wales;
  tables col_severity_code*collision_severity_group
         speed_code*speed_band road_type_code*road_type
         light_code*light_conditions weather_code*weather
         surface_code*road_surface area_code*urban_rural
         / missing nocol norow nopercent;
run;

title "Check: casualty recoding matches the original codes";
proc freq data=work.merged;
  tables type_code*road_user severity_code*injury_severity
         severity_code*severity_group sex_code*sex
         / missing nocol norow nopercent;
run;

title "Check: age";
proc means data=work.merged n nmiss mean min max;
  var age;
run;

title;

/*------------------------------------------------
 Section 5: Save the clean tables
 RETAIN sets the column order, KEEP drops the codes
------------------------------------------------*/
data rs.wales_collisions;
  retain collision_index local_authority_ons_district
         date time month day_of_week hour longitude latitude
         speed_limit speed_band road_type light_conditions weather
         road_surface urban_rural
         collision_severity_group collision_ksi_pct;
  set work.collisions_wales;
  keep collision_index local_authority_ons_district
       date time month day_of_week hour longitude latitude
       speed_limit speed_band road_type light_conditions weather
       road_surface urban_rural
       collision_severity_group collision_ksi_pct;
run;

data rs.wales_analysis;
  retain collision_index local_authority_ons_district
         date time month day_of_week hour longitude latitude
         speed_limit speed_band road_type light_conditions weather
         road_surface urban_rural
         age age_group sex road_user
         injury_severity severity_group ksi_pct;
  set work.merged;
  keep collision_index local_authority_ons_district
       date time month day_of_week hour longitude latitude
       speed_limit speed_band road_type light_conditions weather
       road_surface urban_rural
       age age_group sex road_user
       injury_severity severity_group ksi_pct;
run;