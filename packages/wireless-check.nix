{
  runCommand,
  kernel,
}:
runCommand "beagley-ai-wireless-kernel-contract" {} ''
  for symbol in BT_LE CFG80211_DEBUGFS MAC80211_DEBUGFS SERIAL_DEV_BUS SERIAL_DEV_CTRL_TTYPORT; do
    grep -qx "CONFIG_$symbol=y" ${kernel.configfile}
  done
  for symbol in CC33XX CC33XX_SDIO BT_TI_UART BT CFG80211 MAC80211; do
    grep -qx "CONFIG_$symbol=m" ${kernel.configfile}
  done
  touch "$out"
''
