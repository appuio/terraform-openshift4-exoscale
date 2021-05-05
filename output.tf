output "ns_records" {
  value = <<EOF

; Add these records in the ${var.base_domain} zone file.
;
; If ${var.base_domain} is a subdomain of one of your zones, you'll need to
; adjust the labels of records below to the form
; '${var.cluster_id}.<subdomain>'.
;
; Delegate  ${var.cluster_id}'s subdomain to Exoscale
${var.cluster_id}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[0].content}.
${var.cluster_id}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[1].content}.
${var.cluster_id}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[2].content}.
${var.cluster_id}  IN  NS     ${data.exoscale_domain_record.exo_nameservers.records[3].content}.

EOF
}
