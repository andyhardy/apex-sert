--  VERSION @SV_VERSION@
--
--    NAME
--      ins.sql
--
--    DESCRIPTION
--
--    NOTES
--      Assumes the SYS user is connected.
--
--    REQUIREMENTS
--      - Requires Application Express 5.1.1 or higher to be installed
--      - Requires V11.2.0.1 of the database.
--
--    Arguments:
--
--    Example:
--
--    1)Local
--      sqlplus "sys/syspass as sysdba" @ins 
--
--    2)With connect string
--      sqlplus "sys/syspass@10g as sysdba" @ins 
--
--    MODIFIED   
--      dgault    1/7/09 7:19 PM - Created   
--      
set define '^'
set concat on
set concat .
set verify off
set termout on
CLEAR SCREEN
PROMPT 
PROMPT.   ___  ______ _______   __      _____ ___________ _____ 
PROMPT.  / _ \ | ___ \  ___\ \ / /     /  ___|  ___| ___ \_   _|
PROMPT. / /_\ \| |_/ / |__  \ V /______\ `--.| |__ | |_/ / | |  
PROMPT. |  _  ||  __/|  __| /   \______|`--. \  __||    /  | |  
PROMPT. | | | || |   | |___/ /^\ \     /\__/ / |___| |\ \  | |  
PROMPT. \_| |_/\_|   \____/\/   \/     \____/\____/\_| \_| \_/  
PROMPT                              
PROMPT  ===================== APEX-SERT =======================
PROMPT  Software Version: @SV_VERSION@
PROMPT
PAUSE   Press Enter to continue installation or CTRL-C to EXIT
--

-- Terminate the script on Error during the beginning
whenever sqlerror exit

--  feedback - Displays the number of records returned by a script ON=1
set feedback off
--  termout - display of output generated by commands in a script that is executed
set termout on
-- serverout - allow dbms_output.put_line to be seen in sqlplus
set serverout on
--  define on -- allows substitutions
set define on
--  define - Sets the character used to prefix substitution variables
set define '^'
--  concat - Sets the character used to terminate a substitution variable ON=.
set concat on 
--  verify off prevents the old/new substitution message
set verify off
--Sets the number of lines on each page of output.
SET PAGESIZE 50


--  =================
--  =================  User Input and Substitution Varible Definitions
--  =================
define sert_app_id                 = ''                         -- APP ID for SERT
define sdb2                        = 'NOSYSDBA'                 -- 
define create_user_s               = 'ins/create_user.sql'
define create_parse_as_s           = 'ins/create_parse_as.sql'
define scheduling_grant_s          = 'ins/scheduling_grant.sql'
define parse_as_grants_s           = 'ins/parse_as_grants.sql'
define app_id_assign_script         ='app/id_prompts.sql'       -- Script to assign APP_ID

PROMPT  ... Testing for prerequisites
--  =================
--  =================  PREREQUISITE TESTS
--  =================
--
--  =================
--  =================  Check SYSDBA Privilege
--  =================
PROMPT  ...... Test for SYSDBA privs
column sdb new_val sdb2 NOPRINT
--
select privilege sdb from session_privs where privilege = 'SYSDBA';
--
begin
    if '^sdb2' = 'NOSYSDBA' then
        dbms_output.put_line('SERT installation requires a connection with the SYSDBA privilege.');
        execute immediate 'bogus statement to force exit';
    end if;
end;
/
--  =================
--  =================  Check for V11.2.0.4 and above of the databse
--  =================
PROMPT  ...... Test for Oracle 11.2.0.4 or above

declare
    l_version number;
begin
    execute immediate
      'select to_number(replace(version,''.'',null)) from registry$ where cid=''CATPROC'''
    into l_version;

    if l_version < 110204 then
        dbms_output.put_line('APEX-SERT installation requires database version 11.2.0.4 or later.');
        execute immediate 'bogus statement to force exit';
    end if;
end;
/

--  =================
--  =================  Check for XE edition 
--  =================
PROMPT  ...... Test for XE Edition of Oracle
declare
    l_edition varchar2(30) := 'notXE';
begin
        begin
            execute immediate
              'select edition from registry$ WHERE cid=''CATPROC'''
            into l_edition;
        exception when others then
            null;
        end;


    if l_edition = 'XE' then
        dbms_output.put_line('APEX-SERT will not run on the XE edition of Oracle.');
        execute immediate 'bogus statement to force exit';
    end if;
end;
/

