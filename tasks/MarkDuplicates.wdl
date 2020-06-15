version 1.0

# Mark duplicate reads to avoid counting non-independent observations
task MarkDuplicates {
  input{
      File input_bam
      File input_bam_index
      String output_prefix

      Int compression_level
      Int disk_size
      #String mem_size

      String docker_image
      String cluster_config
      String gatk_path
      String java_opt
  }

 # Task is assuming query-sorted input so that the Secondary and Supplementary reads get marked correctly.
 # This works because the output of BWA is query-grouped and therefore, so is the output of MergeBamAlignment.
 # While query-grouped isn't actually query-sorted, it's good enough for MarkDuplicates with ASSUME_SORT_ORDER="queryname"
  command {
    ${gatk_path} --java-options "-Dsamjdk.compression_level=${compression_level} ${java_opt}" \
      MarkDuplicates \
      -I ${input_bam} \
      -O ${output_prefix}deduplicated.bam \
      -M ${output_prefix}duplication.metrics \
      --REMOVE_DUPLICATES true \
      --CREATE_INDEX true
    ls -l
  }
  runtime {
    docker: docker_image
    cluster: cluster_config
    systemDisk: "cloud_ssd " + disk_size
  }
  output {
    File output_bam = "${output_prefix}deduplicated.bam"
    File output_bam_index = "${output_prefix}deduplicated.bai"
    File duplicate_metrics = "${output_prefix}duplication.metrics"
  }
}