output "keypair_check_result" {
  description = "Result of keypair check"
  value       = data.external.keypair_check.result
}

output "public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  description = "Public DNS name of the web server"
  value       = aws_instance.web.public_dns
}

output "instance_id" {
  description = "EC2 instance ID for SSM access"
  value       = aws_instance.web.id
}

output "website_url" {
  description = "URL to access the website"
  value       = "http://${aws_instance.web.public_dns}"
}

output "ssm_command" {
  description = "Command to connect via SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.web.id}"
}