--  =================
--  =================  Check for APEX 5.1.0 or above
--  =================
PROMPT  ...... Test for Valid Instance of APEX 5.1.0 or above
declare
    l_version number;
    l_status dba_registry.status%TYPE := 'INVALID';
begin
    BEGIN 
       execute immediate
         'select to_number(replace(version,''.'',null)), status from registry$ where cid=''APEX'''
       into l_version, l_status;
    EXCEPTION
       when NO_DATA_FOUND then
         dbms_output.put_line('SERT installation requires a VALID APEX installation of Version 5.1.1 or above.');
          dbms_output.put_line('-- NO APEX INSTALLATION FOUND IN DBA_REGISTRY.');
          execute immediate 'bogus statement to force exit';
       when others then
          dbms_output.put_line('Error Selecting data from registry$ ');
          dbms_output.put_line(SQLERRM);
         execute immediate 'bogus statement to force exit'; 
    END; 
    
    if l_version < 5110000 then
        dbms_output.put_line('This APEX-SERT installation requires APEX version 5.1.0 or later.');
        execute immediate 'bogus statement to force exit';
    elsif l_status = 'INVALID' then
        dbms_output.put_line('Current version of APEX is marked as INVALID.');
        execute immediate 'bogus statement to force exit';
    end if;

end;
/

--  =================
--  =================  Check for the correct SERT Version
--  =================
PROMPT  ...... Is current version of SERT already installed

define esert_user                  = 'SV_SERT_@SV_VERSION@'

Rem Check if this version is already installed
begin
    for c1 in (select null
                 from dba_users
                where username = '^esert_user' ) loop
        dbms_output.put_line('This version of SERT is already installed.');
        execute immediate 'bogus statement to force exit';
    end loop;


    -- application by Alias Check
    for c1 in (select 'x'
                 from apex_applications
                where ALIAS = 'SERT' 
              ) loop
        dbms_output.put_line('An application with the Alias "SERT" is already installed.');
        -- bogus statement to force exit
        execute immediate 'Failed prerequisite';
    end loop;
    dbms_output.put_line('...... Application Alias check is clear');
    
    -- Workspace by Name Check
    for c1 in (
                select workspace 
                  from   apex_workspaces 
                  where  workspace = 'SERT'
              ) loop
        dbms_output.put_line('A Workspace with the name "SERT" already exists.');
        -- bogus statement to force exit
        execute immediate 'Failed prerequisite';
    end loop;
    dbms_output.put_line('...... Application Alias check is clear');

END;
/

--  =================
--  =================  END PREREQUISITE TESTS
--  =================
PROMPT  ... Test for prerequisites succeeded
PROMPT
whenever sqlerror continue
--  =================
--  ================= Start The logging 
--  ================= 
column ln new_val logname NOPRINT
select 'SERT_install_'||to_char(sysdate, 'YYYY-MM-DD_HH24-MI-SS')||'.log' ln from dual;
--  =================
--  ================= Set the User who will own the SERT Objects
--  =================

spool ^logname

--  =================
--  ================= Does the SV_SERT_@SV_VERSION@ user exist? If not run the Create User Script
--  =================
column create_user new_val create_user_s NOPRINT
--
select 'null.sql' create_user from dba_users where username = upper('SV_SERT_@SV_VERSION@');
--
ACCEPT schema_password     CHAR DEFAULT ''  PROMPT 'Please enter the password for the SERT Schemas: '
ACCEPT sert_password       CHAR DEFAULT ''  PROMPT 'Please enter the password for the SERT Admin user: '
ACCEPT admin_email_address CHAR DEFAULT ''  PROMPT 'Please enter the e-mail address the SERT Admin user: '
set termout off
--
-- Create the SV_SERT_@SV_VERSION@ User and it's grants
-- 
define create_user_s               = 'ins/create_user.sql'

@@^create_user_s
@@ins/user_grants

--  =================
--  ================= Does the SV_SERT_APEX user exist? If not run the Create User Script
--  =================
column create_user new_val create_parse_as_s NOPRINT
--
define parse_as_user               = '@SV_PARSE_AS@'

select 'null.sql' create_user from dba_users where username = upper('^parse_as_user');
--
set termout off
--
-- Create the SV_SERT_APEX User 
-- 
@@^create_parse_as_s
--
-- Grant the APEX_ADMINISTRATOR_ROLE 
-- 
@@ins/admin_role_grants

--  =================
--  ================= Create the SV_SERT_LAUNCHER user
--  =================
@@ins/create_launcher

