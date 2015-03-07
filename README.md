# Graylog

## Description
This shell script installs all Graylog components (server and web) on one server.

## Prerequisites
- [x] Processor type : 64Bits
- [x] Operating System : CentOS
- [x] OS versions : 6.5, 6.6
- [x] OS installation : Minimal
- [x] Minimum RAM size : 1Go
- [x] Minimum disk size : 60Go

## Quick guide
1. Create these files in your home folder
  - `touch ~/install_graylog.sh`
  - `touch ~/graylog_variables.cfg`
2. Edit them with Vi editor
  - `vi ~/install_graylog.sh`
  - `vi ~/graylog_variables.cfg`
3. In Vi console
  * Press `<i>` to go in edit mode,
  * Paste content from the following URL : [Github](https://raw.githubusercontent.com/mikael-andre/Graylog/master/install_graylog.sh),
  * Press `<ESCAPE>` to exit edit mode,
  * Type `:x` and press `<ENTER>` to save and close file,
  * For content of `~/graylog_variables.cfg` file, use the following URL : [Github](https://raw.githubusercontent.com/mikael-andre/Graylog/master/graylog_variables.cfg)
4. Give execute rights on install script
  - `chmod +x ~/install_graylog.sh`
5. Launch it with one of the following commands
  - `~/install_graylog.sh -i` to execute in interactive mode
  or
  - `~/install_graylog.sh -a ~/graylog_variables.cfg` to execute in auto mode

## Contact
Feel free to contact me by mail or Github if you have any issues or suggestions.
