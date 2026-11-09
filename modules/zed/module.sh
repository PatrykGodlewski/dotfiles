# shellcheck shell=bash disable=SC2034
DESC="Zed editor config (vim mode, agent setup; theme/font synced by omazed)"
PACMAN=(zed)
SKIP_ON=(wsl)   # on Windows+WSL, Zed runs on Windows and reads %APPDATA%\Zed
