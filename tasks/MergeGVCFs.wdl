version 1.0
# Merge GVCFs generated per-interval for the same sample
task MergeGVCFs {
input {
      Array[File] input_vcfs
      Array[File] input_vcfs_indexes
      String output_filename

      String gatk_path

      # Runtime parameters
      String docker
      String? instance_type
      Int? mem_gb
      Int? disk_space_gb
      Boolean use_ssd = true
  }

  Int machine_mem_gb = select_first([mem_gb, 3])
  Int command_mem_gb = machine_mem_gb - 1

  command <<<
  set -e

    ~{gatk_path} --java-options "-Xmx~{command_mem_gb}G"  \
      MergeVcfs \
      --INPUT ~{sep=' --INPUT ' input_vcfs} \
      --OUTPUT ~{output_filename}
  >>>

  runtime {
    docker: docker
    cluster: "OnDemand " + select_first([instance_type, "ecs.sn1ne.xlarge"]) + " img-ubuntu-vpc"
    dataDisk: (if use_ssd then "cloud_ssd " else "cloud_efficiency ") + select_first([disk_space_gb, 100]) + " /cromwell_root/"
  }


  output {
    File output_vcf = "${output_filename}"
    File output_vcf_index = "${output_filename}.tbi"
  }
}