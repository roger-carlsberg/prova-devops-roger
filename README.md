# Prova Prática DevOps

## Objetivo
Containerizar a aplicação Go e realizar o deploy em Kubernetes seguindo boas práticas, com pipeline CI/CD para build, push no ECR e deploy no EKS.

## Problemas Encontrados
- Dockerfile original não utilizava multi-stage build.
- Imagem final continha dependências desnecessárias do ambiente de build.
- Container rodava com usuário root.
- Manifesto de Deployment utilizava placeholder inválido na imagem do ECR (`<REGIAO>`).
- Deployment não possuía readinessProbe e livenessProbe.
- Deployment não possuía requests e limits de CPU/memória.
- Deployment estava com apenas uma réplica.
- Manifesto de HPA inexistente.
- Pipeline GitHub Actions estava incompleta, contendo apenas checkout do código.

## Correções Realizadas

### Dockerfile
- Implementado multi-stage build.
- Separado estágio de build e estágio final de runtime.
- Reduzido o tamanho da imagem final.
- Configurado o container para executar com usuário não-root.
- Mantida a aplicação exposta na porta `8080`.

### Kubernetes
- Corrigida a referência da imagem para o ECR da região `us-west-2`.
- Configurado Deployment com `2` réplicas.
- Adicionadas `readinessProbe` e `livenessProbe` utilizando o endpoint `/healthz`.
- Adicionados `resources.requests` e `resources.limits`.
- Mantido `Service` do tipo `ClusterIP`, expondo porta `80` para `targetPort 8080`.
- Criado `HPA` com mínimo de `2` réplicas, máximo de `5` e escala baseada em CPU.

### CI/CD
- Criado workflow GitHub Actions funcional.
- Adicionada autenticação na AWS via secrets.
- Adicionado login no Amazon ECR.
- Adicionado build e push da imagem Docker.
- Adicionado deploy automático dos manifestos no EKS.
- Adicionada validação do rollout do Deployment.

## Validação Local
```bash
docker build -t api .
docker run --rm -p 8081:8080 api
curl http://localhost:8081
curl http://localhost:8081/healthz