set termout on
-- Using some SQL*PLUS magic, change the names of the scripts we would use to install the 
-- Parse As support. The script names will be correct if the user selected YES but will 
-- be changed to 'null.sql' if the user selects anything else.

column scheduling_grant new_val scheduling_grant_s NOPRINT
-- Always install the scheduling option, since the role will be assigned anyways
select 'null.sql' scheduling_grant from dual where 'NO' != 'YES';
--
set termout off
--
-- Call the Extra Grant script
@@^scheduling_grant_s 

set termout on
--  =================
--  =================  Check to see if they want to install with the grants that would allow for schema details.
--  =================
PROMPT 
PROMPT ============================================================================
PROMPT == P A R S E   A S   S C H E M A   D E T A I L S   O P T I O N
PROMPT ============================================================================
PROMPT 
PROMPT SERT can provide the ability to examine and report on the schema level
PROMPT privileges of the applications "Parse As" schema. However this requires the
PROMPT following system privileges to be granted to the PARSE AS SCHEMA.
PROMPT 
PROMPT   * GRANT SELECT ON SYS.DBA_SYS_PRIVS TO ^parse_as_user
PROMPT   * GRANT SELECT ON SYS.DBA_TAB_PRIVS TO ^parse_as_user
PROMPT   * GRANT SELECT ON SYS_DBA_ROLE_PRIVS TO ^parse_as_user
PROMPT 
PROMPT If you choose to install this option, the grants will be automatically 
PROMPT apportioned and the feature will be available within SERT
PROMPT
ACCEPT parse_as_optn char DEFAULT 'yes' PROMPT 'Would you like to install the SCHEMA DETAILS option? [yes]'
--
-- Using some SQL*PLUS magic, change the names of the scripts we would use to install the 
-- Parse As support. The script names will be correct if the user selected YES but will 
-- be changed to 'null.sql' if the user selects anything else.

column parse_as_grants new_val parse_as_grants_s NOPRINT
--
select 'null.sql' parse_as_grants from dual where upper('^parse_as_optn') != 'YES';
--
set termout off
--
-- Call the Extra Grant script
@@^parse_as_grants_s 

PROMPT
PROMPT ============================================================================
PROMPT == A U T O   A P P L I C A T I O N   I D   A S S I G N M E N T 
PROMPT ============================================================================
PROMPT
ACCEPT app_id_auto CHAR DEFAULT 'Y' PROMPT 'Let APEX automatically assign Application ID values for SERT? (Y or N) [Y] :'

DEFINE sert_app_id = 0
DEFINE sert_mgmt_id = 0

-- Run the "PROMPT_FOR_ID script if needed"
set termout off
  column my_script new_val app_id_assign_script 
  select 'app/null.sql' my_script from dual where 'Y' = '^app_id_auto';
  column my_script  clear  
set termout on
-- Prompt for ID values if requested by the user 
@@^app_id_assign_script 

set termout on

PROMPT
PROMPT  =============================================================================
PROMPT  == Ready to start SERT Version @SV_VERSION@ installation...
PROMPT  =============================================================================
PROMPT
PROMPT  Log File                  = ^logname
PROMPT  SERT Schema               = ^esert_user
PROMPT  View System Privileges    = ^parse_as_optn
PROMPT  App ID Auto Assign        = ^app_id_auto          
PROMPT  SERT Application ID       = ^sert_app_id
PROMPT  SERT Management App ID    = ^sert_mgmt_id
PROMPT
PAUSE   Press Enter to continue installation or CTRL-C to EXIT


--  ================= Create the objects in the SERT Schema
PROMPT 'Connecting to "sv_sert_@SV_VERSION@" to create objects.'
alter session set current_schema = sv_sert_@SV_VERSION@;

PROMPT  =============================================================================
PROMPT  == L O G G E R
PROMPT  =============================================================================
@@logger/_ins_logger.sql
-- Logger installation sets define to '&' 
-- reset the difine variable so the rest of the script uses it's 
set define on
set define '^'
set define off

PROMPT  =============================================================================
PROMPT  == P A C K A G E   S P E C S
PROMPT  =============================================================================
@@pkg/_ins_pks.sql

PROMPT  =============================================================================
PROMPT  == C O N T E X T
PROMPT  =============================================================================
@@ctx/_ins_ctx.sql

PROMPT  =============================================================================
PROMPT  == T A B L E S
PROMPT  =============================================================================
@@tbl/_ins_tbl.sql

PROMPT  =============================================================================
PROMPT  == V I E W S
PROMPT  =============================================================================
@@vw/_ins_vw.sql

