#!/usr/bin/env bats

@test "lag parser normalizes consumer group describe output" {
  run awk -f lib/kafka-lag-parser.awk tests/fixtures/consumer-groups-describe.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"group,topic,partition,current_offset,log_end_offset,lag,consumer_id,host,client_id"* ]]
  [[ "$output" == *"orders-worker,orders,0,12500,13000,500,-,-,-"* ]]
  [[ "$output" == *"orders-worker,payments,0,,100,,-,-,-"* ]]
}

@test "lag parser sums one topic" {
  run bash -c "awk -f lib/kafka-lag-parser.awk tests/fixtures/consumer-groups-describe.txt | awk -F, 'NR > 1 && \$2 == \"orders\" { total += \$6 } END { print total + 0 }'"
  [ "$status" -eq 0 ]
  [ "$output" = "500" ]
}

@test "lag parser sums all topics and treats unknown lag as zero" {
  run bash -c "awk -f lib/kafka-lag-parser.awk tests/fixtures/consumer-groups-describe.txt | awk -F, 'NR > 1 { total += (\$6 == \"\" ? 0 : \$6) } END { print total + 0 }'"
  [ "$status" -eq 0 ]
  [ "$output" = "500" ]
}
