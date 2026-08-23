# 1. Gerar Chave SSH dinamicamente (100% via código)
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "app_key" {
  key_name   = "${var.projeto}-key-${terraform.workspace}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/app_key.pem"
  file_permission = "0400" # Permissão estrita exigida pelo SSH
}

# 2. Rede (VPC, Subnet Pública, Internet Gateway, Tabela de Roteamento)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "${var.projeto}-vpc-${terraform.workspace}" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Importante para a EC2 ganhar IP público
  tags = { Name = "${var.projeto}-subnet-${terraform.workspace}" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.projeto}-igw-${terraform.workspace}" }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

# 3. Security Group (Portas 22 e 3000)
resource "aws_security_group" "app_sg" {
  name        = "${var.projeto}-sg-${terraform.workspace}"
  description = "Permitir SSH e App porta 3000"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Em um cenário real, limitaríamos ao seu IP
  }

  ingress {
    description = "App Getting Started Docker"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Busca dinamicamente a imagem (AMI) mais recente do Ubuntu 24.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # ID oficial da Canonical (Ubuntu)
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# 4. Instância EC2 t3.micro
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = aws_key_pair.app_key.key_name

  tags = {
    Name        = "${var.projeto}-ec2-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

# 5. O Gatilho para o Ansible (Opção B - Integração Idempotente)
resource "null_resource" "ansible_provisioner" {
  triggers = {
    instance_id = aws_instance.web.id
  }

  provisioner "local-exec" {
    # Espera 30s pelo boot e chama o Ansible apontando para a pasta ../ansible
    command = "sleep 30 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${aws_instance.web.public_ip}, -u ubuntu --private-key ${local_file.private_key.filename} --vault-password-file ../ansible/.vault_pass ../ansible/playbook.yml"
  }

  depends_on = [aws_instance.web, local_file.private_key]
}