# Example: Mininet 2
Example to show how to run Mininet with two hosts while specifying link QoS (in this case, 20% packet loss for packets going to h1)
  * Runs in a screen and "stuffs" commands into the screen (commands must end with a new-line, which is denoted as a ctrl-character; in vim, use `Ctrl+v+m`)
  * Runs iperf server in h1 (within the Mininet console in the screen)
  * Runs iperf client in h2 (within the test script itself)
  * Checks if packet loss is 20% +/- 1%
  * Does proper clean-up of Mininet afterwards (no leftover OVS to pollute future tests)

