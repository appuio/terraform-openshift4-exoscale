output "ns_records" {
  value = <<EOF

; Add these records in the ${var.base_domain} zone file.
;
; If ${var.base_domain} is a subdomain of one of your zones, you'll need to
; adjust the labels of records below to the form
; '${local.cluster_name}.<subdomain>'.
;
; Delegate  ${var.cluster_id}'s subdomain to Exoscale
${local.cluster_name}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[0].content}.
${local.cluster_name}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[1].content}.
${local.cluster_name}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[2].content}.
${local.cluster_name}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[3].content}.

EOF
}

output "hieradata_mr" {
  value = module.lb.hieradata_mr_url
}
