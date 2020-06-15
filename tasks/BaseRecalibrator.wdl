version 1.0


# Generate Base Quality Score Recalibration (BQSR) model
task BaseRecalibrator {
  input {
    File input_bam
    File input_bam_index
    String recalibration_report_filename
    Array[String] sequence_group_interval
#    File dbSNP_vcf
#    File dbSNP_vcf_index
    Array[File] known_indels_sites_VCFs
    Array[File] known_indels_sites_indices
    File ref_dict
    File ref_fasta
    File ref_fasta_index

    Int disk_size
    #String mem_size

    String docker_image
    String cluster_config
    String gatk_path
    String java_opt
  }

  command {
    ${gatk_path} --java-options "${java_opt}" \
      BaseRecalibrator \
      -R ${ref_fasta} \
      -I ${input_bam} \
      -O ${recalibration_report_filename} \
      --known-sites ${sep=" --known-sites " known_indels_sites_VCFs} \
      -L ${sep=" -L " sequence_group_interval}
  }
  runtime {
    docker: docker_image
    cluster: cluster_config
    systemDisk: "cloud_ssd " + disk_size
  }
  output {
    File recalibration_report = "${recalibration_report_filename}"
  }
}