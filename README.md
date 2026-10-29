> **Tech Challenge Fase 4 — `oficina-kubernetes-infra`**
>
> EKS, add-ons do cluster e observabilidade New Relic como código.
>
> Base importada de [`fiap-tech-challenge-fase3-oficina-kubernetes-infra`](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-kubernetes-infra) (commit `bda699f`), sem alterações funcionais. A evolução para a Fase 4 é feita por PRs nas próximas fases; o conteúdo abaixo ainda descreve a Fase 3.

# Oficina Fase 3 — Kubernetes

Documentação da plataforma EKS, da escalabilidade e da observabilidade da Oficina. A visão completa da solução está no [repositório central](https://github.com/tiagomiele/backend).

Projeto de implementação: [fiap-tech-challenge-fase3-oficina-kubernetes-infra](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-kubernetes-infra)

## Visão de negócio

O Kubernetes sustenta a continuidade da operação da oficina. Se a demanda aumentar, a plataforma deve ampliar a capacidade do Backend; se um pod falhar ou precisar ser atualizado, o atendimento deve continuar disponível; se houver degradação, a equipe precisa identificá-la rapidamente.

Esse projeto não implementa regras de clientes ou Ordens de Serviço. Ele oferece a base para que essas funcionalidades operem com escalabilidade, alta disponibilidade, isolamento de rede e visibilidade sobre saúde, consumo e falhas.

## Responsabilidades

- provisionar VPC, sub-redes, rotas, Internet Gateway e NAT Gateway;
- criar Amazon EKS e managed node groups;
- fornecer conectividade e Load Balancer para o Backend;
- instalar Metrics Server e suportar HPA por CPU e memória;
- integrar o cluster ao New Relic por Helm;
- criar dashboards, alertas e monitor sintético como código;
- disponibilizar outputs de rede para Database e Auth;
- separar states e configurações de homologação e produção.

Aplicação Spring Boot, autenticação, schema e RDS permanecem fora deste repositório.

## Arquitetura do componente

![Arquitetura resumida da plataforma Kubernetes com escalabilidade, disponibilidade e observabilidade](docs/assets/arquitetura-kubernetes-resumida.png)

```text
Internet
   ↓
AWS Load Balancer
   ↓
Amazon EKS em sub-redes privadas
   ├─ Backend com múltiplas réplicas
   ├─ HPA por CPU e memória
   ├─ PDB, probes e rolling update
   ├─ Metrics Server
   └─ New Relic Infrastructure Agent

VPC e Security Groups
   ├─ conexão privada com RDS
   └─ integração com Lambdas do Auth

New Relic
   ├─ APM e infraestrutura
   ├─ dashboards
   ├─ alertas
   └─ monitor sintético
```
## Modelo arquitetural e práticas

O projeto utiliza Infrastructure as Code declarativa:

- Terraform cria rede, EKS, nodes e outputs;
- Helm configura add-ons internos;
- um módulo Terraform separado em `observability/newrelic` cria dashboards e alertas;
- workspaces HCP Terraform isolam homologação e produção;
- GitHub Environments controlam a implantação de cada ambiente.

A alta disponibilidade da solução combina capacidade distribuída do cluster com réplicas, HPA, PodDisruptionBudget, probes e estratégia de rolling update configurados no Backend.

## Stack e ferramentas

| Área | Tecnologias |
|---|---|
| Nuvem | AWS VPC, Amazon EKS 1.34, node groups e Load Balancer |
| Orquestração | Kubernetes, Helm, Metrics Server, HPA, PDB e probes |
| Infraestrutura | Terraform, HCP Terraform e providers AWS/Kubernetes/Helm |
| Observabilidade | New Relic `nri-bundle`, dashboards, alertas e monitor sintético |
| Automação | GitHub Actions, Bash, Python e PowerShell |
| Qualidade | Terraform Validate, TFLint, yamllint, ShellCheck, actionlint e testes Python |
| Segurança | Trivy, Gitleaks e Secrets externos ao repositório |

## Estrutura de pastas

```text
.
├── .github/workflows/
│   ├── ci.yml                      # validações de IaC, scripts e segurança
│   ├── terraform-plan.yml          # plan para homologação e produção
│   ├── deploy-homolog.yml          # deploy da plataforma de homologação
│   └── deploy-production.yml       # deploy protegido de produção
├── docs/
│   ├── cicd.md
│   ├── infraestrutura-observabilidade.md
│   └── assets/                     # diagramas da plataforma e dos pipelines
├── environments/                   # exemplos de variáveis por ambiente
├── kubernetes/addons/              # values Helm e versões dos add-ons
├── observability/newrelic/          # dashboards, alertas e sintéticos como código
├── scripts/
│   ├── check-aws-session.sh
│   ├── deploy-cluster-addons.sh
│   ├── lint-cluster-addons.sh
│   ├── verify-cluster-addons.sh
│   └── sync-network-outputs.py
├── tests/                           # testes dos scripts de sincronização
├── network.tf                       # VPC, sub-redes, rotas e NAT
├── eks.tf                           # cluster e managed node groups
├── providers.tf
├── variables.tf
├── outputs.tf
└── versions.tf
```

## Pré-requisitos

- Git;
- Terraform compatível com `versions.tf`;
- AWS CLI;
- `kubectl`;
- Helm;
- Python 3;
- TFLint, yamllint e ShellCheck para validação completa;
- credenciais AWS e workspaces HCP Terraform somente para operações remotas.

## Validar localmente

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
tflint --recursive
python3 -m unittest discover -s tests -p 'test_*.py'
./scripts/lint-cluster-addons.sh
```

Validação adicional do módulo New Relic:

```bash
terraform -chdir=observability/newrelic fmt -check -recursive
terraform -chdir=observability/newrelic init -backend=false -input=false -lockfile=readonly
terraform -chdir=observability/newrelic validate
```

Esses comandos validam a configuração e não criam infraestrutura.

## Configuração por ambiente

Infraestrutura principal:

- [Homologação](environments/homolog.tfvars.example)
- [Produção](environments/production.tfvars.example)

Observabilidade:

- [Homologação](observability/newrelic/environments/homolog.tfvars.example)
- [Produção](observability/newrelic/environments/production.tfvars.example)

Credenciais AWS, chaves New Relic e demais dados sensíveis devem permanecer no HCP Terraform ou nos GitHub Environments. Não versione arquivos `.tfvars` com valores reais.

## Outputs principais

O projeto disponibiliza os dados necessários aos demais componentes, incluindo:

- identificador e endpoint do cluster EKS;
- região AWS;
- VPC e sub-redes privadas;
- Security Groups relevantes;
- dados utilizados na configuração do `kubectl`;
- outputs necessários ao Database, Auth e Backend.

A sincronização cross-repository propaga somente configurações necessárias e não deve expor credenciais.

## Escalabilidade e disponibilidade

A plataforma oferece suporte aos seguintes mecanismos:

| Mecanismo | Finalidade |
|---|---|
| Managed node groups | capacidade computacional administrada do EKS |
| Metrics Server | métricas utilizadas pelo autoscaling |
| HPA | ajuste automático da quantidade de pods |
| Múltiplas réplicas | continuidade diante da falha de um pod |
| PDB | preservação da disponibilidade em interrupções voluntárias |
| Readiness e liveness probes | controle de tráfego e recuperação de containers |
| Rolling update | atualização gradual sem parada planejada |
| Distribuição por host e zona | redução de pontos únicos de falha |

Os manifests desses mecanismos para a aplicação estão em [`k8s/`](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-backend/tree/feature/validacao-deploy-aplicacao/k8s) no Backend.

## Observabilidade

O projeto integra o cluster ao New Relic e mantém como código:

- telemetria de nodes, pods e containers;
- dashboards de aplicação, Kubernetes, Lambda/API Gateway e RDS;
- alertas de disponibilidade, erros, CPU, memória e banco;
- monitor sintético da aplicação;
- canais e workflows de notificação, quando configurados.

- [Configuração técnica da observabilidade](observability/newrelic/)
- [Documentação de infraestrutura e observabilidade](docs/infraestrutura-observabilidade.md)

## CI/CD e implantação

| Workflow | Finalidade |
|---|---|
| `ci.yml` | validar Terraform, scripts, Helm, documentação e segurança |
| `terraform-plan.yml` | apresentar as mudanças sem executar apply |
| `deploy-homolog.yml` | criar ou atualizar homologação |
| `deploy-production.yml` | criar ou atualizar produção pelo ambiente protegido |

Fluxo de promoção:

```text
feature → Pull Request → homolog → Pull Request → main
```

Sequência interna do deploy:

```text
validar sessão AWS
→ aplicar rede e EKS
→ sincronizar outputs
→ configurar kubectl
→ instalar add-ons
→ aplicar observabilidade
→ verificar cluster
```

Na implantação completa da Oficina, este é o primeiro projeto a ser aplicado:

```text
Kubernetes → Database → Auth → Backend
```

## Documentação e evidências

- [Documentação central da Fase 3](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-backend/tree/feature/validacao-deploy-aplicacao)
- [Requisitos obrigatórios e evidências](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-backend/blob/feature/validacao-deploy-aplicacao/README-requisitos-obrigatorios-fase-3.md)
- [Fluxos específicos de CI/CD](docs/cicd.md)

Este repositório não publica APIs de negócio. Swagger, OpenAPI e Postman pertencem ao Backend e ao Auth Serverless.

## Projetos relacionados

- [Backend](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-backend)
- [Auth Serverless](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-auth-serverless)
- [Database Infra](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-database-infra)

## Licença

Consulte o arquivo [LICENSE](LICENSE).
