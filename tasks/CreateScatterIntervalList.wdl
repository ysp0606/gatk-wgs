version 1.0

task CreateScatterIntervalList {
  input {
    File calling_intervals_list
  }

  File ScatterIntervalList = "./ScatterIntervalList.txt"

  command <<<
    # Split wgs_calling_regions list into 9 sub-regions for HaplotypeCaller scatter-gather
    awk 'BEGIN {
      prev_total = 0
      frag = 1
      container = ""
    }
    { if ( $1 !~ /^@/ )
      {
        len = ($3 - $2 + 1)
        if ( prev_total + len < 324860607 ) {
          prev_total += len
          container = container sprintf("-L %s:%d-%d ", $1, $2, $3)
        }
        else {
          a1 = prev_total + len - 324860607
          a2 = 324860607 - prev_total
          if ( a1 > a2 ) { print container; container = sprintf("-L %s:%d-%d ", $1, $2, $3); prev_total = len}
          else { container = container sprintf("-L %s:%d-%d ", $1, $2, $3); print container; container = ""; prev_total = 0}
          frag += 1
        }
      }
    }
    END {
      if ( container ) { print container }
    }' ~{calling_intervals_list} > ~{ScatterIntervalList}
  >>>


  output {
    File IntervalList = "${ScatterIntervalList}"
  }

}



