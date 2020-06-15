# 简介
本流程是使用 WDL 编写的基于 GATK 的 WGS 最佳实践，完成从 fastq 到 vcf 的全流程。使用 Cromwell 可以将工作流运行在阿里云批量计算服务上。更多WDL + Crowmell 的最佳实践请参考阿里云官网文档[链接1](https://help.aliyun.com/document_detail/110173.html?spm=a2c4g.11174283.6.604.52c14fd2tM3f35)和[链接2](https://developer.aliyun.com/article/716546)。

# 流程组成
整个流程由下面几部分组成
- wgs.wdl: WGS 的主流程
- tasks: 主流程中用到的单个 task 定义
- wgs.inputs.30x.json: 输入文件，用于指定工作流的输入样本、参考基因组、参数等
- option.json: 工作流运行选项

# 如何使用
修改输入文件中的下面参数
1. 样本名称 `WGS.sample_name`，改成自己样本名称
2. 样本OSS路径，包括 `WGS.fastq1` 和 `WGS.fastq2`，改成对应 Region 的 OSS 路径
3. 参考基因组，包括 `WGS.ref_dict`、`WGS.ref_fasta`、`WGS.knowns_sites`等，由阿里云提供，注意这里需要改成对应的 Region。

