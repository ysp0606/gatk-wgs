version 1.0

import "tasks/Alignment.wdl" as alignment
import "tasks/MarkDuplicates.wdl" as dedup
import "tasks/CreateSequenceGroupingTSV.wdl" as sequence
import "tasks/BaseRecalibrator.wdl" as base_recalibrator
import "tasks/GatherBqsrReports.wdl" as gather
import "tasks/ApplyBQSR.wdl" as bqsr
import "tasks/GatherBamFiles.wdl" as gather_bam
import "tasks/HaplotypeCaller.wdl" as haplo
import "tasks/MergeGVCFs.wdl" as merge


workflow WGS {
  input {
    # Fastq files
    File fastq1
    File fastq2

    # Gatk path
    String? gatk_path_override
    String gatk_path = select_first([gatk_path_override, "/gatk/gatk"])

    # Bwa path
    String? gotc_path_override
    String gotc_path = select_first([gotc_path_override, "/usr/gitc/"])

    # Fasta
    File ref_fasta
    File ref_fasta_index
    File ref_dict

    Array[File?] genome_indexes

    String platform = "ILLUMINA" #platform

    # Known sites
    Array[File] knowns_sites = [
        "oss://genomics-public-data-shanghai/broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz",
        "oss://genomics-public-data-shanghai/broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz",
        "oss://genomics-public-data-shanghai/broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf"
    ]

    Array[File] knowns_sites_indies = [
        "oss://genomics-public-data-shanghai/broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi",
        "oss://genomics-public-data-shanghai/broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz.tbi",
        "oss://genomics-public-data-shanghai/broad-references/hg38/v0/Homo_sapiens_assembly38.dbsnp138.vcf.idx"
    ]

    # Call interval list
    File scattered_calling_intervals_list



    String sample_name

    Int compression_level

    String? gatk_docker_override
    String gatk_docker = select_first([gatk_docker_override, "registry.cn-shanghai.aliyuncs.com/batchcompute-public/gatk:4.1.5.0"])


    String? gotc_docker_override
    String gotc_docker = select_first([gotc_docker_override, "registry.cn-shanghai.aliyuncs.com/batchcompute-public/genomes-in-the-cloud:bwa-0.7.17-samtools-1.9"])

    Int flowcell_small_disk
#    Int flowcell_medium_disk
    Int agg_small_disk
    # Int agg_medium_disk
    Int agg_large_disk
    # String? small_cluster = "OnDemand ecs.sn1ne.xlarge img-ubuntu-vpc"

    Boolean? make_gvcf
  }

  String output_prefix = "./" + sample_name + "_gatk4.1_"
  String vcf_basename = sample_name
  Boolean making_gvcf = select_first([make_gvcf,false])

  String output_suffix = if making_gvcf then ".g.vcf.gz" else ".vcf.gz"
  String output_filename = vcf_basename + output_suffix

  Array[File] scattered_calling_intervals = read_lines(scattered_calling_intervals_list)

  # We need disk to localize the sharded input and output due to the scatter for HaplotypeCaller.
  # If we take the number we are scattering by and reduce by 20 we will have enough disk space
  # to account for the fact that the data is quite uneven across the shards.
  Int potential_hc_divisor = length(scattered_calling_intervals) - 20
  Int hc_divisor = if potential_hc_divisor > 1 then potential_hc_divisor else 1



  call alignment.Alignment as Alignment {
    input:
      fastq1 = fastq1,
      fastq2 = fastq2,
      genome_indexes  = genome_indexes,
      sample_id = sample_name,
      output_prefix = output_prefix,
      PL = platform,
      bwa_release = gotc_path,
      docker_image = gotc_docker,
      disk_size = agg_large_disk,
  }

  call dedup.MarkDuplicates as MarkDuplicates {
    input:
      input_bam = Alignment.output_bam,
      input_bam_index = Alignment.output_bam_index,
      output_prefix = output_prefix,
      docker_image = gatk_docker,
      disk_size = agg_large_disk,
      gatk_path = gatk_path,
      compression_level = compression_level,
  }


  # Create list of sequences for scatter-gather parallelization
  call sequence.CreateSequenceGroupingTSV as CreateSequenceGroupingTSV {
    input:
      ref_dict = ref_dict,
  }

  # Perform Base Quality Score Recalibration (BQSR) on the sorted BAM in parallel
  scatter (subgroup in CreateSequenceGroupingTSV.sequence_grouping) {
    # Generate the recalibration model by interval
    call base_recalibrator.BaseRecalibrator as BaseRecalibrator {
      input:
        input_bam = MarkDuplicates.output_bam,
        input_bam_index = MarkDuplicates.output_bam_index,
        recalibration_report_filename = output_prefix + ".recal_data.csv",
        sequence_group_interval = subgroup,
        known_indels_sites_VCFs = knowns_sites,
        known_indels_sites_indices = knowns_sites_indies,
        ref_dict = ref_dict,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        docker_image = gatk_docker,
        gatk_path = gatk_path,
        disk_size = agg_small_disk,
    }
  }

  # Merge the recalibration reports resulting from by-interval recalibration
  call gather.GatherBqsrReports as GatherBqsrReports {
    input:
      input_bqsr_reports = BaseRecalibrator.recalibration_report,
      output_report_filename = output_prefix + ".recal_data.csv",
      docker_image = gatk_docker,
      gatk_path = gatk_path,
      disk_size = flowcell_small_disk,
  }

  scatter (subgroup in CreateSequenceGroupingTSV.sequence_grouping_with_unmapped) {

    # Apply the recalibration model by interval
    call bqsr.ApplyBQSR as ApplyBQSR {
      input:
        input_bam = MarkDuplicates.output_bam,
        input_bam_index = MarkDuplicates.output_bam_index,
        output_bam_basename = output_prefix + ".aligned.duplicates_marked.recalibrated",
        recalibration_report = GatherBqsrReports.output_bqsr_report,
        sequence_group_interval = subgroup,
        ref_dict = ref_dict,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        docker_image = gatk_docker,
        gatk_path = gatk_path,
        disk_size = agg_small_disk,
    }
  }

  # Merge the recalibrated BAM files resulting from by-interval recalibration
  call gather_bam.GatherBamFiles as GatherBamFiles {
    input:
        input_bams = ApplyBQSR.recalibrated_bam,
        output_bam_basename = output_prefix,
        docker_image = gatk_docker,
        gatk_path = gatk_path,
        disk_size = agg_large_disk,
        compression_level = compression_level
  }

  # Call variants in parallel over grouped calling intervals
  scatter (interval_file in scattered_calling_intervals) {

    # Generate GVCF by interval
    call haplo.HaplotypeCaller as HaplotypeCaller {
      input:
        input_bam = GatherBamFiles.output_bam,
        input_bam_index = GatherBamFiles.output_bam_index,
        interval_list = interval_file,
        output_filename = output_filename,
        ref_dict = ref_dict,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        hc_scatter = hc_divisor,
        make_gvcf = making_gvcf,
        docker = gatk_docker,
        gatk_path = gatk_path
    }
  }

  # Merge per-interval GVCFs
  call merge.MergeGVCFs as MergeGVCFs {
    input:
      input_vcfs = HaplotypeCaller.output_vcf,
      input_vcfs_indexes = HaplotypeCaller.output_vcf_index,
      output_filename = output_filename,
      docker = gatk_docker,
      gatk_path = gatk_path
  }

  # Outputs that will be retained when execution is complete
  output {
    File output_vcf = MergeGVCFs.output_vcf
    File output_vcf_index = MergeGVCFs.output_vcf_index
  }

}