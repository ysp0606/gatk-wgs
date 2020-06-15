version 1.0


# Combine multiple recalibrated BAM files from scattered ApplyRecalibration runs
task GatherBamFiles {
  input {
    Array[File] input_bams
    String output_bam_basename

    Int compression_level
    Int disk_size
    #String mem_size

    String docker_image
    String cluster_config
    String gatk_path
    String java_opt
  }

  command {
    ${gatk_path} --java-options "-Dsamjdk.compression_level=${compression_level} ${java_opt}" \
      GatherBamFiles \
      --INPUT ${sep=' --INPUT ' input_bams} \
      --OUTPUT ${output_bam_basename}.bam \
      --CREATE_INDEX true \
      --CREATE_MD5_FILE true
    ls -l
  }
  runtime {
    docker: docker_image
    cluster: cluster_config
    systemDisk: "cloud_ssd " + disk_size
  }
  output {
    File output_bam = "${output_bam_basename}.bam"
    File output_bam_index = "${output_bam_basename}.bai"
    File output_bam_md5 = "${output_bam_basename}.bam.md5"
  }
}