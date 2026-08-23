output "instance_public_ip" {
  description = "O endereço IP público da instância EC2"
  value       = aws_instance.web.public_ip
}

output "application_url" {
  description = "URL para acessar a aplicação"
  value       = "http://${aws_instance.web.public_ip}:3000"
}

output "ssh_command" {
  description = "Comando para acessar a instância via SSH (se precisar debugar)"
  value       = "ssh -i app_key.pem ubuntu@${aws_instance.web.public_ip}"
}