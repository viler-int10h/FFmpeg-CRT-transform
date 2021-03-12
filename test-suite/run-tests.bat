@echo off & setlocal
SET TESTRUNSTART=%time%

del *OLD.* 2>nul
for %%a in (*out.*) do ren %%a %%~na-OLD%%~xa

pushd ..
for %%b in (test-suite\??.*) do call ffcrt test-suite\%%~nbcfg.cfg %%b test-suite\%%~nb-out%%~xb
popd

echo TOTAL FOR ALL TESTS - 
@echo Started:     %TESTRUNSTART%
@echo Finished:    %time%