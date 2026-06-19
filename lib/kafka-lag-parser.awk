BEGIN {
  OFS = ","
  print "group,topic,partition,current_offset,log_end_offset,lag,consumer_id,host,client_id"
}

/^[[:space:]]*$/ { next }
/^GROUP[[:space:]]+/ { next }
/^(WARN|WARNING|Error|ERROR|Note):/ { next }

NF >= 6 {
  current = ($4 == "-" ? "" : $4)
  lag = ($6 == "-" ? "" : $6)
  consumer = (NF >= 7 ? $7 : "")
  host = (NF >= 8 ? $8 : "")
  client = (NF >= 9 ? $9 : "")
  print $1, $2, $3, current, $5, lag, consumer, host, client
}
