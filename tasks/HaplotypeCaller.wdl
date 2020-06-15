version 1.0

# HaplotypeCaller per-sample in GVCF mode
task HaplotypeCaller {
  input {
    File input_bam
    File input_bam_index
    File interval_list
    String output_filename
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Float? contamination
    Boolean make_gvcf
    Int hc_scatter

    String gatk_path
    String? java_options

    # Runtime parameters
    String docker
    String? instance_type
    Int? mem_gb
    Int? disk_space_gb
    Boolean use_ssd = true
    Int? preemptible_attempts
  }

  String java_opt = select_first([java_options, "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10"])

  Int machine_mem_gb = select_first([mem_gb, 7])
  Int command_mem_gb = machine_mem_gb - 1

  Float ref_size = size(ref_fasta, "GB") + size(ref_fasta_index, "GB") + size(ref_dict, "GB")
  Int disk_size = ceil(((size(input_bam, "GB") + 30) / hc_scatter) + ref_size) + 20

  command <<<
  set -e

    ~{gatk_path} --java-options "-Xmx~{command_mem_gb}G ~{java_opt}" \
      HaplotypeCaller \
      -R ~{ref_fasta} \
      -I ~{input_bam} \
      -L ~{interval_list} \
      -O ~{output_filename} \
      -contamination ~{default=0 contamination} ~{true="-ERC GVCF" false="" make_gvcf}
  >>>

  runtime {
    docker: docker
    cluster: "OnDemand " + select_first([instance_type, "ecs.sn2ne.xlarge"]) + " img-ubuntu-vpc"
    dataDisk: (if use_ssd then "cloud_ssd " else "cloud_efficiency ") + select_first([disk_space_gb, disk_size]) + " /cromwell_root/"
    #preemptible: select_first([preemptible_attempts, 3])
  }

  output {
    File output_vcf = "${output_filename}"
    File output_vcf_index = "${output_filename}.tbi"
  }
}