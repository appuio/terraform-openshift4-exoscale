output "ns_records" {
  value = <<EOF


${var.cluster_id}.${var.base_domain}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[0].content}.
${var.cluster_id}.${var.base_domain}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[1].content}.
${var.cluster_id}.${var.base_domain}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[2].content}.
${var.cluster_id}.${var.base_domain}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[3].content}.

EOF
}
