@echo off
rem Emote Tracker: serves this folder and opens the tracker in your browser.
rem Save tracked clips into emote_lab\sources\, then import them in the
rem playground's Emote Studio. Close this window to stop the server.
cd /d "%~dp0"
start "" http://localhost:8090/
python -m http.server 8090