PROMPT  =============================================================================
PROMPT  == P R O C E D U R E S
PROMPT  =============================================================================
@@prc/_ins_prc.sql

PROMPT  =============================================================================
PROMPT  == P A C K A G E   B O D I E S
PROMPT  =============================================================================
@@pkg/_ins_pkb.sql

PROMPT  =============================================================================
PROMPT  == C O N F I G 
PROMPT  =============================================================================
@@cfg/_ins_cfg.sql "^parse_as_user"
--
--
-- Switch back to SYS
alter session set current_schema = SYS;

-- redefine these after switching back to the SYS schema
set scan on
set define on
set define '^'

PROMPT  =============================================================================
PROMPT  == G R A N T S
PROMPT  =============================================================================
@@ins/launcher_grants

PROMPT  =============================================================================
PROMPT  == S Y N O N Y M S
PROMPT  =============================================================================
@@syn/_ins_syn.sql 

PROMPT  =============================================================================
PROMPT  == W O R K S P A C E   A N D   A P P L I C A T I O N S
PROMPT  =============================================================================
@@app/_install.sql "^sert_password" "^parse_as_user" "^sert_app_id" "^sert_mgmt_id" "^admin_email_address"

INSERT INTO sv_sert_@SV_VERSION@.sv_sec_snippets (snippet_key, snippet, editable)
  VALUES ('EVAL_NOTIFICATION_FROM', '^admin_email_address','Y')
/

set define '^'

PROMPT  =============================================================================
PROMPT  == L O C K   A C C O U N T S
PROMPT  =============================================================================
alter user sv_sert_@SV_VERSION@ account lock;
alter user ^parse_as_user account lock;

PROMPT  =============================================================================
PROMPT  == R E C O M P I L E   C O R E   S C H E M A
PROMPT  =============================================================================

BEGIN 
  dbms_utility.compile_schema(schema => 'SV_SERT_@SV_VERSION@');
END;
/

PROMPT  =============================================================================
PROMPT  == A P P L I C A T I O N   I N S T A L L A T I O N   R E S U L T S 
PROMPT  =============================================================================
PROMPT
COLUMN APPLICATION_ID FORMAT 999999
COLUMN WORKSPACE FORMAT A20
COLUMN APPLICATION_NAME FORMAT A30
SELECT APPLICATION_ID as APP_ID, WORKSPACE, APPLICATION_NAME
  FROM apex_applications
  WHERE WORKSPACE ='SERT'
  ORDER by application_id;

-- configure logger utility
set define '^'
BEGIN
  sv_sert_@SV_VERSION@.LOGGER_CONFIGURE;
  commit;
END;
/

PROMPT  =============================================================================
PROMPT  == P O S T   I N S T A L L A T I O N   S T E P S 
PROMPT  =============================================================================
PROMPT
PROMPT  In order to be able to launch APEX-SERT, paste the following into the System Message
PROMPT  region in the INTERNAL workspace:
PROMPT
PROMPT  <a href="javascript:var launchSERT=window.open('sert/launch/' + $v('pInstance'));"><span class="a-Icon icon-run-page"></span>&nbsp;Launch APEX-SERT</a>
PROMPT
PROMPT  To access the APEX-SERT Admin application, enter the following URL while
PROMPT  substituting HOST, PORT and DAD with those from your APEX environment:
PROMPT      
PROMPT  http(s)://HOST:PORT/DAD/f?p=SERT_ADMIN
PROMPT
PROMPT  Please see the APEX-SERT Installation Guide for detailed post-installation steps.
PROMPT


--  =================
--  ================= Cleanup
--  ================= 
undefine sert_app_id
undefine sdb2
undefine esert_user
undefine pswd
undefine parse_as_user
undefine create_user_s
undefine create_parse_as_s
undefine scheduling_grant_s
undefine parse_as_grants_s

-- reset the define variable
set define '&'

--  =================
--  =================  Reset all of the standard settings
--  =================
set termout on
set feedback on
Set verify on
whenever sqlerror continue
--  =================
--  =================  END OF INSTALLATION
--  =================
PROMPT
PROMPT
PROMPT  =============================== APEX-SERT ==================================
PROMPT
PROMPT  Please check the log file for errors. 
PROMPT  
PROMPT  Please refer to the SERT installation guide for final installation steps.
PROMPT
PROMPT  ============================================================================
PROMPT  ============================= C O M P L E T E ==============================
PROMPT  ============================================================================
spool off