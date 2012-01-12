CREATE USER nagiosora IDENTIFIED BY nagiosora; 
GRANT CREATE SESSION TO nagiosora;
GRANT CONNECT TO nagiosora;
GRANT SELECT any dictionary TO nagiosora;
GRANT SELECT ON V_$SYSSTAT TO nagiosora;
GRANT SELECT ON V_$INSTANCE TO nagiosora;
GRANT SELECT ON V_$LOG TO nagiosora;
GRANT SELECT ON V_$filestat TO nagiosora;
GRANT SELECT ON SYS.DBA_DATA_FILES TO nagiosora;
GRANT SELECT ON SYS.DBA_FREE_SPACE TO nagiosora;
GRANT SELECT ON SYS.DBA_UNDO_EXTENTS TO nagiosora;
GRANT SELECT ON SYS.DBA_TABLESPACES TO nagiosora;
GRANT SELECT ON SYS.DBA_TEMP_FILES TO nagiosora;
GRANT SELECT ON SYS.V_$TEMP_EXTENT_POOL TO nagiosora; 
GRANT SELECT ON SYS.V_$TEMP_SPACE_HEADER TO nagiosora;

-- if somebody still uses Oracle 8.1.7...
GRANT SELECT ON sys.dba_tablespaces TO nagiosora;
GRANT SELECT ON dba_temp_files TO nagiosora;
GRANT SELECT ON sys.v_$Temp_extent_pool TO nagiosora;
GRANT SELECT ON sys.v_$TEMP_SPACE_HEADER  TO nagiosora;
GRANT SELECT ON sys.v_$session TO nagiosora;








