# Prova Prática DevOps

## Objetivo
Containerizar a aplicacao Go e realizar o deploy em Kubernetes seguindo boas praticas, com pipeline CI/CD para build, push no ECR e deploy no EKS.

## Problemas Encontrados
- Dockerfile original nao utilizava multi-stage build.
- Imagem final continha dependencias desnecessarias do ambiente de build.
- Container rodava com usuario root.
- Manifesto de Deployment utilizava placeholder invalido na imagem do ECR (`<REGIAO>`).
- Deployment nao possuia readinessProbe e livenessProbe.
- Deployment nao possuia requests e limits de CPU/memoria.
- Deployment estava com apenas uma replica.
- Manifesto de HPA inexistente.
- Pipeline GitHub Actions estava incompleta, contendo apenas checkout do codigo.

## Correcoes Realizadas

### Dockerfile
- Implementado multi-stage build.
- Separado estagio de build e estagio final de runtime.
- Reduzido o tamanho da imagem final.
- Configurado o container para executar com usuario nao-root.
- Mantida a aplicacao exposta na porta `8080`.

### Kubernetes
- Corrigida a referencia da imagem para o ECR da regiao `us-west-2`.
- Configurado Deployment com `2` replicas.
- Adicionadas `readinessProbe` e `livenessProbe` utilizando o endpoint `/healthz`.
- Adicionados `resources.requests` e `resources.limits`.
- Mantido Service do tipo `ClusterIP`, expondo porta `80` para `targetPort 8080`.
- Criado HPA com minimo de `2` replicas, maximo de `5` e escala baseada em CPU.

### CI/CD
- Criado workflow GitHub Actions funcional.
- Adicionada autenticacao na AWS via secrets.
- Adicionado login no Amazon ECR.
- Adicionado build e push da imagem Docker.
- Adicionado deploy automatico dos manifestos no EKS.
- Adicionada validacao do rollout do Deployment.

## Melhorias Aplicadas
- Troca da tag `latest` por tag imutavel baseada no SHA do commit na pipeline.
- Criacao de namespace dedicado `go-app` para isolar a aplicacao no cluster.

## Principais Recursos
- `Dockerfile`: gera a imagem da aplicacao em Go.
- `.github/workflows/deploy.yml`: pipeline de build, push e deploy.
- `k8s/deployment.yaml`: define replicas, imagem, probes e recursos.
- `k8s/service.yaml`: expoe a aplicacao internamente no cluster.
- `k8s/hpa.yaml`: habilita escalabilidade horizontal por CPU.
- `k8s/namespace.yaml`: cria o namespace dedicado da aplicacao.
- `main.go`: API simples em Go com endpoint principal e `/healthz`.

## Pre-Requisitos da Pipeline
- Repositorio forkado no GitHub.
- GitHub Actions habilitado no fork.
- Workflow presente em `.github/workflows/deploy.yml`.
- Branch utilizada incluida no gatilho do workflow.
- Secrets configurados no GitHub Actions:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- Permissoes validas na conta AWS para acesso ao ECR e ao EKS.

## Pre-Requisitos para Validacao Manual
- Docker em execucao na maquina local.
- AWS CLI configurada com acesso ao ambiente da prova.
- `kubectl` instalado e apontando para o cluster.

## Configuracao da AWS e do Cluster
Criar um perfil isolado:

```bash
aws configure --profile desafio
```

Atualizar o kubeconfig:

```bash
aws eks update-kubeconfig --name EKS-Oregon --region us-west-2 --profile desafio
kubectl get nodes
```

Autenticar no ECR:

```bash
aws ecr get-login-password --region us-west-2 --profile desafio | docker login --username AWS --password-stdin 363838752048.dkr.ecr.us-west-2.amazonaws.com
```

## Validacao Local
```bash
docker build -t api .
docker run --rm -p 8081:8080 api
curl http://localhost:8081
curl http://localhost:8081/healthz
```

