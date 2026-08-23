Markdown
# Projeto Final: Provisionamento e Configuração Integrados (Terraform + Ansible)

Este projeto realiza o provisionamento automatizado de infraestrutura na AWS via Terraform e a configuração do ambiente/aplicação via Ansible, atendendo aos requisitos da disciplina de Infraestrutura como Código.

---

## 1. Arquitetura da Solução

```text
Internet
   |
   v
[ Internet Gateway ]
   |
VPC (10.0.0.0/16)
   |
Subnet Pública (10.0.1.0/24)
   |
Security Group (Portas 22, 3000)
   |
+------------------------------------------+
| EC2 t3.micro                             | <-- Provisionada pelo Terraform
|  - Docker Engine                         | <-- Instalado pelo Ansible
|  - getting-started-app (porta 3000:80)   | <-- Container executado pelo Ansible
+------------------------------------------+
   ^
   |
terraform apply --> local-exec (sleep 30) --> ansible-playbook
2. Detalhamento da Integração Terraform -> Ansible
Estratégia Escolhida: Opção B (local-exec disparando o Ansible automaticamente).

Mecanismo: Foi utilizado um recurso null_resource com o provisioner local-exec no Terraform.

Fluxo de Execução:

O Terraform cria a VPC, Subnet, Security Group, Chave SSH e a instância EC2 t3.micro.

Após a criação da instância, o null_resource entra em ação executando um comando local na máquina do operador (runner/Mac M1).

O comando aguarda 30 segundos (sleep 30) para garantir o término do boot do sistema operacional e libera o acesso SSH.

O local-exec invoca o ansible-playbook informando dinamicamente o IP Público da EC2 e a chave privada gerada.

Garantia de Idempotência: O null_resource possui a propriedade triggers = { instance_id = aws_instance.web.id }. O Ansible só será acionado novamente se a instância EC2 for recriada/alterada no Terraform. Execuções repetidas do terraform apply resultam em nenhuma alteração (changed=0).

Boas Práticas: Nenhum provisioner remote-exec foi utilizado. O Ansible utiliza os módulos oficiais da coleção community.docker (docker_image e docker_container) em vez de comandos shell/command.

3. Gestão de Segredos (Ansible Vault)
Variáveis sensíveis do projeto estão armazenadas criptografadas no arquivo ansible/vault.yml via ansible-vault. O arquivo .vault_pass utilizado na descriptografia automática durante a execução do Terraform está protegido no .gitignore e não é comitado no repositório.

4. Passos de Execução (Workspaces dev/prod)
Navegue até o diretório terraform/:

Bash
cd terraform

# Inicializar os provedores
terraform init

# Criar e selecionar o workspace (ex: dev)
terraform workspace new dev
terraform workspace select dev

# Aplicar o provisionamento (infraestrutura + aplicação via Ansible)
terraform apply -auto-approve
5. Passos de Destruição
Para remover 100% dos recursos criados na AWS e evitar custos:

Bash
cd terraform
terraform destroy -auto-approve
6. Evidências de Funcionamento
As capturas de tela e evidências de execução da aplicação na porta 3000 e da destruição dos recursos estão salvas no diretório /evidencias.


Salve o arquivo (`Cmd + S`). O único passo que ficará faltando no seu projeto agora é rodar o `terraform apply`, tirar os prints da aplicação funcionando e da tela de destruição para salvar na pasta `evidencias/`[cite: 1]!

<FollowUp label="Tudo pronto! Quer rodar o terraform apply agora?" query="Como executo o terraform apply com workspaces e valido se o Ansible rodou com sucesso?"/>