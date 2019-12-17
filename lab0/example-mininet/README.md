# Example: Mininet
Example to show how to run Mininet, issue arbitrary commands, and capture the output.
  * Runs in a screen and "stuffs" commands into the screen (commands must end with a new-line, which is denoted as a ctrl-character; in vim, use `Ctrl+v+m`)
  * Dumps screen contents into a log / output file
  * Simple `pingall` command, and checks output to ensure no packet loss occurred.
  * Does proper clean-up of Mininet afterwards (no leftover OVS to pollute future tests)

