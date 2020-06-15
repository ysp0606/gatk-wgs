version 1.0

# Combine multiple recalibration tables from scattered BaseRecalibrator runs
# Note that when run from GATK 3.x the tool is not a walker and is invoked differently.
task GatherBqsrReports {
  input {
    Array[File] input_bqsr_reports
    String output_report_filename

    Int disk_size
    #String mem_size

    String docker_image
    String cluster_config
    String gatk_path
    String java_opt
  }
  command {
    ${gatk_path} --java-options "${java_opt}" \
      GatherBQSRReports \
      -I ${sep=' -I ' input_bqsr_reports} \
      -O ${output_report_filename}
  }
  runtime {
    docker: docker_image
    cluster: cluster_config
    systemDisk: "cloud_ssd " + disk_size
  }
  output {
    File output_bqsr_report = "${output_report_filename}"
  }
}
