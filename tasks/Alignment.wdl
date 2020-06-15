version 1.0

task Alignment {
  input {
    File fastq1
    File fastq2
    Array[File?] genome_indexes
    String sample_id
    String lib = "LIBRARY"
    # Sequencing platform.
    String PL
    String output_prefix
    Int disk_size
    String cluster_config
    String docker_image
    String bwa_release
  }

  String ID_SM = sample_id
  String PU = lib + "_" + sample_id
  String LB = sample_id
  String SM = sample_id
  String GROUP_ID="'@RG\\tID:" + ID_SM + "\\tSM:" + SM + "\\tPU:" + PU + "\\tPL:" + PL + "\\tLB:" + LB + "'"


  command <<<
    cpu_cores=$(nproc)
    # Alignment and sort
    bwa_opts="-K 10000000 -M -Y"
    ~{bwa_release}/bwa mem $bwa_opts -t $cpu_cores -R ~{GROUP_ID} ~{genome_indexes[0]} ~{fastq1} ~{fastq2} \
    | samtools sort -@ $cpu_cores -o ~{output_prefix}sorted.bam -
    echo "first"
    ls -l
    samtools index ~{output_prefix}sorted.bam
    echo "second"
    ls -l
  >>>

    runtime {
      docker: docker_image
      cluster: cluster_config
      systemDisk: "cloud_ssd " + disk_size
    }

  output {
    File output_bam = "${output_prefix}sorted.bam"
    File output_bam_index = "${output_prefix}sorted.bam.bai"
  }


}