## Deploy Manual
```bash
docker build -t api .
IMAGE_TAG=$(git rev-parse HEAD)
docker tag api 363838752048.dkr.ecr.us-west-2.amazonaws.com/devops/prova:$IMAGE_TAG
docker push 363838752048.dkr.ecr.us-west-2.amazonaws.com/devops/prova:$IMAGE_TAG
kubectl apply -f k8s/namespace.yaml
sed "s/PLACEHOLDER_IMAGE_TAG/${IMAGE_TAG}/g" k8s/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
kubectl get deploy,svc,hpa,pods -n go-app
kubectl rollout status deployment/go-app -n go-app
```

## Passo a Passo da Pipeline
1. Fazer push da branch para o fork no GitHub.
2. Garantir que o workflow `Deploy to EKS` esta habilitado no fork.
3. Garantir que os secrets `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` estao configurados.
4. O GitHub Actions executa `checkout` do codigo.
5. O workflow autentica na AWS.
6. O workflow realiza login no Amazon ECR.
7. O workflow executa `docker build`.
8. O workflow usa o `SHA` do commit como tag imutavel da imagem.
9. O workflow envia a imagem para o repositorio `devops/prova` no ECR.
10. O workflow atualiza o kubeconfig para o cluster `EKS-Oregon`.
11. O workflow cria o namespace `go-app`.
12. O workflow aplica `Deployment`, `Service` e `HPA` no cluster.
13. O workflow valida o rollout com `kubectl rollout status deployment/go-app -n go-app`.

## Como Validar a Pipeline
- Acessar a aba `Actions` do fork.
- Abrir a execucao do workflow `Deploy to EKS`.
- Confirmar sucesso das etapas:
  - `Configure AWS credentials`
  - `Login to Amazon ECR`
  - `Build and push Docker image`
  - `Update kubeconfig`
  - `Deploy manifests to EKS`

## Validacao no Cluster
```bash
kubectl get deploy,svc,hpa,pods -n go-app
kubectl describe pod -l app=go-app -n go-app
kubectl logs -l app=go-app -n go-app
kubectl port-forward svc/go-app-service 8080:80 -n go-app
```

Em outro terminal:

```bash
curl http://localhost:8080
curl http://localhost:8080/healthz
```

## Troubleshooting

### Docker daemon nao responde
```bash
docker ps
```
Verificar se o Docker Desktop esta em execucao.

### Porta local em uso
```bash
lsof -i :8080
docker run --rm -p 8081:8080 api
```

### Falha ao puxar imagem no Kubernetes
```bash
kubectl describe pod -l app=go-app -n go-app
```
Verificar nome da imagem, regiao do ECR e se a imagem foi enviada com sucesso.

### Pod sobe mas nao fica pronto
```bash
kubectl describe pod -l app=go-app -n go-app
kubectl logs -l app=go-app -n go-app
```
Verificar probes, tempo de aquecimento da aplicacao e logs do container.

### Rollout nao conclui
```bash
kubectl rollout status deployment/go-app -n go-app
kubectl describe deployment go-app -n go-app
kubectl get events -n go-app --sort-by=.metadata.creationTimestamp
```

### Pipeline falha na autenticacao AWS
Verificar se os secrets do GitHub Actions foram cadastrados corretamente:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Pipeline nao roda no fork
- Habilitar Actions no fork.
- Confirmar se a branch usada esta incluida no gatilho do workflow.

## Roadmap Futuro
- Criar serviceAccount dedicado para isolar melhor a aplicacao.
- Migrar a autenticacao do GitHub Actions para OIDC, evitando secrets estaticos.

## Escolhas Tecnicas
- Multi-stage build para reduzir tamanho da imagem final.
- Usuario nao-root para melhorar seguranca do container.
- Readiness probe para evitar trafego antes da aplicacao ficar pronta.
- Liveness probe para reinicio automatico em caso de falha.
- Requests e limits para previsibilidade de recursos e suporte ao HPA.
- HPA baseado em CPU para permitir escalabilidade horizontal automatica.
